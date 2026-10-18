# Data sources
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-vpc"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-public-subnet*"]
  }
}

data "aws_security_group" "ssh" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-sg-ssh"]
  }
}

data "aws_security_group" "http" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-sg-http"]
  }
}

data "aws_security_group" "lb" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-sg-lb"]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Launch Templates
resource "aws_launch_template" "blue" {
  name          = "${var.name_prefix}-blue-template"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  vpc_security_group_ids = [
    data.aws_security_group.ssh.id,
    data.aws_security_group.http.id
  ]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
    yum install -y httpd
    echo "<h1>Blue Environment</h1><p>Instance: $INSTANCE_ID</p>" > /var/www/html/index.html
    systemctl start httpd
    systemctl enable httpd
    EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "${var.name_prefix}-blue-instance"
      Project = var.project_tag
    }
  }

  tags = {
    Name    = "${var.name_prefix}-blue-template"
    Project = var.project_tag
  }
}

resource "aws_launch_template" "green" {
  name          = "${var.name_prefix}-green-template"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  vpc_security_group_ids = [
    data.aws_security_group.ssh.id,
    data.aws_security_group.http.id
  ]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
    yum install -y httpd
    echo "<h1>Green Environment</h1><p>Instance: $INSTANCE_ID</p>" > /var/www/html/index.html
    systemctl start httpd
    systemctl enable httpd
    EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "${var.name_prefix}-green-instance"
      Project = var.project_tag
    }
  }

  tags = {
    Name    = "${var.name_prefix}-green-template"
    Project = var.project_tag
  }
}

# Target Groups
resource "aws_lb_target_group" "blue" {
  name     = "${var.name_prefix}-blue-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
  }

  tags = {
    Name    = "${var.name_prefix}-blue-tg"
    Project = var.project_tag
  }
}

resource "aws_lb_target_group" "green" {
  name     = "${var.name_prefix}-green-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
  }

  tags = {
    Name    = "${var.name_prefix}-green-tg"
    Project = var.project_tag
  }
}

# ALB
resource "aws_lb" "main" {
  name               = "${var.name_prefix}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [data.aws_security_group.lb.id]
  subnets            = data.aws_subnets.public.ids

  tags = {
    Name    = "${var.name_prefix}-lb"
    Project = var.project_tag
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.blue.arn
        weight = var.blue_weight
      }

      target_group {
        arn    = aws_lb_target_group.green.arn
        weight = var.green_weight
      }
    }
  }

  tags = {
    Name    = "${var.name_prefix}-listener"
    Project = var.project_tag
  }
}

# Auto Scaling Groups
resource "aws_autoscaling_group" "blue" {
  name                = "${var.name_prefix}-blue-asg"
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1
  vpc_zone_identifier = data.aws_subnets.public.ids
  target_group_arns   = [aws_lb_target_group.blue.arn]

  launch_template {
    id      = aws_launch_template.blue.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-blue-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_tag
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

resource "aws_autoscaling_group" "green" {
  name                = "${var.name_prefix}-green-asg"
  desired_capacity    = 1
  max_size            = 2
  min_size            = 1
  vpc_zone_identifier = data.aws_subnets.public.ids
  target_group_arns   = [aws_lb_target_group.green.arn]

  launch_template {
    id      = aws_launch_template.green.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-green-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_tag
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}