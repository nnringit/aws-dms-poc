# -----------------------------------------------------------------------------
# AWS DMS Resources
# -----------------------------------------------------------------------------

# IAM Role for DMS
resource "aws_iam_role" "dms_vpc_role" {
  name = "dms-vpc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-dms-vpc-role"
  }
}

resource "aws_iam_role_policy_attachment" "dms_vpc_policy" {
  role       = aws_iam_role.dms_vpc_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

# IAM Role for DMS CloudWatch Logs
resource "aws_iam_role" "dms_cloudwatch_role" {
  name = "dms-cloudwatch-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-dms-cloudwatch-role"
  }
}

resource "aws_iam_role_policy_attachment" "dms_cloudwatch_policy" {
  role       = aws_iam_role.dms_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
}

# DMS Replication Instance
resource "aws_dms_replication_instance" "main" {
  replication_instance_id     = "${var.project_name}-replication-instance"
  replication_instance_class  = var.dms_instance_class
  allocated_storage           = var.dms_allocated_storage
  engine_version              = var.dms_engine_version
  
  vpc_security_group_ids      = [aws_security_group.dms.id]
  replication_subnet_group_id = aws_dms_replication_subnet_group.main.id

  publicly_accessible         = false
  multi_az                    = false
  auto_minor_version_upgrade  = true

  apply_immediately = true

  tags = {
    Name = "${var.project_name}-replication-instance"
  }

  depends_on = [
    aws_iam_role_policy_attachment.dms_vpc_policy,
    aws_iam_role_policy_attachment.dms_cloudwatch_policy
  ]
}

# DMS Source Endpoint
resource "aws_dms_endpoint" "source" {
  endpoint_id   = "${var.project_name}-source-endpoint"
  endpoint_type = "source"
  engine_name   = "postgres"

  server_name   = aws_db_instance.source.address
  port          = aws_db_instance.source.port
  database_name = var.db_name
  username      = var.db_username
  password      = var.db_password

  ssl_mode = "require"

  tags = {
    Name = "${var.project_name}-source-endpoint"
    Role = "Source"
  }
}

# DMS Target Endpoint
resource "aws_dms_endpoint" "target" {
  endpoint_id   = "${var.project_name}-target-endpoint"
  endpoint_type = "target"
  engine_name   = "postgres"

  server_name   = aws_db_instance.target.address
  port          = aws_db_instance.target.port
  database_name = var.db_name
  username      = var.db_username
  password      = var.db_password

  ssl_mode = "require"

  tags = {
    Name = "${var.project_name}-target-endpoint"
    Role = "Target"
  }
}

