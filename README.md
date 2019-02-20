# terraform-aws-rancher

This module will launch Rancher 2.0 in AWS Fargate. 

# Usage

```
module "rancher" {
  source  = "devoption/rancher/aws"
  version = "0.2.0"

  # Set the name
  name                  = "rancher"

  # Optional - Use an existing VPC (If not set, one will be created)
  vpc_id                = "${var.vpc_id}"
  private_subnet_ids    = "${var.private_subnet_ids}"
  public_subnet_ids     = "${var.public_subnet_ids}"

  # The Route53 Zone Name (without the trailing dot)
  route53_zone_name     = "example.com"

  # Optional - Set the Certificate ARN (If not set, one will be created)
  certificate_arn       = "${var.cert_arn}"
}
```