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

  tags = merge(var.tags, { Name = "${var.env_name}-nat-eip-${count.index + 1}" })
}

resource "aws_nat_gateway" "this" {
  count = var.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
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
