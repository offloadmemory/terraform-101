# Terraform Multi-Account / Multi-Environment Demo — Part 1 (Pure Terraform) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the pure-Terraform half of a live demonstration: hand-rolled modules plus three environment accounts (dev/staging/prod), each with network/database/ecs components, structured to surface Terraform's multi-account pain points before a later Terragrunt act.

**Architecture:** Environment-centric layout — `environments/{env}/{component}/` holds a thin root (provider + backend + module call + tfvars); `modules/` at repo root holds four hand-rolled modules (state, network, database, ecs) shared by every environment. Each component is its own Terraform workspace with its own S3 backend. Cross-component data flows through `data "terraform_remote_state"` with hardcoded backend keys — a deliberate brittleness the demo narrates. A `bootstrap/` workspace creates per-account state buckets first (the chicken-and-egg the demo names on stage).

**Tech Stack:** Terraform 1.x (v1.13.4 local), AWS provider ~5.x, HCL. Placeholder container `nginx:alpine` on ECS Fargate behind an ALB; RDS PostgreSQL.

**Spec:** `docs/superpowers/specs/2026-08-22-terraform-multi-account-demo-design.md`

## Global Constraints

- Terraform 1.x; AWS provider `~> 5.0` pinned via `required_providers` in every module and root component.
- Every module and every root component must pass `terraform fmt` and `terraform validate` (validate after `terraform init -backend=false`, which needs no AWS credentials).
- No Terragrunt code anywhere (Act 2 deferred). `terragrunt-live/` must NOT be created yet.
- One environment = one AWS account via named profile (`dev`/`staging`/`prod`), read from `profile` variable.
- Placeholder app container image is `nginx:alpine`; ALB health check path `/`, matcher `200`.
- RDS uses `manage_master_password = true` — never put a password literal in code.
- Bucket naming convention `tfstate-<env>` and `tfstate-<env>-lock`, state key `<env>/<component>/terraform.tfstate`.
- Default region `us-east-1`; default `nat_gateway_count = 1` for cost.
- Every task ends with a git commit. Task verify steps run from the repo root where noted.

---

### Task 1: Repo scaffolding + `modules/state`

The bootstrap module — the state backend itself as code.

**Files:**
- Create: `.gitignore`
- Create: `modules/state/main.tf`
- Create: `modules/state/variables.tf`
- Create: `modules/state/outputs.tf`
- Create: `modules/state/versions.tf`

**Interfaces:**
- Consumes: nothing.
- Produces: `modules/state` with inputs `bucket_name`, `table_name`, `region`, `tags`; outputs `bucket_name`, `table_name`. Used by Task 5 (`environments/bootstrap`).

- [ ] **Step 1: Create `.gitignore`**

```gitignore
.terraform/
*.tfstate
*.tfstate.*
crash.log
```

- [ ] **Step 2: Write `modules/state/variables.tf`**

```hcl
variable "bucket_name" {
  description = "Globally unique S3 bucket name for remote state"
  type        = string
}

variable "table_name" {
  description = "DynamoDB table name for state locking"
  type        = string
}

variable "region" {
  description = "AWS region for state infrastructure"
  type        = string
}

variable "tags" {
  description = "Common tags applied to state resources"
  type        = map(string)
  default     = {}
}
```

- [ ] **Step 3: Write `modules/state/main.tf`**

```hcl
resource "aws_s3_bucket" "state" {
  bucket        = var.bucket_name
  force_destroy = false

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "state_lock" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = var.tags
}
```

- [ ] **Step 4: Write `modules/state/outputs.tf`**

```hcl
output "bucket_name" {
  value = aws_s3_bucket.state.id
}

output "table_name" {
  value = aws_dynamodb_table.state_lock.name
}
```

- [ ] **Step 5: Write `modules/state/versions.tf`**

```hcl
terraform {
  required_version = "~> 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

- [ ] **Step 6: Verify the module validates**

Run:
```bash
cd modules/state && terraform fmt --recursive && terraform init -backend=false && terraform validate
```
Expected: `fmt` reports no diffs, `init` succeeds without credentials, `validate` prints `Success! The configuration is valid.` Then `cd ../..` back to repo root.

- [ ] **Step 7: Commit**

```bash
git add .gitignore modules/state
git commit -m "feat: add state module (S3 bucket + DynamoDB lock table)"
```

---

### Task 2: `modules/network`

The environment network foundation: VPC, subnets, IGW, NAT, route tables, and the three security groups (ALB / ECS / DB).

**Files:**
- Create: `modules/network/main.tf`
- Create: `modules/network/variables.tf`
- Create: `modules/network/outputs.tf`
- Create: `modules/network/versions.tf`

**Interfaces:**
- Consumes: nothing.
- Produces: `modules/network` — inputs `env_name`, `region`, `vpc_cidr`, `azs`, `public_subnet_cidrs`, `private_subnet_cidrs`, `nat_gateway_count`, `tags`; outputs `vpc_id`, `vpc_cidr_block`, `public_subnet_ids`, `private_subnet_ids`, `alb_sg_id`, `ecs_sg_id`, `db_sg_id`. Consumed by Tasks 3–4 (as wiring in environment roots) and Tasks 6–8.

- [ ] **Step 1: Write `modules/network/variables.tf`**

```hcl
variable "env_name" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "azs" {
  description = "Availability zones, one per subnet index"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "nat_gateway_count" {
  description = "Number of NAT gateways (minimum 1)"
  type        = number
  default     = 1
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
```

- [ ] **Step 2: Write `modules/network/main.tf`**

```hcl
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "${var.env_name}-vpc" })
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, { Name = "${var.env_name}-public-${count.index + 1}" })
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(var.tags, { Name = "${var.env_name}-private-${count.index + 1}" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.env_name}-igw" })
}

