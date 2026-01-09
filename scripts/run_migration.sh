#!/bin/bash
# =============================================================================
# DMS Migration Orchestration Script
# =============================================================================
# This script orchestrates the complete DMS migration process:
# 1. Validates prerequisites
# 2. Populates source database
# 3. Tests DMS endpoints
# 4. Starts migration task
# 5. Monitors migration progress
# 6. Validates migration results
# =============================================================================

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../terraform"
LOG_FILE="${SCRIPT_DIR}/migration_$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        INFO)  color=$GREEN ;;
        WARN)  color=$YELLOW ;;
        ERROR) color=$RED ;;
        *)     color=$NC ;;
    esac
    
    echo -e "${color}[${timestamp}] [${level}] ${message}${NC}" | tee -a "$LOG_FILE"
}

# Check prerequisites
check_prerequisites() {
    log INFO "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log ERROR "AWS CLI is not installed"
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log ERROR "Terraform is not installed"
        exit 1
    fi
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        log ERROR "Python 3 is not installed"
        exit 1
    fi
    
    # Check psycopg2
    if ! python3 -c "import psycopg2" 2>/dev/null; then
        log WARN "psycopg2 not installed. Installing..."
        pip3 install psycopg2-binary
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log ERROR "AWS credentials not configured"
        exit 1
    fi
    
    log INFO "All prerequisites met!"
}

# Get Terraform outputs
get_terraform_outputs() {
    log INFO "Getting Terraform outputs..."
    
    cd "$TERRAFORM_DIR"
    
    SOURCE_HOST=$(terraform output -raw source_db_address 2>/dev/null || echo "")
    TARGET_HOST=$(terraform output -raw target_db_address 2>/dev/null || echo "")
    REPLICATION_INSTANCE_ARN=$(terraform output -raw dms_replication_instance_arn 2>/dev/null || echo "")
    SOURCE_ENDPOINT_ARN=$(terraform output -raw dms_source_endpoint_arn 2>/dev/null || echo "")
    TARGET_ENDPOINT_ARN=$(terraform output -raw dms_target_endpoint_arn 2>/dev/null || echo "")
    TASK_ARN=$(terraform output -raw dms_replication_task_arn 2>/dev/null || echo "")
    
    if [[ -z "$SOURCE_HOST" || -z "$TARGET_HOST" ]]; then
        log ERROR "Failed to get Terraform outputs. Make sure infrastructure is deployed."
        exit 1
    fi
    
    log INFO "Source DB: $SOURCE_HOST"
    log INFO "Target DB: $TARGET_HOST"
}

# Test DMS endpoints
test_endpoints() {
    log INFO "Testing DMS endpoint connections..."
    
    # Test source endpoint
    log INFO "Testing source endpoint..."
    aws dms test-connection \
        --replication-instance-arn "$REPLICATION_INSTANCE_ARN" \
        --endpoint-arn "$SOURCE_ENDPOINT_ARN" \
        2>&1 | tee -a "$LOG_FILE"
    
    # Wait for source test
    sleep 30
    
    SOURCE_STATUS=$(aws dms describe-connections \
        --filter "Name=endpoint-arn,Values=$SOURCE_ENDPOINT_ARN" \
        --query 'Connections[0].Status' --output text 2>/dev/null || echo "unknown")
    
    if [[ "$SOURCE_STATUS" == "successful" ]]; then
        log INFO "Source endpoint connection successful"
    else
        log WARN "Source endpoint status: $SOURCE_STATUS"
    fi
    
    # Test target endpoint
    log INFO "Testing target endpoint..."
    aws dms test-connection \
        --replication-instance-arn "$REPLICATION_INSTANCE_ARN" \
        --endpoint-arn "$TARGET_ENDPOINT_ARN" \
        2>&1 | tee -a "$LOG_FILE"
    
    # Wait for target test
    sleep 30
    
    TARGET_STATUS=$(aws dms describe-connections \
        --filter "Name=endpoint-arn,Values=$TARGET_ENDPOINT_ARN" \
        --query 'Connections[0].Status' --output text 2>/dev/null || echo "unknown")
    
    if [[ "$TARGET_STATUS" == "successful" ]]; then
        log INFO "Target endpoint connection successful"
    else
        log WARN "Target endpoint status: $TARGET_STATUS"
    fi
}

