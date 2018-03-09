/**
 * ECS Cluster for use with Fargate launch types:
 *
 * Usage:
 *
 *      module "cdn" {
 *        source               = "github.com/das42/segmentio-stack/ecs-fargate-cluster"
 *        environment          = "prod"
 *        name                 = "cdn"
 *        vpc_id               = "vpc-id"
 *        security_groups      = "1,2"
 *      }
 *
 */

variable "name" {
  description = "The cluster name, e.g cdn"
}

variable "environment" {
  description = "Environment tag, e.g prod"
}

variable "vpc_id" {
  description = "VPC ID"
}

variable "security_groups" {
  description = "Comma separated list of security groups"
}

resource "aws_security_group" "cluster" {
  name        = "${var.name}-ecs-cluster"
  vpc_id      = "${var.vpc_id}"
  description = "Allows traffic from and to the EC2 instances of the ${var.name} ECS cluster"

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = -1
    security_groups = ["${split(",", var.security_groups)}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name        = "ECS cluster (${var.name})"
    Environment = "${var.environment}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ecs_cluster" "main" {
  name = "${var.name}"

  lifecycle {
    create_before_destroy = true
  }
}

// The cluster name, e.g cdn
output "name" {
  value = "${var.name}"
}

// The cluster security group ID.
output "security_group_id" {
  value = "${aws_security_group.cluster.id}"
}