resource "aws_eip" "nat" {
  count  = var.nat_gateway_count
  domain = "vpc"
}

resource "aws_nat_gateway" "this" {
  count = var.nat_gateway_count

  allocation_id = aws_eip.public[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, { Name = "${var.env_name}-nat-${count.index + 1}" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.env_name}-public-rt" })
}

resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count = var.nat_gateway_count

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.env_name}-private-rt-${count.index + 1}" })
}

resource "aws_route" "private_nat" {
  count = var.nat_gateway_count

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index].id
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index % var.nat_gateway_count].id
}

resource "aws_security_group" "alb" {
  name        = "${var.env_name}-alb-sg"
  description = "ALB ingress on 80/443 from anywhere"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.env_name}-alb-sg" })
}

resource "aws_security_group" "ecs" {
  name        = "${var.env_name}-ecs-sg"
  description = "ECS tasks receive traffic from the ALB only"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.env_name}-ecs-sg" })
}

resource "aws_security_group" "db" {
  name        = "${var.env_name}-db-sg"
  description = "PostgreSQL accessible from the ECS SG only"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.env_name}-db-sg" })
}
```

- [ ] **Step 3: Write `modules/network/outputs.tf`**

```hcl
output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr_block" {
  value = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "ecs_sg_id" {
  value = aws_security_group.ecs.id
}

