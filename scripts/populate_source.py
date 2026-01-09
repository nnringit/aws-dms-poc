#!/usr/bin/env python3
"""
Populate Source Database with Sample Data

This script connects to the source RDS PostgreSQL database and loads
the sample e-commerce data from setup_source_data.sql.
"""

import os
import sys
import json
import argparse
import subprocess
from pathlib import Path

try:
    import psycopg2
    from psycopg2 import sql
except ImportError:
    print("Error: psycopg2 is not installed. Run: pip install psycopg2-binary")
    sys.exit(1)


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
    except subprocess.CalledProcessError as e:
        print(f"Error getting Terraform outputs: {e.stderr}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error parsing Terraform outputs: {e}")
        sys.exit(1)


def connect_to_database(host: str, port: int, database: str, 
                        username: str, password: str) -> psycopg2.extensions.connection:
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
        conn.autocommit = True
        return conn
    except psycopg2.Error as e:
        print(f"Error connecting to database: {e}")
        sys.exit(1)


def execute_sql_file(conn: psycopg2.extensions.connection, sql_file: str) -> None:
    """Execute SQL commands from a file."""
    print(f"Reading SQL file: {sql_file}")
    
    with open(sql_file, 'r', encoding='utf-8') as f:
        sql_content = f.read()
    
    print("Executing SQL commands...")
    cursor = conn.cursor()
    
    try:
        cursor.execute(sql_content)
        print("SQL execution completed successfully!")
    except psycopg2.Error as e:
        print(f"Error executing SQL: {e}")
        raise
    finally:
        cursor.close()


def verify_data_loaded(conn: psycopg2.extensions.connection) -> dict:
    """Verify that data was loaded correctly."""
    cursor = conn.cursor()
    
    tables = ['categories', 'customers', 'products', 'inventory', 'orders', 'order_items']
    counts = {}
    
    print("\n" + "=" * 50)
    print("Data Verification")
    print("=" * 50)
    
    for table in tables:
        cursor.execute(sql.SQL("SELECT COUNT(*) FROM {}").format(sql.Identifier(table)))
        count = cursor.fetchone()[0]
        counts[table] = count
        print(f"  {table}: {count} records")
    
    cursor.close()
    print("=" * 50)
    
    return counts


def main():
    parser = argparse.ArgumentParser(description='Populate source database with sample data')
    parser.add_argument('--host', help='Database host')
    parser.add_argument('--port', type=int, default=5432, help='Database port')
    parser.add_argument('--database', default='ecommerce', help='Database name')
    parser.add_argument('--username', default='admin', help='Database username')
    parser.add_argument('--password', help='Database password')
    parser.add_argument('--sql-file', help='Path to SQL file')
    parser.add_argument('--terraform-dir', default='../terraform', 
                        help='Path to Terraform directory')
    parser.add_argument('--use-terraform', action='store_true', 
                        help='Get connection info from Terraform outputs')
    
    args = parser.parse_args()
    
    # Determine script directory
    script_dir = Path(__file__).parent.resolve()
    
    # Get connection info
    if args.use_terraform or (not args.host and not args.password):
        print("Getting connection info from Terraform outputs...")
        terraform_dir = (script_dir / args.terraform_dir).resolve()
        outputs = get_terraform_outputs(str(terraform_dir))
        
        connection_info = outputs.get('connection_info', {}).get('source', {})
        host = connection_info.get('host', args.host)
        port = connection_info.get('port', args.port)
        database = connection_info.get('database', args.database)
        username = connection_info.get('username', args.username)
        
        # Password must be provided separately for security
        password = args.password or os.environ.get('DB_PASSWORD')
        if not password:
            password = input("Enter database password: ")
    else:
        host = args.host
        port = args.port
        database = args.database
        username = args.username
        password = args.password or os.environ.get('DB_PASSWORD')
        if not password:
            password = input("Enter database password: ")
    
    # Determine SQL file path
    sql_file = args.sql_file or (script_dir / 'setup_source_data.sql')
    if not Path(sql_file).exists():
        print(f"Error: SQL file not found: {sql_file}")
        sys.exit(1)
    
    print("\n" + "=" * 50)
    print("Source Database Population")
    print("=" * 50)
    print(f"Host: {host}")
    print(f"Port: {port}")
    print(f"Database: {database}")
    print(f"Username: {username}")
    print(f"SQL File: {sql_file}")
    print("=" * 50 + "\n")
    
    # Connect and load data
    print("Connecting to source database...")
    conn = connect_to_database(host, port, database, username, password)
    print("Connected successfully!")
    
    try:
        execute_sql_file(conn, str(sql_file))
        verify_data_loaded(conn)
    finally:
        conn.close()
        print("\nDatabase connection closed.")
    
    print("\n✓ Source database populated successfully!")
    print("  You can now start the DMS migration task.")


if __name__ == '__main__':
    main()
