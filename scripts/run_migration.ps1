# PowerShell script to run DMS migration on Windows
# =============================================================================
# DMS Migration Orchestration Script for Windows
# =============================================================================

param(
    [string]$TerraformDir = "..\terraform",
    [string]$DbPassword = $env:DB_PASSWORD,
    [switch]$SkipPopulate,
    [switch]$SkipValidation
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Colors
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Log-Info($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [INFO] $message" -ForegroundColor Green
}

function Log-Warn($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [WARN] $message" -ForegroundColor Yellow
}

function Log-Error($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [ERROR] $message" -ForegroundColor Red
}

# Check prerequisites
function Test-Prerequisites {
    Log-Info "Checking prerequisites..."
    
    # Check AWS CLI
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        Log-Error "AWS CLI is not installed"
        exit 1
    }
    
    # Check Terraform
    if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
        Log-Error "Terraform is not installed"
        exit 1
    }
    
    # Check Python
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        Log-Error "Python is not installed"
        exit 1
    }
    
    # Check AWS credentials
    try {
        aws sts get-caller-identity | Out-Null
    } catch {
        Log-Error "AWS credentials not configured"
        exit 1
    }
    
    Log-Info "All prerequisites met!"
}

# Get Terraform outputs
function Get-TerraformOutputs {
    Log-Info "Getting Terraform outputs..."
    
    Push-Location (Join-Path $ScriptDir $TerraformDir)
    
    try {
        $outputs = terraform output -json | ConvertFrom-Json
        
        $script:SourceHost = $outputs.source_db_address.value
        $script:TargetHost = $outputs.target_db_address.value
        $script:ReplicationInstanceArn = $outputs.dms_replication_instance_arn.value
        $script:SourceEndpointArn = $outputs.dms_source_endpoint_arn.value
        $script:TargetEndpointArn = $outputs.dms_target_endpoint_arn.value
        $script:TaskArn = $outputs.dms_replication_task_arn.value
        
        Log-Info "Source DB: $SourceHost"
        Log-Info "Target DB: $TargetHost"
    } catch {
        Log-Error "Failed to get Terraform outputs: $_"
        exit 1
    } finally {
        Pop-Location
    }
}

# Test DMS endpoints
function Test-DmsEndpoints {
    Log-Info "Testing DMS endpoint connections..."
    
    # Test source endpoint
    Log-Info "Testing source endpoint..."
    aws dms test-connection `
        --replication-instance-arn $ReplicationInstanceArn `
        --endpoint-arn $SourceEndpointArn
    
    Start-Sleep -Seconds 30
    
    # Test target endpoint
    Log-Info "Testing target endpoint..."
    aws dms test-connection `
        --replication-instance-arn $ReplicationInstanceArn `
        --endpoint-arn $TargetEndpointArn
    
    Start-Sleep -Seconds 30
    
    Log-Info "Endpoint tests initiated. Check AWS Console for results."
}

# Populate source database
function Initialize-SourceDatabase {
    Log-Info "Populating source database with sample data..."
    
    if (-not $DbPassword) {
        $securePassword = Read-Host "Enter database password" -AsSecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        $script:DbPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }
    
    Push-Location $ScriptDir
    
    try {
        $env:DB_PASSWORD = $DbPassword
        python populate_source.py --host $SourceHost --password $DbPassword
        Log-Info "Source database populated successfully!"
    } catch {
        Log-Error "Failed to populate source database: $_"
        exit 1
    } finally {
        Pop-Location
    }
}

# Start migration task
function Start-MigrationTask {
    Log-Info "Starting DMS migration task..."
    
    # Get current task status
    $taskInfo = aws dms describe-replication-tasks `
        --filters "Name=replication-task-arn,Values=$TaskArn" `
        --query 'ReplicationTasks[0]' | ConvertFrom-Json
    
    $taskStatus = $taskInfo.Status
    Log-Info "Current task status: $taskStatus"
    
    if ($taskStatus -eq "ready" -or $taskStatus -eq "stopped") {
        aws dms start-replication-task `
            --replication-task-arn $TaskArn `
            --start-replication-task-type start-replication
        
        Log-Info "Migration task started!"
    } else {
        Log-Warn "Task is in status: $taskStatus. May already be running."
    }
}

# Monitor migration progress
function Watch-MigrationProgress {
    Log-Info "Monitoring migration progress..."
    
    $maxWait = 1800  # 30 minutes
    $elapsed = 0
    $checkInterval = 30
    
    while ($elapsed -lt $maxWait) {
        $taskInfo = aws dms describe-replication-tasks `
            --filters "Name=replication-task-arn,Values=$TaskArn" `
            --query 'ReplicationTasks[0]' | ConvertFrom-Json
        
        $taskStatus = $taskInfo.Status
        $progress = $taskInfo.ReplicationTaskStats.FullLoadProgressPercent
        
        Log-Info "Status: $taskStatus | Progress: $progress%"
        
        if ($taskStatus -eq "stopped" -and $progress -eq 100) {
            Log-Info "Migration completed successfully!"
            return
        } elseif ($taskStatus -eq "failed") {
            Log-Error "Migration task failed!"
            exit 1
        }
        
        Start-Sleep -Seconds $checkInterval
        $elapsed += $checkInterval
    }
    
    Log-Warn "Migration monitoring timed out. Check AWS Console for status."
}

# Validate migration
function Test-Migration {
    Log-Info "Validating migration results..."
    
    Push-Location $ScriptDir
    
    try {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        python validate_migration.py `
            --source-host $SourceHost `
            --source-password $DbPassword `
            --target-host $TargetHost `
            --target-password $DbPassword `
            --output-file "validation_report_$timestamp.json"
        
        Log-Info "Validation complete!"
    } catch {
        Log-Error "Validation failed: $_"
    } finally {
        Pop-Location
    }
}

# Main execution
function Main {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "DMS Migration Orchestration Started" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    
    Test-Prerequisites
    Get-TerraformOutputs
    
    Write-Host ""
    Write-Host "This script will:"
    Write-Host "  1. Test DMS endpoint connections"
    Write-Host "  2. Populate source database with sample data"
    Write-Host "  3. Start the DMS migration task"
    Write-Host "  4. Monitor migration progress"
    Write-Host "  5. Validate migration results"
    Write-Host ""
    
    $confirm = Read-Host "Continue? (y/n)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Log-Info "Aborted by user"
        exit 0
    }
    
    Test-DmsEndpoints
    
    if (-not $SkipPopulate) {
        Initialize-SourceDatabase
    }
    
    Start-MigrationTask
    Watch-MigrationProgress
    
    if (-not $SkipValidation) {
        Test-Migration
    }
    
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "DMS Migration Orchestration Completed" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
}

# Run main function
Main