output "db_sg_id" {
  value = aws_security_group.db.id
}
```

- [ ] **Step 4: Write `modules/network/versions.tf`**

```hcl
terraform {
  required_version = "~> 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

- [ ] **Step 5: Verify the module**

Run: `cd modules/network && terraform fmt --recursive && terraform init -backend=false && terraform validate`
Expected: fmt clean; `Success! The configuration is valid.`. Then `cd ../..`.

- [ ] **Step 6: Commit**

```bash
git add modules/network
git commit -m "feat: add network module (VPC, subnets, IGW, NAT, route tables, SGs)"
```

---

### Task 3: `modules/database`

**Files:**
- Create: `modules/database/main.tf`
- Create: `modules/database/variables.tf`
- Create: `modules/database/outputs.tf`
- Create: `modules/database/versions.tf`

**Interfaces:**
- Consumes: nothing directly (inputs come from the environment root, which reads network via `terraform_remote_state` in Task 6).
- Produces: `modules/database` — inputs `env`, `db_name`, `instance_class`, `allocated_storage`, `backup_retention_period`, `multi_az`, `deletion_protection`, `skip_final_snapshot`, `subnet_ids`, `db_sg_id`, `tags`; outputs `db_endpoint`, `db_name`, `db_port`, `db_sg_id`.

- [ ] **Step 1: Write `modules/database/variables.tf`**

```hcl
variable "env" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

variable "db_name" {
  description = "Name of the initial database"
  type        = string
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "allocated_storage" {
  description = "Allocated storage in GiB"
  type        = number
  default     = 20
}

variable "backup_retention_period" {
  description = "Backup retention in days"
  type        = number
  default     = 1
}

variable "multi_az" {
  description = "Deploy across multiple AZs"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Prevent accidental deletion"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy (dev convenience)"
  type        = bool
  default     = true
}

variable "subnet_ids" {
  description = "Private subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "db_sg_id" {
  description = "Security group id that allows 5432 ingress from ECS"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
```

- [ ] **Step 2: Write `modules/database/main.tf`**

```hcl
resource "aws_db_subnet_group" "this" {
  name       = "${var.env}-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = var.tags
}

resource "aws_db_instance" "this" {
  identifier             = "${var.env}-postgres"
  engine                 = "postgres"
  engine_version         = "16.4"
  instance_class         = var.instance_class
  allocated_storage      = var.allocated_storage
  storage_type           = "gp3"
  storage_encrypted      = true
  db_name                = var.db_name
  username               = "postgres"
  manage_master_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.db_sg_id]

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = var.skip_final_snapshot
  publicly_accessible     = false

  tags = var.tags
}
```

- [ ] **Step 3: Write `modules/database/outputs.tf`**

```hcl
output "db_endpoint" {
  value = aws_db_instance.this.address
}

output "db_name" {
  value = aws_db_instance.this.db_name
}

output "db_port" {
  value = aws_db_instance.this.port
}

output "db_sg_id" {
  value = aws_db_instance.this.vpc_security_group_ids[0]
}
```

- [ ] **Step 4: Write `modules/database/versions.tf`**

```hcl
terraform {
  required_version = "~> 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

- [ ] **Step 5: Verify the module**

Run: `cd modules/database && terraform fmt --recursive && terraform init -backend=false && terraform validate`
Expected: `Success! The configuration is valid.`. Then `cd ../..`.

- [ ] **Step 6: Commit**

```bash
git add modules/database
git commit -m "feat: add database module (RDS PostgreSQL, managed password)"
```

---

### Task 4: `modules/ecs`

**Files:**
- Create: `modules/ecs/main.tf`
- Create: `modules/ecs/variables.tf`
- Create: `modules/ecs/outputs.tf`
- Create: `modules/ecs/versions.tf`

**Interfaces:**
- Consumes: nothing directly.
- Produces: `modules/ecs` — inputs `env`, `region`, `image`, `cpu`, `memory`, `desired_count`, `vpc_id`, `public_subnet_ids`, `private_subnet_ids`, `alb_sg_id`, `ecs_sg_id`, `tags`; outputs `cluster_name`, `service_name`, `alb_dns_name`.

- [ ] **Step 1: Write `modules/ecs/variables.tf`**

```hcl
variable "env" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "image" {
  description = "Container image for the app task"
  type        = string
  default     = "nginx:alpine"
}

variable "cpu" {
  description = "Task CPU units"
  type        = string
  default     = "256"
}

variable "memory" {
  description = "Task memory MiB"
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Number of running tasks"
  type        = number
  default     = 1
}

variable "vpc_id" {
  description = "VPC ID for the target group"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the Fargate tasks"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "ALB security group ID"
  type        = string
}

variable "ecs_sg_id" {
  description = "ECS task security group ID"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
```

- [ ] **Step 2: Write `modules/ecs/main.tf`**

```hcl
resource "aws_ecs_cluster" "this" {
  name = "${var.env}-cluster"

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.env}"
  retention_in_days = 7

  tags = var.tags
}

resource "aws_iam_role" "ecs_execution" {
  name = "${var.env}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name = "${var.env}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.env}-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = var.image
      essential = true
      portMappings = [{ containerPort = 80, protocol = "tcp" }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_lb" "this" {
  name               = "${var.env}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [var.alb_sg_id]

  tags = var.tags
}

resource "aws_lb_target_group" "app" {
  name        = "${var.env}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = var.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_ecs_service" "app" {
  name            = "${var.env}-app-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.http]
}
```

- [ ] **Step 3: Write `modules/ecs/outputs.tf`**

```hcl
output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_name" {
  value = aws_ecs_service.app.name
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}
```

- [ ] **Step 4: Write `modules/ecs/versions.tf`**

```hcl
terraform {
  required_version = "~> 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

- [ ] **Step 5: Verify the module**

Run: `cd modules/ecs && terraform fmt --recursive && terraform init -backend=false && terraform validate`
Expected: `Success!`. Then `cd ../..`.

- [ ] **Step 6: Commit**

```bash
git add modules/ecs
git commit -m "feat: add ecs module (cluster, Fargate service, ALB, IAM roles)"
```

---

### Task 5: `environments/bootstrap`

One apply, all three accounts: creates `tfstate-dev`, `tfstate-staging`, `tfstate-prod` buckets + lock tables via three provider aliases. Uses local state — the chicken-and-egg made explicit.

**Files:**
- Create: `environments/bootstrap/main.tf`
- Create: `environments/bootstrap/versions.tf`

**Interfaces:**
- Consumes: `modules/state` (Task 1).
- Produces: S3 bucket `tfstate-<env>` + DynamoDB table `tfstate-<env>-lock` per account. Consumed as the backend by every component in Tasks 6–8.

- [ ] **Step 1: Write `environments/bootstrap/main.tf`**

```hcl
provider "aws" {
  alias   = "dev"
  region  = "us-east-1"
  profile = "dev"
}

provider "aws" {
  alias   = "staging"
  region  = "us-east-1"
  profile = "staging"
}

provider "aws" {
  alias   = "prod"
  region  = "us-east-1"
  profile = "prod"
}

module "state_dev" {
  source = "../../modules/state"

  providers = {
    aws = aws.dev
  }

  bucket_name = "tfstate-dev"
  table_name  = "tfstate-dev-lock"
  region      = "us-east-1"
  tags = {
    Name    = "tfstate-dev"
    env     = "dev"
    project = "terraform-101-demo"
  }
}

module "state_staging" {
  source = "../../modules/state"

  providers = {
    aws = aws.staging
  }

  bucket_name = "tfstate-staging"
  table_name  = "tfstate-staging-lock"
  region      = "us-east-1"
  tags = {
    Name    = "tfstate-staging"
    env     = "staging"
    project = "terraform-101-demo"
  }
}

module "state_prod" {
  source = "../../modules/state"

  providers = {
    aws = aws.prod
  }

  bucket_name = "tfstate-prod"
  table_name  = "tfstate-prod-lock"
  region      = "us-east-1"
  tags = {
    Name    = "tfstate-prod"
    env     = "prod"
    project = "terraform-101-demo"
  }
}
```

- [ ] **Step 2: Write `environments/bootstrap/versions.tf`**

```hcl
terraform {
  required_version = "~> 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

- [ ] **Step 3: Verify the workspace parses**

Run: `cd environments/bootstrap && terraform fmt --check && terraform init -backend=false && terraform validate`
Expected: `Success!`. Then `cd ../..`.

> Note: no `backend` block is present — bootstrap uses local state on purpose. Say this on stage: *"you can't store state in a bucket that doesn't exist yet."*

- [ ] **Step 4: Commit**

```bash
git add environments/bootstrap
git commit -m "feat: add multi-account bootstrap workspace for state buckets"
```

---

### Task 6: `environments/dev` (network, database, ecs)

The complete dev environment. This is the full, verbose pattern that staging/prod repeat (with different values) — and the repetition itself is the demo.

**Files:**
- Create: `environments/dev/network/main.tf`, `environments/dev/network/backend.tf`, `environments/dev/network/versions.tf`, `environments/dev/network/variables.tf`, `environments/dev/network/terraform.tfvars`, `environments/dev/network/outputs.tf`
- Create: `environments/dev/database/main.tf`, `environments/dev/database/backend.tf`, `environments/dev/database/versions.tf`, `environments/dev/database/variables.tf`, `environments/dev/database/terraform.tfvars`, `environments/dev/database/outputs.tf`
- Create: `environments/dev/ecs/main.tf`, `environments/dev/ecs/backend.tf`, `environments/dev/ecs/versions.tf`, `environments/dev/ecs/variables.tf`, `environments/dev/ecs/terraform.tfvars`, `environments/dev/ecs/outputs.tf`

**Interfaces:**
- Consumes: `modules/network`, `modules/database`, `modules/ecs`; `data "terraform_remote_state"` reading the dev network backend (key `dev/network/terraform.tfstate`).
- Produces: the dev environment's full resource set. `environments/dev/network/outputs.tf` is read by dev database/ecs via remote_state, and the same shape is copied to staging/prod in Tasks 7–8.

- [ ] **Step 1: Write `environments/dev/network/main.tf`**

```hcl
provider "aws" {
  region  = var.region
  profile = var.profile
}

module "network" {
  source = "../../../modules/network"

  env_name              = var.env_name
  region                = var.region
  vpc_cidr              = var.vpc_cidr
  azs                   = var.azs
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  nat_gateway_count     = var.nat_gateway_count
  tags                  = var.tags
}
```

- [ ] **Step 2: Write `environments/dev/network/backend.tf`**

```hcl
terraform {
  backend "s3" {
    bucket         = "tfstate-dev"
    key            = "dev/network/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tfstate-dev-lock"
    encrypt        = true
  }
}
```

- [ ] **Step 3: Write `environments/dev/network/variables.tf`**

```hcl
variable "region" {
  type = string
}

variable "profile" {
  type = string
}

variable "env_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "nat_gateway_count" {
  type    = number
  default = 1
}

variable "tags" {
  type    = map(string)
  default = {}
}
```

- [ ] **Step 4: Write `environments/dev/network/terraform.tfvars`**

```hcl
region              = "us-east-1"
profile             = "dev"
env_name            = "dev"
vpc_cidr            = "10.0.0.0/16"
azs                 = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
nat_gateway_count   = 1
tags = {
  env       = "dev"
  project   = "terraform-101-demo"
  managed_by = "terraform"
}
```

- [ ] **Step 5: Write `environments/dev/network/outputs.tf`**

```hcl
output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "alb_sg_id" {
  value = module.network.alb_sg_id
}

output "ecs_sg_id" {
  value = module.network.ecs_sg_id
}

output "db_sg_id" {
  value = module.network.db_sg_id
}
```

- [ ] **Step 6: Write `environments/dev/network/versions.tf`**

```hcl
terraform {
  required_version = "~> 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

- [ ] **Step 7: Write `environments/dev/database/main.tf`**

```hcl
provider "aws" {
  region  = var.region
  profile = var.profile
}

data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket         = "tfstate-${var.env_name}"
    key            = "network/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tfstate-${var.env_name}-lock"
  }
}

module "database" {
  source = "../../../modules/database"

  env                    = var.env_name
  db_name                = var.db_name
  instance_class         = var.instance_class
  allocated_storage      = var.allocated_storage
  backup_retention_period = var.backup_retention_period
  multi_az               = var.multi_az
  deletion_protection    = var.deletion_protection
  skip_final_snapshot    = var.skip_final_snapshot
  subnet_ids             = data.terraform_remote_state.network.outputs.private_subnet_ids
  db_sg_id               = data.terraform_remote_state.network.outputs.db_sg_id
  tags                   = var.tags
}
```

- [ ] **Step 8: Write `environments/dev/database/backend.tf`**

```hcl
terraform {
  backend "s3" {
    bucket         = "tfstate-dev"
    key           = "database/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tfstate-dev-lock"
    encrypt        = true
  }
}
```

- [ ] **Step 9: Write `environments/dev/database/variables.tf`**

```hcl
variable "region" {
  type = string
}

variable "profile" {
  type = string
}

variable "env_name" {
  type = string
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "backup_retention_period" {
  type    = number
  default = 1
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
```

- [ ] **Step 10: Write `environments/dev/database/terraform.tfvars`**

```hcl
region              = "us-east-1"
profile             = "dev"
env_name            = "dev"
db_name             = "appdb"
instance_class      = "db.t4g.micro"
allocated_storage   = 20
backup_retention_period = 1
multi_az            = false
deletion_protection = false
skip_final_snapshot = true
tags = {
  env       = "dev"
  project   = "terraform-101-demo"
  managed_by = "terraform"
}
```

- [ ] **Step 11: Write `environments/dev/database/outputs.tf`**

```hcl
output "db_endpoint" {
  value = module.database.db_endpoint
}

output "db_name" {
  value = module.database.db_name
}

output "db_port" {
  value = module.database.db_port
}
```

- [ ] **Step 12: Write `environments/dev/database/versions.tf`**

```hcl
terraform {
  required_version = "~> 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

- [ ] **Step 13: Write `environments/dev/ecs/main.tf`**

```hcl
provider "aws" {
  region  = var.region
  profile = var.profile
}

data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket         = "tfstate-${var.env_name}"
    key            = "network/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tfstate-${var.env_name}-lock"
  }
}

