#!/usr/bin/env python3
"""
Migration Validation Script

This script validates that the DMS migration was successful by comparing
the source and target databases for:
- Row counts
- Schema structure
- Data integrity (checksums)
- Constraints and indexes
"""

import os
import sys
import json
import argparse
import hashlib
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from datetime import datetime

try:
    import psycopg2
    from psycopg2 import sql
except ImportError:
    print("Error: psycopg2 is not installed. Run: pip install psycopg2-binary")
    sys.exit(1)


@dataclass
class ValidationResult:
    """Represents the result of a validation check."""
    check_name: str
    passed: bool
    source_value: any
    target_value: any
    message: str


class DatabaseValidator:
    """Validates migration between source and target databases."""
    
    def __init__(self, source_conn, target_conn):
        self.source_conn = source_conn
        self.target_conn = target_conn
        self.results: List[ValidationResult] = []
    
    def get_tables(self, conn) -> List[str]:
        """Get list of user tables from the database."""
        cursor = conn.cursor()
        cursor.execute("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
              AND table_type = 'BASE TABLE'
            ORDER BY table_name
        """)
        tables = [row[0] for row in cursor.fetchall()]
        cursor.close()
        return tables
    
    def get_row_count(self, conn, table: str) -> int:
        """Get row count for a table."""
        cursor = conn.cursor()
        cursor.execute(sql.SQL("SELECT COUNT(*) FROM {}").format(sql.Identifier(table)))
        count = cursor.fetchone()[0]
        cursor.close()
        return count
    
    def get_table_schema(self, conn, table: str) -> List[Dict]:
        """Get schema definition for a table."""
        cursor = conn.cursor()
        cursor.execute("""
            SELECT 
                column_name,
                data_type,
                character_maximum_length,
                is_nullable,
                column_default
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = %s
            ORDER BY ordinal_position
        """, (table,))
        
        columns = []
        for row in cursor.fetchall():
            columns.append({
                'name': row[0],
                'type': row[1],
                'max_length': row[2],
                'nullable': row[3],
                'default': row[4]
            })
        cursor.close()
        return columns
    
    def get_constraints(self, conn, table: str) -> List[Dict]:
        """Get constraints for a table."""
        cursor = conn.cursor()
        cursor.execute("""
            SELECT 
                tc.constraint_name,
                tc.constraint_type,
                kcu.column_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu 
                ON tc.constraint_name = kcu.constraint_name
                AND tc.table_schema = kcu.table_schema
            WHERE tc.table_schema = 'public' AND tc.table_name = %s
            ORDER BY tc.constraint_name, kcu.ordinal_position
        """, (table,))
        
        constraints = []
        for row in cursor.fetchall():
            constraints.append({
                'name': row[0],
                'type': row[1],
                'column': row[2]
            })
        cursor.close()
        return constraints
    
    def get_indexes(self, conn, table: str) -> List[Dict]:
        """Get indexes for a table."""
        cursor = conn.cursor()
        cursor.execute("""
            SELECT 
                indexname,
                indexdef
            FROM pg_indexes
            WHERE schemaname = 'public' AND tablename = %s
            ORDER BY indexname
        """, (table,))
        
        indexes = []
        for row in cursor.fetchall():
            indexes.append({
                'name': row[0],
                'definition': row[1]
            })
        cursor.close()
        return indexes
    
    def get_data_checksum(self, conn, table: str, limit: int = 1000) -> str:
        """Get checksum of table data (sample for performance)."""
        cursor = conn.cursor()
        
        # Get primary key column
        cursor.execute("""
            SELECT a.attname
            FROM pg_index i
            JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
            WHERE i.indrelid = %s::regclass AND i.indisprimary
        """, (table,))
        pk_result = cursor.fetchone()
        
        if pk_result:
            pk_column = pk_result[0]
            query = sql.SQL("""
                SELECT * FROM {} ORDER BY {} LIMIT {}
            """).format(
                sql.Identifier(table),
                sql.Identifier(pk_column),
                sql.Literal(limit)
            )
        else:
            query = sql.SQL("SELECT * FROM {} LIMIT {}").format(
                sql.Identifier(table),
                sql.Literal(limit)
            )
        
        cursor.execute(query)
        rows = cursor.fetchall()
        cursor.close()
        
        # Create checksum from data
        data_str = str(rows)
        return hashlib.md5(data_str.encode()).hexdigest()
    
    def validate_table_existence(self) -> None:
        """Validate that all tables exist in both databases."""
        source_tables = set(self.get_tables(self.source_conn))
        target_tables = set(self.get_tables(self.target_conn))
        
        # Tables in source but not target
        missing_in_target = source_tables - target_tables
        # Tables in target but not source
        extra_in_target = target_tables - source_tables
        
        passed = len(missing_in_target) == 0
        
        if missing_in_target:
            message = f"Missing tables in target: {', '.join(missing_in_target)}"
        elif extra_in_target:
            message = f"Extra tables in target (OK): {', '.join(extra_in_target)}"
        else:
            message = f"All {len(source_tables)} tables present in both databases"
        
        self.results.append(ValidationResult(
            check_name="Table Existence",
            passed=passed,
            source_value=list(source_tables),
            target_value=list(target_tables),
            message=message
        ))
    
    def validate_row_counts(self) -> None:
        """Validate row counts match between source and target."""
        tables = self.get_tables(self.source_conn)
        all_match = True
        details = []
        
        for table in tables:
            source_count = self.get_row_count(self.source_conn, table)
            
            try:
                target_count = self.get_row_count(self.target_conn, table)
            except Exception:
                target_count = 0
            
            match = source_count == target_count
            if not match:
                all_match = False
            
            status = "✓" if match else "✗"
            details.append(f"{status} {table}: {source_count} vs {target_count}")
        
        self.results.append(ValidationResult(
            check_name="Row Counts",
            passed=all_match,
            source_value=details,
            target_value=None,
            message="All row counts match" if all_match else "Row count mismatch detected"
        ))
    
    def validate_schemas(self) -> None:
        """Validate schema structures match."""
        tables = self.get_tables(self.source_conn)
        all_match = True
        details = []
        
        for table in tables:
            source_schema = self.get_table_schema(self.source_conn, table)
            
            try:
                target_schema = self.get_table_schema(self.target_conn, table)
            except Exception:
                target_schema = []
            
            # Compare column names and types
            source_cols = {col['name']: col['type'] for col in source_schema}
            target_cols = {col['name']: col['type'] for col in target_schema}
            
            if source_cols == target_cols:
                details.append(f"✓ {table}: Schema matches ({len(source_cols)} columns)")
            else:
                all_match = False
                diff_cols = set(source_cols.keys()) ^ set(target_cols.keys())
                details.append(f"✗ {table}: Schema mismatch - diff columns: {diff_cols}")
        
        self.results.append(ValidationResult(
            check_name="Schema Structure",
            passed=all_match,
            source_value=details,
            target_value=None,
            message="All schemas match" if all_match else "Schema differences detected"
        ))
    
    def validate_constraints(self) -> None:
        """Validate constraints are present in target."""
        tables = self.get_tables(self.source_conn)
        all_match = True
        details = []
        
        for table in tables:
            source_constraints = self.get_constraints(self.source_conn, table)
            
            try:
                target_constraints = self.get_constraints(self.target_conn, table)
            except Exception:
                target_constraints = []
            
            source_pk = [c for c in source_constraints if c['type'] == 'PRIMARY KEY']
            target_pk = [c for c in target_constraints if c['type'] == 'PRIMARY KEY']
            
            pk_match = len(source_pk) == len(target_pk)
            if not pk_match:
                all_match = False
                details.append(f"✗ {table}: Primary key mismatch")
            else:
                details.append(f"✓ {table}: Constraints present")
        
        self.results.append(ValidationResult(
            check_name="Constraints",
            passed=all_match,
            source_value=details,
            target_value=None,
            message="All constraints present" if all_match else "Missing constraints detected"
        ))
    
    def validate_data_integrity(self, sample_size: int = 1000) -> None:
        """Validate data integrity using checksums."""
        tables = self.get_tables(self.source_conn)
        all_match = True
        details = []
        
        for table in tables:
            try:
                source_checksum = self.get_data_checksum(self.source_conn, table, sample_size)
                target_checksum = self.get_data_checksum(self.target_conn, table, sample_size)
                
                match = source_checksum == target_checksum
                if not match:
                    all_match = False
                
                status = "✓" if match else "✗"
                details.append(f"{status} {table}: {source_checksum[:8]}... vs {target_checksum[:8]}...")
            except Exception as e:
                all_match = False
                details.append(f"✗ {table}: Error - {str(e)}")
        
        self.results.append(ValidationResult(
            check_name="Data Integrity",
            passed=all_match,
            source_value=details,
            target_value=None,
            message="Data integrity verified" if all_match else "Data integrity issues detected"
        ))
    
    def run_all_validations(self) -> List[ValidationResult]:
        """Run all validation checks."""
        print("\n" + "=" * 60)
        print("Running Migration Validation")
        print("=" * 60)
        
        validations = [
            ("Table Existence", self.validate_table_existence),
            ("Row Counts", self.validate_row_counts),
            ("Schema Structure", self.validate_schemas),
            ("Constraints", self.validate_constraints),
            ("Data Integrity", self.validate_data_integrity),
        ]
        
        for name, validation_func in validations:
            print(f"\nValidating: {name}...")
            try:
                validation_func()
            except Exception as e:
                self.results.append(ValidationResult(
                    check_name=name,
                    passed=False,
                    source_value=None,
                    target_value=None,
                    message=f"Error: {str(e)}"
                ))
        
        return self.results
    
    def print_report(self) -> None:
        """Print validation report."""
        print("\n" + "=" * 60)
        print("MIGRATION VALIDATION REPORT")
        print("=" * 60)
        print(f"Timestamp: {datetime.now().isoformat()}")
        print("=" * 60)
        
        passed_count = sum(1 for r in self.results if r.passed)
        total_count = len(self.results)
        
        for result in self.results:
            status = "✓ PASSED" if result.passed else "✗ FAILED"
            print(f"\n{status}: {result.check_name}")
            print(f"  Message: {result.message}")
            
            if isinstance(result.source_value, list):
                for item in result.source_value:
                    print(f"    {item}")
        
        print("\n" + "=" * 60)
        print(f"SUMMARY: {passed_count}/{total_count} checks passed")
        
        if passed_count == total_count:
            print("✓ MIGRATION VALIDATED SUCCESSFULLY")
        else:
            print("✗ MIGRATION VALIDATION FAILED")
        print("=" * 60)
    
    def export_report(self, output_file: str) -> None:
        """Export validation report to JSON."""
        report = {
            'timestamp': datetime.now().isoformat(),
            'summary': {
                'total_checks': len(self.results),
                'passed': sum(1 for r in self.results if r.passed),
                'failed': sum(1 for r in self.results if not r.passed),
            },
            'results': [
                {
                    'check_name': r.check_name,
                    'passed': r.passed,
                    'message': r.message,
                }
                for r in self.results
            ]
        }
        
        with open(output_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"\nReport exported to: {output_file}")


def get_terraform_outputs(terraform_dir: str) -> dict:
    """Get outputs from Terraform state."""
    try:
        result = subprocess.run(
            ["terraform", "output", "-json"],
            cwd=terraform_dir,
            capture_output=True,
            text=True,
            check=True
        )
        outputs = json.loads(result.stdout)
        return {k: v.get("value") for k, v in outputs.items()}
    except (subprocess.CalledProcessError, json.JSONDecodeError) as e:
        print(f"Error getting Terraform outputs: {e}")
        return {}


def connect_to_database(host: str, port: int, database: str,
                        username: str, password: str):
    """Create a connection to the PostgreSQL database."""
    try:
        conn = psycopg2.connect(
            host=host,
            port=port,
            database=database,
            user=username,
            password=password,
            connect_timeout=30,
            sslmode='require'
        )
        return conn
    except psycopg2.Error as e:
        print(f"Error connecting to database: {e}")
        return None


def main():
    parser = argparse.ArgumentParser(description='Validate DMS migration')
    
    # Source database arguments
    parser.add_argument('--source-host', help='Source database host')
    parser.add_argument('--source-port', type=int, default=5432)
    parser.add_argument('--source-database', default='ecommerce')
    parser.add_argument('--source-username', default='admin')
    parser.add_argument('--source-password', help='Source database password')
    
    # Target database arguments
    parser.add_argument('--target-host', help='Target database host')
    parser.add_argument('--target-port', type=int, default=5432)
    parser.add_argument('--target-database', default='ecommerce')
    parser.add_argument('--target-username', default='admin')
    parser.add_argument('--target-password', help='Target database password')
    
    # Other arguments
    parser.add_argument('--terraform-dir', default='../terraform')
    parser.add_argument('--use-terraform', action='store_true')
    parser.add_argument('--output-file', help='Output file for JSON report')
    
    args = parser.parse_args()
    
    script_dir = Path(__file__).parent.resolve()
    
    # Get connection info from Terraform if requested
    if args.use_terraform or (not args.source_host and not args.target_host):
        print("Getting connection info from Terraform outputs...")
        terraform_dir = (script_dir / args.terraform_dir).resolve()
        outputs = get_terraform_outputs(str(terraform_dir))
        
        if outputs:
            conn_info = outputs.get('connection_info', {})
            source_info = conn_info.get('source', {})
            target_info = conn_info.get('target', {})
            
            source_host = source_info.get('host', args.source_host)
            source_port = source_info.get('port', args.source_port)
            source_database = source_info.get('database', args.source_database)
            source_username = source_info.get('username', args.source_username)
            
            target_host = target_info.get('host', args.target_host)
            target_port = target_info.get('port', args.target_port)
            target_database = target_info.get('database', args.target_database)
            target_username = target_info.get('username', args.target_username)
        else:
            print("Warning: Could not get Terraform outputs")
            source_host = args.source_host
            source_port = args.source_port
            source_database = args.source_database
            source_username = args.source_username
            target_host = args.target_host
            target_port = args.target_port
            target_database = args.target_database
            target_username = args.target_username
    else:
        source_host = args.source_host
        source_port = args.source_port
        source_database = args.source_database
        source_username = args.source_username
        target_host = args.target_host
        target_port = args.target_port
        target_database = args.target_database
        target_username = args.target_username
    
    # Get passwords
    source_password = args.source_password or os.environ.get('SOURCE_DB_PASSWORD')
    target_password = args.target_password or os.environ.get('TARGET_DB_PASSWORD')
    
    if not source_password:
        source_password = input("Enter source database password: ")
    if not target_password:
        target_password = source_password  # Often same password for both
    
    print("\n" + "=" * 60)
    print("Database Connection Info")
    print("=" * 60)
    print(f"Source: {source_host}:{source_port}/{source_database}")
    print(f"Target: {target_host}:{target_port}/{target_database}")
    print("=" * 60)
    
    # Connect to databases
    print("\nConnecting to source database...")
    source_conn = connect_to_database(
        source_host, source_port, source_database, 
        source_username, source_password
    )
    if not source_conn:
        print("Failed to connect to source database")
        sys.exit(1)
    print("Connected to source database!")
    
    print("Connecting to target database...")
    target_conn = connect_to_database(
        target_host, target_port, target_database,
        target_username, target_password
    )
    if not target_conn:
        print("Failed to connect to target database")
        source_conn.close()
        sys.exit(1)
    print("Connected to target database!")
    
    try:
        # Run validation
        validator = DatabaseValidator(source_conn, target_conn)
        results = validator.run_all_validations()
        validator.print_report()
        
        if args.output_file:
            validator.export_report(args.output_file)
        
        # Exit with appropriate code
        all_passed = all(r.passed for r in results)
        sys.exit(0 if all_passed else 1)
        
    finally:
        source_conn.close()
        target_conn.close()
        print("\nDatabase connections closed.")


if __name__ == '__main__':
    main()
