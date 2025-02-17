# Create ALB
resource "aws_lb" "alb" {
  name               = var.platform_type
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.security_groups
  subnets            = var.subnets

  enable_deletion_protection = false

  tags = {
    Name = var.platform_type
  }
}

# Create ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# Create Target Group
resource "aws_lb_target_group" "tg" {
  name        = var.platform_type
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = var.target_type
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = var.platform_type
  }
}

# Attach EC2 instances to Target Group using for_each
resource "aws_lb_target_group_attachment" "tg-attach" {
  for_each         = var.instance_ids
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = each.value
}
