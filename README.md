# keel_ds

prerequisites:
1. Ensure the environment which terraform running has enough permission
2. S3 bucket to store Terraform state files
3. In AWS Secret Manager, create 2 secrets for database master credential and service user credential.
   Both of secrets have keys username="" and password=""
   This two secrets are refered by root main.tf (locals) to init rds
5. Ensure this is a public key in this location "~/.ssh/id_rsa.pub". It's required when creating EC2 instances

Description
1. Docker images:
   All 3 applications are built up with docker and images are available in public registry
   - adder : public.ecr.aws/k3h4d7k6/ag/adder
   - display : public.ecr.aws/k3h4d7k6/ag/display
   - reset : public.ecr.aws/k3h4d7k6/ag/reset

2. VPC:
   The VPC includes 3 group subnets, each of them crosses 3 AZs for high availablility
   - public_subnets  : Provide internet access for NAT gateways used by private_subnets.
   - private_subnets : Workloads such as RDS,  EC2 instances, ECS and EKS are deployed in those subnets.
   - app_subnets : They are public subnets. 3 Load balancers for adder, display and reset services are diplayed here.

   The traffic from app_subnets to private subnets is managed by secrity groups.

3. EC2 Instance:
   Bastion server is located in app_subnets which could be reached from internet. When it's being created, the EC2 key pair is created based on the public key of the machine which Terraform running on. It coul dbe accessed from internet by command ssh -i "key.pem" ec2-user@xxx.xxx.xxx.xxx.

   EC2 instances for applications are located in private subnets without public IP.  They could be accessed from Bastion server via private IP and key pair.

4. Service adder:
   This service is deployed in a group of EC2 instances with docker in private subnets accross 2 AZs.  It's exposed by an ALB located in application subnets.

5. Service display:
   It's running on ECS with Fargate to privide serverless service in private subnets which accross 3 AZs. It's exposed by an ALB located in application subnets

6. Service reset:
   It's running on EKS with node group to privide service in private subnets which accross 3 AZs. It's exposed by an ALB located in application subnets and ingress-nginx controller.
   HPA is enable to scale up & down the sum of pods for deployment based on CPU usage.


Need-To-Improve:

1. For Terraform, need to use separated variables files for different environments such as dev, staging and prod when apply the change.
2. Application Load Balancer should enable https.
3. Password of RDS should be managed by Secret Manager and rotated periodically.
4. Enable CloudTrail Logging and VPC Flow Log and keep logs in S3 bucket
