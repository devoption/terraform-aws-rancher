module "rancher" {
  source                = "devoption/rancher/aws"
  version               = "0.1.0"

  name                  = "rancher"

  vpc_id                = "${var.vpc_id}"
  private_subnet_ids    = "${var.private_subnet_ids}"
  public_subnet_ids     = "${var.public_subnet_ids}"

  route53_zone_name     = "${var.domain}"

  certificate_arn       = "${var.cert_arn}"
}
