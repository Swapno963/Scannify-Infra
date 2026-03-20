# main.tf

provider "aws" {
  region = "ap-southeast-1"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "4.0.0"  # Specify the version of the module

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-southeast-1a"]
  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.2.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Explicitly enable auto-assign public IPv4 address on public subnets
  map_public_ip_on_launch = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}



# Security Group for the Public Instance
resource "aws_security_group" "public_sg" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "public-sg"
  }
}

# Security Group for the Private Instance
resource "aws_security_group" "private_sg" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]  # Only allow SSH from the public subnet
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private-sg"
  }
}

##########################
# 1. Security Group for ALB
##########################
resource "aws_security_group" "alb_sg" {
  vpc_id = module.vpc.vpc_id  # Use your VPC ID from module

  description = "Allow HTTP from anywhere"

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

#######################################
# 2. Security Group Update for Private Instance
# Allow HTTP traffic from ALB
#######################################
resource "aws_security_group_rule" "allow_alb_to_private" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.private_sg.id
  source_security_group_id = aws_security_group.alb_sg.id
  description              = "Allow HTTP from ALB"
}

##########################
# 3. Create Application Load Balancer
##########################
resource "aws_lb" "frontend_alb" {
  name               = "frontend-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = module.vpc.public_subnets  # Public subnet
  enable_deletion_protection = false

  tags = {
    Name = "frontend-alb"
  }
}

##########################
# 4. Target Group for Private Frontend Instance
##########################
resource "aws_lb_target_group" "frontend_tg" {
  name     = "frontend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }

  tags = {
    Name = "frontend-tg"
  }
}

###################################
# 5. Attach Private Instance to Target Group
###################################
resource "aws_lb_target_group_attachment" "frontend_attachment" {
  target_group_arn = aws_lb_target_group.frontend_tg.arn
  target_id        = aws_instance.private.id  # Replace with your frontend instance
  port             = 80
}

##########################
# 6. ALB Listener
##########################
resource "aws_lb_listener" "frontend_listener" {
  load_balancer_arn = aws_lb.frontend_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}
# Key Pair
resource "aws_key_pair" "main" {
  key_name   = "main-key"
  public_key = file("~/.ssh/id_rsa.pub")  # Replace with your own public key
}



# Public EC2 Instance
resource "aws_instance" "public" {
  ami           = "ami-060e277c0d4cce553"  # Ubuntu AMI
  instance_type = "t2.micro"
  subnet_id     = module.vpc.public.id
  key_name      = aws_key_pair.main.key_name

  tags = {
    Name = "public-instance"
  }

  security_groups = [aws_security_group.public_sg.name]
}

# Private EC2 Instance
resource "aws_instance" "private" {
  ami           = "ami-060e277c0d4cce553"  # Ubuntu AMI
  instance_type = "t2.micro"
  subnet_id     = module.vpc.private.id
  key_name      = aws_key_pair.main.key_name
  user_data = <<-EOF
              #!/bin/bash
              # Update system
              apt-get update -y
              apt-get upgrade -y

              # Install Node.js
              curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
              apt-get install -y nodejs git

              # Pull backend code 
              cd /home/ubuntu
              git https://github.com/Swapno963/Scannify-Backend.git app
              cd app/Scannify-Backend
              npm install

              # Start the Node.js app 
              npm start



              # Pull backend code 
              cd /home/ubuntu
              git https://github.com/Swapno963/Scannify.git app
              cd app/Scannify
              npm install

              # Start the Node.js app 
              npm start
              EOF
  tags = {
    Name = "private-instance"
  }

  security_groups = [aws_security_group.private_sg.name]
}
