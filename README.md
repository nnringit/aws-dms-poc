# AWS DMS Homogeneous Database Migration POC

A complete Proof of Concept demonstrating AWS Database Migration Service (DMS) for homogeneous PostgreSQL-to-PostgreSQL migration with full infrastructure-as-code using Terraform.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              VPC (10.0.0.0/16)                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        Public Subnets                                │   │
│  │  ┌─────────────────┐                    ┌─────────────────┐         │   │
│  │  │   Source RDS    │                    │   Target RDS    │         │   │
│  │  │   PostgreSQL    │                    │   PostgreSQL    │         │   │
│  │  │   (with data)   │                    │   (migrated)    │         │   │
│  │  └────────┬────────┘                    └────────┬────────┘         │   │
│  └───────────┼──────────────────────────────────────┼──────────────────┘   │
│              │                                      │                       │
│  ┌───────────┼──────────────────────────────────────┼──────────────────┐   │
│  │           │         Private Subnets              │                   │   │
│  │           ▼                                      ▼                   │   │
│  │  ┌─────────────────────────────────────────────────────────────┐    │   │
│  │  │                    AWS DMS                                   │    │   │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │    │   │
│  │  │  │    Source    │  │ Replication  │  │     Target       │   │    │   │
│  │  │  │   Endpoint   │──│   Instance   │──│    Endpoint      │   │    │   │
│  │  │  └──────────────┘  └──────────────┘  └──────────────────┘   │    │   │
│  │  └─────────────────────────────────────────────────────────────┘    │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## ✨ Features

- **Infrastructure as Code** - Complete Terraform configuration for all AWS resources
- **Homogeneous Migration** - PostgreSQL 15.10 to PostgreSQL 15.10
- **Full Load + CDC** - Initial data load with ongoing Change Data Capture
- **Data Validation** - Built-in DMS validation and Python validation scripts
- **Sample E-commerce Data** - Realistic dataset with 6 tables and ~1000 records
- **Security** - VPC isolation, security groups, encrypted storage

## 📁 Project Structure

```
aws-dms-poc/
├── terraform/
│   ├── main.tf              # Provider and backend configuration
│   ├── variables.tf         # Input variables with defaults
│   ├── outputs.tf           # Output values (endpoints, ARNs)
│   ├── vpc.tf               # VPC, subnets, security groups
│   ├── rds.tf               # Source and Target RDS instances
│   ├── dms.tf               # DMS replication instance, endpoints, task
│   ├── iam.tf               # IAM roles and policies
│   └── terraform.tfvars     # Variable values (customize this)
├── scripts/
│   ├── setup_source_data.sql    # E-commerce sample data DDL & DML
│   ├── populate_source.py       # Load data into source database
│   ├── validate_migration.py    # Compare source and target
│   ├── run_migration.sh         # Linux/Mac automation script
│   └── run_migration.ps1        # Windows PowerShell automation
├── .gitignore
├── requirements.txt         # Python dependencies
└── README.md
```

## 🔧 Prerequisites

- **AWS CLI** configured with credentials (`aws configure`)
- **Terraform** >= 1.0 ([Install](https://developer.hashicorp.com/terraform/downloads))
- **Python** 3.8+ with pip
- **AWS Permissions** for RDS, DMS, VPC, IAM

## 🚀 Quick Start

### 1. Clone and Configure

```bash
git clone <repository-url>
cd aws-dms-poc

# Edit terraform.tfvars with your settings
cd terraform
```

### 2. Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

This creates (~10-15 minutes):
- VPC with public/private subnets
- 2 RDS PostgreSQL instances (source & target)
- DMS replication instance
- DMS endpoints and migration task

### 3. Install Python Dependencies

```bash
pip install -r requirements.txt
```

### 4. Populate Source Database

```bash
# Get the source endpoint from terraform output
terraform output source_db_endpoint

# Run the population script
python scripts/populate_source.py \
  --host <source-db-endpoint> \
  --port 5432 \
  --database ecommerce \
  --username dbadmin \
  --password <your-password>
```

### 5. Start Migration

```bash
# Get the task ARN
TASK_ARN=$(aws dms describe-replication-tasks \
  --query "ReplicationTasks[0].ReplicationTaskArn" \
  --output text)

# Start the migration
aws dms start-replication-task \
  --replication-task-arn $TASK_ARN \
  --start-replication-task-type start-replication
```

### 6. Monitor Progress

```bash
# Check task status
aws dms describe-replication-tasks \
  --query "ReplicationTasks[0].{Status:Status,Progress:ReplicationTaskStats.FullLoadProgressPercent}"
```

### 7. Validate Migration

```bash
python scripts/validate_migration.py \
  --source-host <source-endpoint> \
  --target-host <target-endpoint> \
  --source-port 5432 --target-port 5432 \
  --source-database ecommerce --target-database ecommerce \
  --source-username dbadmin --target-username dbadmin \
  --source-password <password> --target-password <password>
```

## 📊 Sample Data Schema

The source database contains an e-commerce schema:

| Table | Records | Description |
|-------|---------|-------------|
| categories | 10 | Product categories |
| customers | 50 | Customer profiles |
| products | 100 | Product catalog |
| inventory | 100 | Stock levels |
| orders | 200 | Order headers |
| order_items | 530 | Order line items |

**Total: ~990 records across 6 tables**

## ⚙️ Configuration

Edit `terraform/terraform.tfvars` to customize:

```hcl
# Project Settings
project_name = "dms-poc"
aws_region   = "us-east-1"

# Database Settings
db_username  = "dbadmin"
db_password  = "YourSecurePassword123!"  # Change this!
db_name      = "ecommerce"

# Instance Sizes (for POC, use smallest)
db_instance_class  = "db.t3.micro"
dms_instance_class = "dms.t3.micro"
```

## 🧹 Cleanup

**Important:** Stop the DMS task before destroying to avoid errors.

```bash
# Stop the running task
aws dms stop-replication-task --replication-task-arn <task-arn>

# Wait for it to stop, then destroy
cd terraform
terraform destroy -auto-approve
```

## 💰 Cost Considerations

For a POC running a few hours:
- **RDS** (2x db.t3.micro): ~$0.03/hour
- **DMS** (dms.t3.micro): ~$0.02/hour
- **NAT Gateway** (2x): ~$0.09/hour
- **Data Transfer**: Minimal

**Estimated cost: ~$0.15/hour or ~$3.50/day**

> ⚠️ Remember to run `terraform destroy` when done to avoid ongoing charges!

## 🔍 Troubleshooting

### DMS Task Fails to Start
- Check security groups allow port 5432 between DMS and RDS
- Verify database credentials in DMS endpoints
- Test endpoint connections: `aws dms test-connection`

### Cannot Connect to RDS from Local Machine
- Ensure RDS is in public subnet with `publicly_accessible = true`
- Check security group allows your IP on port 5432

### Terraform Errors
- Run `terraform init` to download providers
- Check AWS credentials: `aws sts get-caller-identity`
- Verify region matches in CLI and terraform

## 📝 License

MIT License - feel free to use this for learning and development.

## 💬 AI Prompt Used

This project was generated using the following prompt with GitHub Copilot:

> Create a sample Data migration pipeline using DMS to migrate homogeneous database:
> 1. Source database created with sample data
> 2. Use DMS to migrate that to a target database
> 3. Validate the source & target database are the same

This prompt creates a complete infrastructure-as-code solution with Terraform, Python scripts for data population and validation, and automation scripts for both Linux and Windows.

## 🤝 Contributing

Contributions welcome! Please submit issues and pull requests.