# DMS Replication Task
resource "aws_dms_replication_task" "main" {
  replication_task_id      = "${var.project_name}-migration-task"
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target.endpoint_arn

  migration_type = "full-load-and-cdc"

  # Table mappings - migrate all tables from public schema
  table_mappings = jsonencode({
    rules = [
      {
        rule-type = "selection"
        rule-id   = "1"
        rule-name = "include-all-tables"
        object-locator = {
          schema-name = "public"
          table-name  = "%"
        }
        rule-action = "include"
      }
    ]
  })

  # Replication task settings
  replication_task_settings = jsonencode({
    TargetMetadata = {
      TargetSchema         = "public"
      SupportLobs          = true
      FullLobMode          = false
      LobChunkSize         = 64
      LimitedSizeLobMode   = true
      LobMaxSize           = 32768
      InlineLobMaxSize     = 0
      LoadMaxFileSize      = 0
      ParallelLoadThreads  = 0
      ParallelLoadBufferSize = 0
      BatchApplyEnabled    = false
    }
    FullLoadSettings = {
      TargetTablePrepMode        = "DROP_AND_CREATE"
      CreatePkAfterFullLoad      = false
      StopTaskCachedChangesApplied = false
      StopTaskCachedChangesNotApplied = false
      MaxFullLoadSubTasks        = 8
      TransactionConsistencyTimeout = 600
      CommitRate                 = 10000
    }
    Logging = {
      EnableLogging = true
      LogComponents = [
        {
          Id       = "TRANSFORMATION"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "SOURCE_UNLOAD"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "IO"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "TARGET_LOAD"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "PERFORMANCE"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "SOURCE_CAPTURE"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "SORTER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "REST_SERVER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "VALIDATOR_EXT"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "TARGET_APPLY"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "TASK_MANAGER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "TABLES_MANAGER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "METADATA_MANAGER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "FILE_FACTORY"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "COMMON"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "ADDONS"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "DATA_STRUCTURE"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "COMMUNICATION"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        },
        {
          Id       = "FILE_TRANSFER"
          Severity = "LOGGER_SEVERITY_DEFAULT"
        }
      ]
    }
    ControlTablesSettings = {
      historyTimeslotInMinutes   = 5
      ControlSchema              = ""
      HistoryTimeslotInMinutes   = 5
      HistoryTableEnabled        = false
      SuspendedTablesTableEnabled = false
      StatusTableEnabled         = false
    }
    StreamBufferSettings = {
      StreamBufferCount  = 3
      StreamBufferSizeInMB = 8
      CtrlStreamBufferSizeInMB = 5
    }
    ChangeProcessingDdlHandlingPolicy = {
      HandleSourceTableDropped   = true
      HandleSourceTableTruncated = true
      HandleSourceTableAltered   = true
    }
    ErrorBehavior = {
      DataErrorPolicy            = "LOG_ERROR"
      DataTruncationErrorPolicy  = "LOG_ERROR"
      DataErrorEscalationPolicy  = "SUSPEND_TABLE"
      DataErrorEscalationCount   = 0
      TableErrorPolicy           = "SUSPEND_TABLE"
      TableErrorEscalationPolicy = "STOP_TASK"
      TableErrorEscalationCount  = 0
      RecoverableErrorCount      = -1
      RecoverableErrorInterval   = 5
      RecoverableErrorThrottling = true
      RecoverableErrorThrottlingMax = 1800
      RecoverableErrorStopRetryAfterThrottlingMax = false
      ApplyErrorDeletePolicy     = "IGNORE_RECORD"
      ApplyErrorInsertPolicy     = "LOG_ERROR"
      ApplyErrorUpdatePolicy     = "LOG_ERROR"
      ApplyErrorEscalationPolicy = "LOG_ERROR"
      ApplyErrorEscalationCount  = 0
      ApplyErrorFailOnTruncationDdl = false
      FullLoadIgnoreConflicts    = true
      FailOnTransactionConsistencyBreached = false
      FailOnNoTablesCaptured     = false
    }
    ValidationSettings = {
      EnableValidation                 = true
      ValidationMode                   = "ROW_LEVEL"
      ThreadCount                      = 5
      PartitionSize                    = 10000
      FailureMaxCount                  = 10000
      RecordFailureDelayInMinutes      = 5
      RecordSuspendDelayInMinutes      = 30
      MaxKeyColumnSize                 = 8096
      TableFailureMaxCount             = 1000
      ValidationOnly                   = false
      HandleCollationDiff              = false
      RecordFailureDelayLimitInMinutes = 0
      SkipLobColumns                   = false
      ValidationPartialLobSize         = 0
      ValidationQueryCdcDelaySeconds   = 0
    }
    ChangeProcessingTuning = {
      BatchApplyPreserveTransaction  = true
      BatchApplyTimeoutMin           = 1
      BatchApplyTimeoutMax           = 30
      BatchApplyMemoryLimit          = 500
      BatchSplitSize                 = 0
      MinTransactionSize             = 1000
      CommitTimeout                  = 1
      MemoryLimitTotal               = 1024
      MemoryKeepTime                 = 60
      StatementCacheSize             = 50
    }
  })

  # Start the task when it's ready
  start_replication_task = false  # Set to false initially, start after data is loaded

  tags = {
    Name = "${var.project_name}-migration-task"
  }

  depends_on = [
    aws_dms_replication_instance.main,
    aws_dms_endpoint.source,
    aws_dms_endpoint.target
  ]
}
