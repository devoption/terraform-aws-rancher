variable "name" {
  description = "Name to use on all resources created (VPC, ALB, etc)"
  default     = "rancher"
}

variable "tags" {
  description = "A map of tags to use on all resources"
  default     = {}
}

variable "vpc_id" {
  description = "ID of an existing VPC where resources will be created"
  default     = ""
}

variable "public_subnet_ids" {
  description = "A list of IDs of existing public subnets inside the VPC"
  type        = "list"
  default     = []
}

variable "private_subnet_ids" {
  description = "A list of IDs of existing private subnets inside the VPC"
  type        = "list"
  default     = []
}

variable "cidr" {
  description = "The CIDR block for the VPC which will be created if `vpc_id` is not specified"
  default     = ""
}

variable "azs" {
  description = "A list of availability zones in the region"
  type        = "list"
  default     = []
}

variable "public_subnets" {
  description = "A list of public subnets inside the VPC"
  type        = "list"
  default     = []
}

variable "private_subnets" {
  description = "A list of private subnets inside the VPC"
  type        = "list"
  default     = []
}

variable "alb_ingress_cidr_blocks" {
  description = "List of IPv4 CIDR ranges to use on all ingress rules of the ALB."
  type        = "list"
  default     = ["0.0.0.0/0"]
}

variable "certificate_arn" {
  description = "ARN of certificate issued by AWS ACM. If empty, a new ACM certificate will be created and validated using Route53 DNS"
  default     = ""
}

variable "acm_certificate_domain_name" {
  description = "Route53 domain name to use for ACM certificate. Route53 zone for this domain should be created in advance. Specify if it is different from value in `route53_zone_name`"
  default     = ""
}

variable "route53_zone_name" {
  description = "Route53 zone name to create ACM certificate in and main A-record, without trailing dot"
  default     = ""
}

variable "create_route53_record" {
  description = "Whether to create Route53 record for Rancher"
  default     = true
}

variable "cloudwatch_log_retention_in_days" {
  description = "Retention period of Rancher CloudWatch logs"
  default     = 7
}

variable "webhook_ssm_parameter_name" {
  description = "Name of SSM parameter to keep webhook secret"
  default     = "/rancher/webhook/secret"
}

variable "ssm_kms_key_arn" {
  description = "ARN of KMS key to use for entryption and decryption of SSM Parameters. Required only if your key uses a custom KMS key and not the default key"
  default     = ""
}

variable "ecs_service_assign_public_ip" {
  description = "Should be true, if ECS service is using public subnets (more info: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_cannot_pull_image.html)"
  default     = false
}

variable "policies_arn" {
  description = "A list of the ARN of the policies you want to apply"
  type        = "list"
  default     = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
}

variable "ecs_service_desired_count" {
  description = "The number of instances of the task definition to place and keep running"
  default     = 1
}

variable "ecs_service_deployment_maximum_percent" {
  description = "The upper limit (as a percentage of the service's desiredCount) of the number of running tasks that can be running in a service during a deployment"
  default     = 200
}

variable "ecs_service_deployment_minimum_healthy_percent" {
  description = "The lower limit (as a percentage of the service's desiredCount) of the number of running tasks that must remain running and healthy in a service during a deployment"
  default     = 50
}

variable "ecs_task_cpu" {
  description = "The number of cpu units used by the task"
  default     = 256
}

variable "ecs_task_memory" {
  description = "The amount (in MiB) of memory used by the task"
  default     = 512
}

variable "container_memory_reservation" {
  description = "The amount of memory (in MiB) to reserve for the container"
  default     = 128
}

variable "custom_container_definitions" {
  description = "A list of valid container definitions provided as a single valid JSON document. By default, the standard container definition is used."
  default     = ""
}

variable "rancher_image" {
  description = "Docker image to run Rancher with. If not specified, official Rancher image will be used"
  default     = ""
}

variable "rancher_version" {
  description = "Verion of Rancher to run. If not specified latest will be used"
  default     = "latest"
}

variable "rancher_port" {
  description = "Local port Rancher should be running on. Default value is most likely fine."
  default     = "443"
}

variable "custom_environment_secrets" {
  description = "List of additional secrets the container will use (list should contain maps with `name` and `valueFrom`)"
  default     = []
}

variable "custom_environment_variables" {
  description = "List of additional environment variables the container will use (list should contain maps with `name` and `value`)"
  default     = []
}