module "ecs" {
  source = "../../../modules/ecs"

  env                = var.env_name
  region             = var.region
  image              = var.image
  cpu                = var.cpu
  memory             = var.memory
  desired_count      = var.desired_count
  vpc_id             = data.terraform_remote_state.network.outputs.vpc_id
  public_subnet_ids  = data.terraform_remote_state.network.outputs.public_subnet_ids
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
  alb_sg_id          = data.terraform_remote_state.network.outputs.alb_sg_id
  ecs_sg_id          = data.terraform_remote_state.network.outputs.ecs_sg_id
  tags               = var.tags
}
```

- [ ] **Step 14: Write `environments/dev/ecs/backend.tf`**

```hcl
terraform {
  backend "s3" {
    bucket         = "tfstate-dev"
    key            = "ecs/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tfstate-dev-lock"
    encrypt        = true
  }
}
```

- [ ] **Step 15: Write `environments/dev/ecs/variables.tf`**

```hcl
variable "region" {
  type = string
}

variable "profile" {
  type = string
}

variable "env_name" {
  type = string
}

variable "image" {
  type    = string
  default = "nginx:alpine"
}

variable "cpu" {
  type    = string
  default = "256"
}

variable "memory" {
  type    = string
  default = "512"
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "tags" {
  type    = map(string)
  default = {}
}
```

- [ ] **Step 16: Write `environments/dev/ecs/terraform.tfvars`**

```hcl
region         = "us-east-1"
profile        = "dev"
env_name       = "dev"
image          = "nginx:alpine"
cpu            = "256"
memory         = "512"
desired_count  = 1
tags = {
  env       = "dev"
  project   = "terraform-101-demo"
  managed_by = "terraform"
}
```

- [ ] **Step 17: Write `environments/dev/ecs/outputs.tf`**

```hcl
output "alb_dns_name" {
  value = module.ecs.alb_dns_name
}

output "cluster_name" {
  value = module.ecs.cluster_name
}

output "service_name" {
  value = module.ecs.service_name
}
```

- [ ] **Step 18: Write `environments/dev/ecs/versions.tf`**

```hcl
terraform {
  required_version = "~> 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

- [ ] **Step 19: Verify all three dev components parse**

Run:
```bash
for d in network database ecs; do
  cd "environments/dev/$d" && terraform fmt --recursive && terraform init -backend=false && terraform validate && cd ../../..
done
```
Expected: `Success!` for all three.

- [ ] **Step 20: Commit**

```bash
git add environments/dev
git commit -m "feat: add dev environment (network, database, ecs)"
```

---

### Task 7: `environments/staging`

Same component shape as dev, different values. `main.tf`, `variables.tf`, `versions.tf`, and `outputs.tf` for each component are byte-identical to dev — copy them verbatim; only `backend.tf` and `terraform.tfvars` change.

**Files:**
- Copy (verbatim, from `environments/dev/`): `staging/network/{main.tf,variables.tf,outputs.tf,versions.tf}`, `staging/database/{main.tf,variables.tf,outputs.tf,versions.tf}`, `staging/ecs/{main.tf,variables.tf,outputs.tf,versions.tf}`
- Create: `environments/staging/network/backend.tf`, `environments/staging/network/terraform.tfvars`
- Create: `environments/staging/database/backend.tf`, `environments/staging/database/terraform.tfvars`
- Create: `environments/staging/ecs/backend.tf`, `environments/staging/ecs/terraform.tfvars`

**Interfaces:**
- Consumes/Produces: same as Task 6, with `profile = "staging"` and bucket `tfstate-staging`.

- [ ] **Step 1: Copy the four identical files per component from dev**

Copy `environments/dev/<component>/main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` to `environments/staging/<component>/` unchanged (the same files, byte-identical).

- [ ] **Step 2: Write `environments/staging/network/backend.tf`**

```hcl
terraform {
  backend "s3" {
    bucket         = "tfstate-staging"
    key            = "network/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tfstate-staging-lock"
    encrypt        = true
  }
}
```

- [ ] **Step 3: Write `environments/staging/network/terraform.tfvars`**

```hcl
region              = "us-east-1"
profile             = "staging"
env_name            = "staging"
vpc_cidr            = "10.1.0.0/16"
azs                 = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs = ["10.1.0.0/24", "10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24", "10.1.12.0/24"]
nat_gateway_count   = 1
tags = {
  env        = "staging"
  project    = "terraform-101-demo"
  managed_by = "terraform"
}
```

- [ ] **Step 4: Write `environments/staging/database/backend.tf`**

```hcl
terraform {
  backend "s3" {
    bucket         = "tfstate-staging"
    key            = "database/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tfstate-staging-lock"
    encrypt        = true
  }
}
```

- [ ] **Step 5: Write `environments/staging/database/terraform.tfvars`**

```hcl
region              = "us-east-1"
profile             = "staging"
env_name            = "staging"
db_name             = "appdb"
instance_class      = "db.t4g.micro"
allocated_storage   = 20
backup_retention_period = 7
multi_az            = false
deletion_protection = false
skip_final_snapshot = true
tags = {
  env        = "staging"
  project    = "terraform-101-demo"
  managed_by = "terraform"
}
```

- [ ] **Step 6: Write `environments/staging/ecs/backend.tf`**

```hcl
terraform {
  backend "s3" {
    bucket         = "tfstate-staging"
    key            = "ecs/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tfstate-staging-lock"
    encrypt        = true
  }
}
```

- [ ] **Step 7: Write `environments/staging/ecs/terraform.tfvars`**

```hcl
region        = "us-east-1"
profile       = "staging"
env_name      = "staging"
image         = "nginx:alpine"
cpu           = "256"
memory        = "512"
desired_count = 1
tags = {
  env        = "staging"
  project    = "terraform-101-demo"
  managed_by = "terraform"
}
```

- [ ] **Step 8: Verify all three staging components**

Run the same loop as Task 6 Step 19 with `environments/staging`.
Expected: `Success!` × 3.

- [ ] **Step 9: Commit**

```bash
git add environments/staging
git commit -m "feat: add staging environment (network, database, ecs)"
```

---

### Task 8: `environments/prod`

Same shape, production values: multi-AZ DB, deletion protection, retained final snapshot, larger instances.

**Files:**
- Copy (verbatim, from `environments/dev/`): `prod/network/{main.tf,variables.tf,outputs.tf,versions.tf}`, `prod/database/{main.tf,variables.tf,outputs.tf,versions.tf}`, `prod/ecs/{main.tf,variables.tf,outputs.tf,versions.tf}`
- Create: `environments/prod/network/backend.tf`, `environments/prod/network/terraform.tfvars`
- Create: `environments/prod/database/backend.tf`, `environments/prod/database/terraform.tfvars`
- Create: `environments/prod/ecs/backend.tf`, `environments/prod/ecs/terraform.tfvars`

**Interfaces:**
- Consumes/Produces: same as Task 7, with `profile = "prod"`, bucket `tfstate-prod`, production values below.

- [ ] **Step 1: Copy the four verbatim files per prod component**

Copy `environments/dev/<component>/{main.tf,variables.tf,outputs.tf,versions.tf}` into `environments/prod/<component>/` unchanged.

- [ ] **Step 2: Write `environments/prod/network/backend.tf`**

```hcl
terraform {
  backend "s3" {
    bucket         = "tfstate-prod"
    key            = "network/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tfstate-prod-lock"
    encrypt        = true
  }
}
```

- [ ] **Step 3: Write `environments/prod/network/terraform.tfvars`**

```hcl
region              = "us-east-1"
profile             = "prod"
env_name            = "prod"
vpc_cidr            = "10.2.0.0/16"
azs                 = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnet_cidrs = ["10.2.0.0/24", "10.2.1.0/24", "10.2.2.0/24"]
private_subnet_cidrs = ["10.2.10.0/24", "10.2.11.0/24", "10.2.12.0/24"]
nat_gateway_count   = 1
tags = {
  env        = "prod"
  project    = "terraform-101-demo"
  managed_by = "terraform"
}
```

- [ ] **Step 4: Write `environments/prod/database/backend.tf`**

```hcl
terraform {
  backend "s3" {
    bucket         = "tfstate-prod"
    key            = "database/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tfstate-prod-lock"
    encrypt        = true
  }
}
```

- [ ] **Step 5: Write `environments/prod/database/terraform.tfvars`**

```hcl
region              = "us-east-1"
profile             = "prod"
env_name            = "prod"
db_name             = "appdb"
instance_class      = "db.t4g.small"
allocated_storage   = 50
backup_retention_period = 7
multi_az            = true
deletion_protection = true
skip_final_snapshot = false
tags = {
  env        = "prod"
  project    = "terraform-101-demo"
  managed_by = "terraform"
}
```

- [ ] **Step 6: Write `environments/prod/ecs/backend.tf`**

```hcl
terraform {
  backend "s3" {
    bucket         = "tfstate-prod"
    key            = "ecs/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tfstate-prod-lock"
    encrypt        = true
  }
}
```

- [ ] **Step 7: Write `environments/prod/ecs/terraform.tfvars`**

```hcl
region = "us-east-1"
profile = "prod"
env_name = "prod"
image = "nginx:alpine"
cpu = "256"
memory = "512"
desired_count = 1
tags = {
  env        = "prod"
  project    = "terraform-101-demo"
  managed_by = "terraform"
}
```

- [ ] **Step 8: Verify all three prod components**

Run the same loop as Task 6 with `environments/prod`.
Expected: `Success!` × 3.

- [ ] **Step 9: Commit**

```bash
git add environments/prod
git commit -m "feat: add prod environment with hardened DB defaults"
```

---

### Task 9: Docs, Makefile, scripts, and full-repo verification

**Files:**
- Create: `README.md`
- Create: `docs/SETUP.md`
- Create: `docs/GAPS.md`
- Create: `docs/DEMO-SCRIPT.md`
- Create: `Makefile`
- Create: `scripts/validate-all.sh`, `scripts/plan-all.sh`, `scripts/destroy-all.sh`

**Interfaces:**
- Consumes: all modules and environments from Tasks 1–8.
- Produces: the demo narrative assets (README, SETUP, GAPS, DEMO-SCRIPT) and operational entrypoints (Makefile, scripts).

- [ ] **Step 1: Write `README.md`**

```markdown
# Terraform Multi-Account / Multi-Environment Demonstration

A live, pure-Terraform multi-account infrastructure demo: three AWS accounts
(dev, staging, prod), each with a VPC network, an RDS PostgreSQL database, and
an ECS Fargate service behind an ALB. The repo's layout and deliberate
repetition illustrate Terraform's multi-account pain points — the setup for a
follow-on Terragrunt act.

## Layout

    modules/          hand-rolled modules shared across environments
    environments/     one workspace per environment & component (own state)
      bootstrap/      creates the per-account state buckets (apply once)
      dev/            network · database · ecs
      staging/        network · database · ecs
      prod/           network · database · ecs

## Prereqs & setup

See `docs/SETUP.md` (AWS CLI profiles, costs, teardown).

## Apply order (per environment)

    bootstrap → network → database → ecs

Live demo applies `dev` only; `staging` and `prod` are coded and validated.
See `docs/DEMO-SCRIPT.md` for the narration, `docs/GAPS.md` for the gap table.

## Commands

    make fmt        # terraform fmt --recursive
    make validate   # init -backend=false + validate on every component
    make plan       # init + plan on every component (needs creds)
```

- [ ] **Step 2: Write `docs/SETUP.md`**

```markdown
# Setup

## Prerequisites

- Terraform 1.6+ (verified with 1.13.4)
- AWS CLI v2
- Three AWS accounts (or one account reused for all three profiles while
  bootstrapping the demo)

## Named profiles

Create ~/.aws/credentials with three profiles:

    [dev]
    aws_access_key_id = AKIA...
    aws_secret_access_key = ...

    [staging]
    ...

    [prod]
    ...

Until real accounts exist, all three profiles may point at the same account —
the multi-account structure is coded regardless.

## Bootstrap (once)

    cd environments/bootstrap
    terraform init && terraform apply

Creates tfstate-<env> buckets + lock tables in each account profile.

## Apply (dev only for the live demo)

    cd environments/dev/network   && terraform init && terraform apply -auto-approve
    cd environments/dev/database  && terraform init && terraform apply -auto-approve
    cd environments/dev/ecs       && terraform init && terraform apply -auto-approve

## Cost

Dev, while running ≈ $70/mo (1 NAT+EIP ≈ $34, RDS micro ≈ $13, ALB ≈ $16,
Fargate ≈ $5). **Destroy after the demo.**

## Teardown

    cd environments/dev/ecs       && terraform destroy -auto-approve
    cd environments/dev/database  && terraform destroy -auto-approve
    cd environments/dev/network   && terraform destroy -auto-approve
```

- [ ] **Step 3: Write `docs/GAPS.md`**

```markdown
# Terraform pain points on display — and where Terragrunt cures them

| # | Gap demonstrated in Part 1 | Where it shows | Terragrunt cure (Act 2 preview) |
|---|---|---|---|
| 1 | Boilerplate repetition: provider + module call copied into 12 component roots | every `main.tf` | `include "root.hcl"` + `generate` |
| 2 | Static backend: bucket/key hardcoded, can't derive env | every `backend.tf` | `remote_state` block builds the key from the path |
| 3 | No single source of truth for region/profile/common tags | every `terraform.tfvars` | `env.hcl`/`account.hcl` inherited via `include` |
| 4 | Cross-component coupling via hardcoded remote-state keys | `data "terraform_remote_state"` in db/ecs | `dependency` blocks with typed outputs |
| 5 | No orchestration: sequential manual applies, no promotion story | the apply sequence | `run-all apply` + `dependencies` |
| 6 | Bootstrap chicken-and-egg: state infra before state | `environments/bootstrap` | `remote_state` auto-creates bucket + lock |
```

- [ ] **Step 4: Write `docs/DEMO-SCRIPT.md`**

```markdown
# Demo script — Act 1 (pure Terraform)

## Beat 0 — The shape (2 min)
Walk the tree: `environments/{dev,staging,prod}/{network,database,ecs}`.
Note modules at root, one component = one workspace = one state.

## Beat 1 — Bootstrap chicken-and-egg (2 min)
Run `environments/bootstrap` once. Ask: *why is this its own thing?* Answer:
Terraform can't reference a bucket that doesn't exist yet. Terragrunt
`remote_state` cures this later.

## Beat 2 — network apply (5 min)
Apply `dev/network`. Point at the duplicated `provider` block; every
environment re-types region/profile. **Gap #1, #3.**

## Beat 3 — database reads network (3 min)
Show `data "terraform_remote_state"` in `dev/database/main.tf` — the bucket
key `network/terraform.tfstate` is hardcoded text. Apply it. **Gap #4.**

## Beat 4 — ecs (4 min)
Same remote_state pattern, plus ALB DNS output. Apply. Open the ALB DNS.

## Beat 5 — staging/prod exist but are copies (3 min)
`tree environments` again. Show staging/network and dev/network `main.tf`
are identical; only backend+tfvars differ. Name the cost of that. **Gap #2, #5.**

## Beat 6 — recap (2 min)
Six gaps on the board (docs/GAPS.md). Preview: Terragrunt collapses each.
```

- [ ] **Step 5: Write `Makefile`**

```make
.PHONY: fmt validate plan destroy

fmt:
	terraform fmt --recursive

validate:
	@./scripts/validate-all.sh

plan:
	@./scripts/plan-all.sh

destroy:
	@./scripts/destroy-all.sh
```

- [ ] **Step 6: Write `scripts/validate-all.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
for env in dev staging prod; do
  for comp in network database ecs; do
    dir="environments/${env}/${comp}"
    echo "==> validate ${dir}"
    (cd "${dir}" && terraform fmt --recursive && terraform init -backend=false && terraform validate)
  done
done
echo "All components validated."
```

- [ ] **Step 7: Write `scripts/plan-all.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
for env in dev staging prod; do
  for comp in network database ecs; do
    dir="environments/${env}/${comp}"
    echo "==> plan ${dir}"
    (cd "${dir}" && terraform init && terraform plan)
  done
done
echo "Plans complete."
```

- [ ] **Step 8: Write `scripts/destroy-all.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
for env in dev staging prod; do
  for comp in ecs database network; do
    dir="environments/${env}/${comp}"
    echo "==> destroy ${dir}"
    (cd "${dir}" && terraform init && terraform destroy -auto-approve)
  done
done
echo "Teardown complete."
```

- [ ] **Step 9: Make scripts executable**

Run: `chmod +x scripts/*.sh`

- [ ] **Step 10: Full-repo verification**

Run: `make fmt && make validate`
Expected: `fmt` reports no files needing formatting; `validate` prints `Success!` for all 12 component directories (3 envs × 3 components) and exits 0.

- [ ] **Step 11: Commit**

```bash
git add README.md docs Makefile scripts
git commit -m "docs: add demo narrative (README, SETUP, GAPS, DEMO-SCRIPT) and Makefile/scripts"
```

---

### Task 10: Optional live apply (needs credentials — gate on user request)

Runs only when the user has configured the `dev`/`staging`/`prod` profiles.

- [ ] **Step 1: Bootstrap** — `cd environments/bootstrap && terraform init && terraform apply -auto-approve`
- [ ] **Step 2: Apply dev** — `make plan` then, for the dev env only, apply network → database → ecs in order.
- [ ] **Step 3: Verify** — open the `alb_dns_name` from `environments/dev/ecs` outputs in a browser; confirm nginx responds.
- [ ] **Step 4: Tear down when done** — `cd environments/dev && for d in ecs database network; do (cd $d && terraform destroy -auto-approve); done`
