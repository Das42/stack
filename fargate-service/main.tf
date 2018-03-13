/**
 * The service module creates an ecs service, task definition
 * elb and a route53 record under the local service zone (see the dns module).
 *
 * Usage:
 *
 *      module "auth_service" {
 *        source    = "github.com/segmentio/stack/service"
 *        name      = "auth-service"
 *        image     = "auth-service"
 *        cluster   = "default"
 *        internal_subnets = "subnets"
 *        vpc_id    = "vpc_id"
 *        logs_region = "logs_region"
 *        ecs_execution_role_arn = "role_arn"
 *      }
 *
 */

/**
 * Required Variables.
 */

variable "environment" {
  description = "Environment tag, e.g prod"
}

variable "image" {
  description = "The docker image name, e.g nginx"
}

variable "name" {
  description = "The service name, if empty the service name is defaulted to the image name"
  default     = ""
}

variable "version" {
  description = "The docker image version"
  default     = "latest"
}

variable "subnet_ids" {
  description = "Comma separated list of subnet IDs that will be passed to the ELB module"
}

variable "security_groups" {
  description = "Comma separated list of security group IDs that will be passed to the ELB module"
}

variable "port" {
  description = "The container host port"
}

variable "cluster" {
  description = "The cluster name or ARN"
}

variable "dns_name" {
  description = "The DNS name to use, e.g nginx"
}

variable "log_bucket" {
  description = "The S3 bucket ID to use for the ELB"
}

/**
 * Options.
 */

variable "healthcheck" {
  description = "Path to a healthcheck endpoint"
  default     = "/"
}

variable "command" {
  description = "The raw json of the task command"
  default     = "[]"
}

variable "env_vars" {
  description = "The raw json of the task env vars"
  default     = "[]"
}

variable "desired_count" {
  description = "The desired count"
  default     = 2
}

variable "memory" {
  description = "The number of MiB of memory to reserve for the container"
  default     = 512
}

variable "cpu" {
  description = "The number of cpu units to reserve for the container"
  default     = 256
}

variable "protocol" {
  description = "The ELB protocol, HTTP or TCP"
  default     = "HTTP"
}

variable "zone_id" {
  description = "The zone ID to create the record in"
}

variable "deployment_minimum_healthy_percent" {
  description = "lower limit (% of desired_count) of # of running tasks during a deployment"
  default     = 100
}

variable "deployment_maximum_percent" {
  description = "upper limit (% of desired_count) of # of running tasks during a deployment"
  default     = 200
}

variable "internal_subnets" {
  type = "list"
}

variable "vpc_id" {
}

variable "logs_region" {
}

variable "log_group" {
}

variable "ecs_execution_role_arn" {
}

/**
 * Resources.
 */

resource "aws_ecs_service" "main" {
  name                               = "${module.fargate_task.name}"
  cluster                            = "${var.cluster}"
  task_definition                    = "${module.fargate_task.arn}"
  desired_count                      = "${var.desired_count}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"
  deployment_maximum_percent         = "${var.deployment_maximum_percent}"
  launch_type                        = "FARGATE"

  network_configuration = {
    subnets = ["${var.internal_subnets}"]
    security_groups = ["${var.security_groups}"]
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.main.arn}"
    container_name = "${module.fargate_task.name}"
    container_port = "${var.port}"
  }

  depends_on = [
    "aws_alb_listener.main"
  ]

  lifecycle {
    create_before_destroy = true
  }
}

module "fargate_task" {
  source = "../fargate-task"

  name          = "${coalesce(var.name, replace(var.image, "/", "-"))}"
  image         = "${var.image}"
  image_version = "${var.version}"
  env_vars      = "${var.env_vars}"
  memory        = "${var.memory}"
  cpu           = "${var.cpu}"
  logs_region   = "${var.logs_region}"
  log_group     = "${var.log_group}"
  ecs_execution_role_arn = "${var.ecs_execution_role_arn}"

  ports = <<EOF
  [
    {
      "containerPort": ${var.port},
      "hostPort": ${var.port}
    }
  ]
EOF

}

resource "aws_alb" "main" {
  name = "${var.name}"
  internal = true

  security_groups = ["${var.security_groups}"]

  subnets = ["${var.internal_subnets}"]
}

resource "aws_alb_target_group" "main" {  
  name = "${var.name}"
  protocol = "HTTP"
  port = "${var.port}"
  vpc_id = "${var.vpc_id}"
  target_type = "ip"

  health_check {
    path = "/"
  }
}

resource "aws_alb_listener" "main" {
  load_balancer_arn = "${aws_alb.main.arn}"
  port = "80"
  protocol = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.main.arn}"
    type = "forward"
  }

  depends_on = ["aws_alb_target_group.main"]
}

/**
 * Outputs.
 */

