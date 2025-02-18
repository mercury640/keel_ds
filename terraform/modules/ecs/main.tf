resource "aws_iam_role" "ecs_task_role" {
  name = "ecsTaskRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_cluster" "display" {
  name = var.display_service_name
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "display" {
  family                   = var.display_service_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "${var.display_service_name}"
      image     = "public.ecr.aws/k3h4d7k6/ag/display"
      cpu       = 512
      memory    = 1024
      essential = true

      logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "${var.log_group}"
        awslogs-region        = "ca-central-1"
        awslogs-stream-prefix = "ecs"
      }
    }

      portMappings = [
        {
          containerPort = 5002
          hostPort      = 5002
        }
      ]

      environment = [
        { name = "DB_NAME", value = "${var.db_name}" },
        { name = "DB_HOST", value = "${var.db_host}" },
        { name = "DB_PORT", value = "${var.db_port}" }
      ]
      
      secrets = [
        { name = "DB_USER", valueFrom = "${var.db_user_from}" },
        { name = "DB_PASSWORD", valueFrom = "${var.db_pass_from}" }
      ]
    }
  ])
}

resource "aws_ecs_service" "display" {
  name            = var.display_service_name
  cluster         = aws_ecs_cluster.display.id
  task_definition = aws_ecs_task_definition.display.arn
  launch_type     = "FARGATE"
  desired_count   = 2

  network_configuration {
    subnets          = var.ecs_subnets
    security_groups  = var.ecs_security_group_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.display.arn
    container_name   = var.display_service_name
    container_port   = 5002
  }

  deployment_controller {
    type = "ECS"
  }

  enable_execute_command = true
}

resource "aws_lb" "display" {
  name               = var.display_service_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.alb_security_group_ids
  subnets           = var.alb_subnets
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.display.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.display.arn
  }
}

resource "aws_lb_target_group" "display" {
  name     = var.display_service_name
  port     = 5002
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

