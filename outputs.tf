output "rancher_url" {
  description = "URL for Rancher"
  value       = "${local.rancher_url}"
}

output "rancher_url_events" {
  description = "Webhook events URL of Rancher"
  value       = "${local.rancher_url_events}"
}

output "task_role_arn" {
  description = "The Rancher ECS task role arn"
  value       = "${aws_iam_role.ecs_task_execution.arn}"
}

output "vpc_id" {
  description = "ID of the VPC that was created or passed in"
  value       = "${local.vpc_id}"
}
