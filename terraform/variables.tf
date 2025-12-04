variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "region" {
  description = "AWS region to use."
  type        = string
}

variable "service_count" {
  description = "Number of services to use."
  type        = number
}

variable "docker_tag" {
  description = "Image tag to use."
  type        = string
}

variable "min_capacity" {
  description = "Smallest number of tasks the service can scale-in to."
  type        = number
}

variable "max_capacity" {
  description = "Largest number of tasks the service can scale-out to."
  type        = number
}

variable "cpu" {
  description = "CPU units to use."
  type        = number
}

variable "memory" {
  description = "Memory to allocate in MB. Powers of 2 only."
  type        = number
}

variable "autoscaling_metrics" {
  description = "A map of autoscaling metrics."
  type = map(object({
    metric_type  = string
    target_value = number
  }))
  default = {
    cpu = {
      metric_type  = "ECSServiceAverageCPUUtilization"
      target_value = 40
    },
    memory = {
      metric_type  = "ECSServiceAverageMemoryUtilization"
      target_value = 40
    }
  }
}
