locals {
  vpc_id             = "${var.vpc_id == "" ? module.vpc.vpc_id : var.vpc_id}"
  private_subnet_ids = "${coalescelist(module.vpc.private_subnets, var.private_subnet_ids)}"
  public_subnet_ids  = "${coalescelist(module.vpc.public_subnets, var.public_subnet_ids)}"
  rancher_image      = "${var.rancher_image == '' ? 'rancher/rancher:${var.rancher_version}' : '${var.rancher_image}' }"
  rancher_url        = "https://${coalesce(element(concat(aws_route53_record.rancher.*.fqdn, list("")), 0), module.alb.dns_name)}"
  rancher_url_events = "${local.rancher_url}/events"

  # Container definitions
  container_definitions = "${var.custom_container_definitions == "" ? module.container_definition.json : var.custom_container_definitions}"

  container_definition_environment = [
    {
      name  = "RANCHER_LOG_LEVEL"
      value = "debug"
    },
    {
      name  = "RANCHER_PORT"
      value = "${var.rancher_port}"
    },
    {
      name  = "RANCHER_RANCHER_URL"
      value = "${local.rancher_url}"
    },
  ]

  container_definition_secrets = [
    {
      name      = "${local.secret_name_key}"
      valueFrom = "${local.secret_name_value_from}"
    },
  ]

  tags = "${merge(map("Name", var.name), var.tags)}"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_route53_zone" "this" {
  count        = "${var.create_route53_record}"
  name         = "${var.route53_zone_name}"
  private_zone = false
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "v1.53.0"

  create_vpc = "${var.vpc_id == ""}"

  name = "${var.name}"

  cidr            = "${var.cidr}"
  azs             = "${var.azs}"
  private_subnets = "${var.private_subnets}"
  public_subnets  = "${var.public_subnets}"

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = "${local.tags}"
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "v3.5.0"

  load_balancer_name = "${var.name}"

  vpc_id          = "${local.vpc_id}"
  subnets         = ["${local.public_subnet_ids}"]
  security_groups = ["${module.alb_https_sg.this_security_group_id}", "${module.alb_http_sg.this_security_group_id}"]
  logging_enabled = false

  https_listeners = [{
    port            = 443
    certificate_arn = "${var.certificate_arn == "" ? module.acm.this_acm_certificate_arn : var.certificate_arn}"
  }]

  https_listeners_count = 1

  http_tcp_listeners = [{
    port     = 80
    protocol = "HTTP"
  }]

  http_tcp_listeners_count = 1

  target_groups = [{
    name                 = "${var.name}"
    backend_protocol     = "HTTP"
    backend_port         = "${var.rancher_port}"
    target_type          = "ip"
    deregistration_delay = 10
  }]

  target_groups_count = 1

  tags = "${local.tags}"
}

resource "aws_lb_listener_rule" "redirect_http_to_https" {
  listener_arn = "${module.alb.http_tcp_listener_arns[0]}"

  action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    field  = "path-pattern"
    values = ["*"]
  }
}

module "alb_https_sg" {
  source  = "terraform-aws-modules/security-group/aws//modules/https-443"
  version = "v2.11.0"

  name        = "${var.name}-alb-https"
  vpc_id      = "${local.vpc_id}"
  description = "Security group with HTTPS ports open for specific IPv4 CIDR block (or everybody), egress ports are all world open"

  ingress_cidr_blocks = "${var.alb_ingress_cidr_blocks}"

  tags = "${local.tags}"
}

module "alb_http_sg" {
  source  = "terraform-aws-modules/security-group/aws//modules/http-80"
  version = "v2.9.0"

  name        = "${var.name}-alb-http"
  vpc_id      = "${local.vpc_id}"
  description = "Security group with HTTP ports open for specific IPv4 CIDR block (or everybody), egress ports are all world open"

  ingress_cidr_blocks = "${var.alb_ingress_cidr_blocks}"

  tags = "${local.tags}"
}

module "rancher_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "v2.11.0"

  name        = "${var.name}"
  vpc_id      = "${local.vpc_id}"
  description = "Security group with open port for Rancher (${var.rancher_port}) from ALB, egress ports are all world open"

  computed_ingress_with_source_security_group_id = [
    {
      from_port                = "${var.rancher_port}"
      to_port                  = "${var.rancher_port}"
      protocol                 = "tcp"
      description              = "Rancher"
      source_security_group_id = "${module.alb_https_sg.this_security_group_id}"
    },
  ]

  number_of_computed_ingress_with_source_security_group_id = 1

  egress_rules = ["all-all"]

  tags = "${local.tags}"
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "v1.1.0"

  create_certificate = "${var.certificate_arn == "" ? 1 : 0}"

  domain_name = "${var.acm_certificate_domain_name == "" ? join(".", list(var.name, var.route53_zone_name)) : var.acm_certificate_domain_name}"
  zone_id     = "${data.aws_route53_zone.this.id}"

  tags = "${local.tags}"
}