# Populate source database
populate_source() {
    log INFO "Populating source database with sample data..."
    
    cd "$SCRIPT_DIR"
    
    if [[ -z "$DB_PASSWORD" ]]; then
        read -sp "Enter database password: " DB_PASSWORD
        echo
        export DB_PASSWORD
    fi
    
    python3 populate_source.py \
        --host "$SOURCE_HOST" \
        --password "$DB_PASSWORD" \
        2>&1 | tee -a "$LOG_FILE"
    
    log INFO "Source database populated successfully!"
}

# Start migration task
start_migration() {
    log INFO "Starting DMS migration task..."
    
    # Get current task status
    TASK_STATUS=$(aws dms describe-replication-tasks \
        --filters "Name=replication-task-arn,Values=$TASK_ARN" \
        --query 'ReplicationTasks[0].Status' --output text 2>/dev/null || echo "unknown")
    
    log INFO "Current task status: $TASK_STATUS"
    
    if [[ "$TASK_STATUS" == "ready" || "$TASK_STATUS" == "stopped" ]]; then
        aws dms start-replication-task \
            --replication-task-arn "$TASK_ARN" \
            --start-replication-task-type start-replication \
            2>&1 | tee -a "$LOG_FILE"
        
        log INFO "Migration task started!"
    else
        log WARN "Task is in status: $TASK_STATUS. May already be running."
    fi
}

# Monitor migration progress
monitor_migration() {
    log INFO "Monitoring migration progress..."
    
    local max_wait=1800  # 30 minutes max wait
    local elapsed=0
    local check_interval=30
    
    while [[ $elapsed -lt $max_wait ]]; do
        TASK_STATUS=$(aws dms describe-replication-tasks \
            --filters "Name=replication-task-arn,Values=$TASK_ARN" \
            --query 'ReplicationTasks[0].Status' --output text 2>/dev/null || echo "unknown")
        
        TASK_PROGRESS=$(aws dms describe-replication-tasks \
            --filters "Name=replication-task-arn,Values=$TASK_ARN" \
            --query 'ReplicationTasks[0].ReplicationTaskStats.FullLoadProgressPercent' \
            --output text 2>/dev/null || echo "0")
        
        log INFO "Status: $TASK_STATUS | Progress: ${TASK_PROGRESS}%"
        
        if [[ "$TASK_STATUS" == "stopped" && "$TASK_PROGRESS" == "100" ]]; then
            log INFO "Migration completed successfully!"
            return 0
        elif [[ "$TASK_STATUS" == "running" ]]; then
            log INFO "Migration in progress..."
        elif [[ "$TASK_STATUS" == "failed" ]]; then
            log ERROR "Migration task failed!"
            return 1
        fi
        
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done
    
    log WARN "Migration monitoring timed out. Check AWS Console for status."
    return 0
}

# Validate migration
validate_migration() {
    log INFO "Validating migration results..."
    
    cd "$SCRIPT_DIR"
    
    python3 validate_migration.py \
        --source-host "$SOURCE_HOST" \
        --source-password "$DB_PASSWORD" \
        --target-host "$TARGET_HOST" \
        --target-password "$DB_PASSWORD" \
        --output-file "${SCRIPT_DIR}/validation_report_$(date +%Y%m%d_%H%M%S).json" \
        2>&1 | tee -a "$LOG_FILE"
    
    log INFO "Validation complete!"
}

# Main execution
main() {
    log INFO "=========================================="
    log INFO "DMS Migration Orchestration Started"
    log INFO "=========================================="
    log INFO "Log file: $LOG_FILE"
    
    check_prerequisites
    get_terraform_outputs
    
    echo ""
    echo "This script will:"
    echo "  1. Test DMS endpoint connections"
    echo "  2. Populate source database with sample data"
    echo "  3. Start the DMS migration task"
    echo "  4. Monitor migration progress"
    echo "  5. Validate migration results"
    echo ""
    read -p "Continue? (y/n) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log INFO "Aborted by user"
        exit 0
    fi
    
    test_endpoints
    populate_source
    start_migration
    monitor_migration
    validate_migration
    
    log INFO "=========================================="
    log INFO "DMS Migration Orchestration Completed"
    log INFO "=========================================="
}

# Run main function
main "$@"
