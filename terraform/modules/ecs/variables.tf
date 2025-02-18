variable "vpc_id" {
  type = string
}

variable "display_service_name" {}
variable "db_name" {}
variable "db_host" {}
variable "db_port" {}
variable "db_user_from" {}
variable "db_pass_from" {}
variable "ecs_subnets" {}
variable "alb_subnets" {}
variable "ecs_security_group_ids" {}
variable "alb_security_group_ids" {}
variable "log_group" {}
variable "execution_role_arn" {}