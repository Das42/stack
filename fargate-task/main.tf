/**
 * The task module creates an ECS task definition.
 *
 * Usage:
 *
 *     module "nginx" {
 *       source = "github.com/segmentio/stack/task"
 *       name   = "nginx"
 *       image  = "nginx"
 *       logs_region = "region"
 *       ecs_execution_role_arn = "role_arn"
 *     }
 *
 */

/**
 * Required Variables.
 */

variable "image" {
  description = "The docker image name, e.g nginx"
}

variable "name" {
  description = "The worker name, if empty the service name is defaulted to the image name"
}

/**
 * Optional Variables.
 */

variable "cpu" {
  description = "The number of cpu units to reserve for the container"
  default     = 256
}

variable "ports" {
  description = "The docker container ports"
  default     = "[]"
}

variable "env_vars" {
  description = "The raw json of the task env vars"
  default     = "[]"
} # [{ "name": name, "value": value }]


variable "image_version" {
  description = "The docker image version"
  default     = "latest"
}

variable "memory" {
  description = "The number of MiB of memory to reserve for the container"
  default     = 512
}

variable "log_driver" {
  description = "The log driver to use use for the container"
  default     = "journald"
}

variable "logs_region" {
}

variable "ecs_execution_role_arn" {
}

variable "log_group" {
}

/**
 * Resources.
 */

# The ECS task definition.

resource "aws_cloudwatch_log_group" "ecs" {
  name = "${var.log_group}"
}

resource "aws_ecs_task_definition" "main" {
  family        = "${var.name}"
  execution_role_arn = "${var.ecs_execution_role_arn}"
  requires_compatibilities = ["FARGATE"]
  network_mode = "awsvpc"
  cpu = "${var.cpu}"
  memory = "${var.memory}"

  lifecycle {
    ignore_changes        = ["image"]
    create_before_destroy = true
  }

  container_definitions = <<EOF
[
  {
    "environment": ${var.env_vars},
    "essential": true,
    "image": "${var.image}:${var.image_version}",
    "name": "${var.name}",
    "portMappings": ${var.ports},
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "${var.log_group}",
            "awslogs-region": "${var.logs_region}",
            "awslogs-stream-prefix": "ecs"
        }
    }
  }
]
EOF
}

/**
 * Outputs.
 */

// The created task definition name
output "name" {
  value = "${aws_ecs_task_definition.main.family}"
}

// The created task definition ARN
output "arn" {
  value = "${aws_ecs_task_definition.main.arn}"
}

// The revision number of the task definition
output "revision" {
  value = "${aws_ecs_task_definition.main.revision}"
}
