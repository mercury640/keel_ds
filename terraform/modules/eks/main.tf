data "aws_iam_role" "eksClusterRole" {
  name = "eksClusterRole"  
}

data "aws_iam_role" "AmazonEKSNodeRole" {
  name = "AmazonEKSNodeRole"  
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy1" {
  role       = data.aws_iam_role.eksClusterRole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy2" {
  role       = data.aws_iam_role.eksClusterRole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy3" {
  role       = data.aws_iam_role.eksClusterRole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy4" {
  role       = data.aws_iam_role.eksClusterRole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
}

resource "aws_eks_cluster" "eks" {
  name     = var.cluster_name
  role_arn = data.aws_iam_role.eksClusterRole.arn
  version  = "1.31"

  vpc_config {
    subnet_ids = var.cluster_subnets
  }
}

resource "aws_eks_node_group" "node_group" {
  cluster_name  = var.cluster_name
  node_role_arn = data.aws_iam_role.AmazonEKSNodeRole.arn
  subnet_ids    = var.cluster_subnets
  instance_types = ["t3.medium"]
  scaling_config {
    desired_size = 3
    max_size     = 6
    min_size     = 3
  }
  depends_on = [aws_eks_cluster.eks]
}

resource "aws_lb" "alb" {
  name               = var.cluster_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.alb_security_groups
  subnets           = var.alb_subnets
}

resource "aws_lb_target_group" "tg" {
  name     = var.cluster_name
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "instance"
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}