resource "aws_route53_record" "rancher" {
  count = "${var.create_route53_record}"

  zone_id = "${data.aws_route53_zone.this.zone_id}"
  name    = "${var.name}"
  type    = "A"

  alias {
    name                   = "${module.alb.dns_name}"
    zone_id                = "${module.alb.load_balancer_zone_id}"
    evaluate_target_health = true
  }
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "v1.1.0"

  name = "${var.name}"
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.name}-ecs_task_execution"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  count = "${length(var.policies_arn)}"

  role       = "${aws_iam_role.ecs_task_execution.id}"
  policy_arn = "${element(var.policies_arn, count.index)}"
}

// ref: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specifying-sensitive-data.html
data "aws_iam_policy_document" "ecs_task_access_secrets" {
  statement {
    effect = "Allow"

    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${var.webhook_ssm_parameter_name}",
    ]

    actions = [
      "ssm:GetParameters",
      "secretsmanager:GetSecretValue",
    ]
  }
}

data "aws_iam_policy_document" "ecs_task_access_secrets_with_kms" {
  count = "${var.ssm_kms_key_arn == "" ? 0 : 1}"

  source_json = "${data.aws_iam_policy_document.ecs_task_access_secrets.0.json}"

  statement {
    sid       = "AllowKMSDecrypt"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["${var.ssm_kms_key_arn == "" ? "" : var.ssm_kms_key_arn}"]
  }
}

resource "aws_iam_role_policy" "ecs_task_access_secrets" {
  name = "ECSTaskAccessSecretsPolicy"

  role = "${aws_iam_role.ecs_task_execution.id}"

  policy = "${element(compact(concat(data.aws_iam_policy_document.ecs_task_access_secrets_with_kms.*.json, data.aws_iam_policy_document.ecs_task_access_secrets.*.json)), 0)}"
}

module "container_definition" {
  source  = "cloudposse/ecs-container-definition/aws"
  version = "v0.7.0"

  container_name  = "${var.name}"
  container_image = "${local.rancher_image}"

  container_cpu                = "${var.ecs_task_cpu}"
  container_memory             = "${var.ecs_task_memory}"
  container_memory_reservation = "${var.container_memory_reservation}"

  port_mappings = [
    {
      containerPort = "${var.rancher_port}"
      hostPort      = "${var.rancher_port}"
      protocol      = "tcp"
    },
  ]

  log_options = [
    {
      "awslogs-region"        = "${data.aws_region.current.name}"
      "awslogs-group"         = "${aws_cloudwatch_log_group.rancher.name}"
      "awslogs-stream-prefix" = "ecs"
    },
  ]

  environment = ["${concat(local.container_definition_environment, var.custom_environment_variables)}"]

  secrets = ["${concat(local.container_definition_secrets, var.custom_environment_secrets)}"]
}

resource "aws_ecs_task_definition" "rancher" {
  family                   = "${var.name}"
  execution_role_arn       = "${aws_iam_role.ecs_task_execution.arn}"
  task_role_arn            = "${aws_iam_role.ecs_task_execution.arn}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "${var.ecs_task_cpu}"
  memory                   = "${var.ecs_task_memory}"

  container_definitions = "${local.container_definitions}"
}

data "aws_ecs_task_definition" "rancher" {
  task_definition = "${var.name}"
  depends_on      = ["aws_ecs_task_definition.rancher"]
}

resource "aws_ecs_service" "rancher" {
  name                               = "${var.name}"
  cluster                            = "${module.ecs.this_ecs_cluster_id}"
  task_definition                    = "${data.aws_ecs_task_definition.rancher.family}:${max(aws_ecs_task_definition.rancher.revision, data.aws_ecs_task_definition.rancher.revision)}"
  desired_count                      = "${var.ecs_service_desired_count}"
  launch_type                        = "FARGATE"
  deployment_maximum_percent         = "${var.ecs_service_deployment_maximum_percent}"
  deployment_minimum_healthy_percent = "${var.ecs_service_deployment_minimum_healthy_percent}"

  network_configuration {
    subnets          = ["${local.private_subnet_ids}"]
    security_groups  = ["${module.rancher_sg.this_security_group_id}"]
    assign_public_ip = "${var.ecs_service_assign_public_ip}"
  }

  load_balancer {
    container_name   = "${var.name}"
    container_port   = "${var.rancher_port}"
    target_group_arn = "${element(module.alb.target_group_arns, 0)}"
  }
}

resource "aws_cloudwatch_log_group" "rancher" {
  name              = "${var.name}"
  retention_in_days = "${var.cloudwatch_log_retention_in_days}"

  tags = "${local.tags}"
}