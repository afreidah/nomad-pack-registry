variable "job_name" {
  description = "Name of the Nomad job"
  type        = string
  default     = "promtail"
}

variable "region" {
  description = "Job region"
  type        = string
  default     = "global"
}

variable "datacenters" {
  description = "List of datacenters"
  type        = list(string)
  default     = ["pi-dc"]
}

variable "node_pool" {
  description = "Node pool"
  type        = string
  default     = "all"
}

variable "promtail_version" {
  description = "Promtail version"
  type        = string
  default     = "3.3.1"
}

variable "loki_address" {
  description = "Loki API address"
  type        = string
  default     = "http://loki.service.consul:3100"
}

variable "http_port" {
  description = "HTTP metrics port"
  type        = number
  default     = 9080
}

variable "dns_servers" {
  description = "DNS servers"
  type        = list(string)
  default     = ["192.168.68.62", "192.168.68.64"]
}

variable "cpu" {
  description = "CPU allocation"
  type        = number
  default     = 150
}

variable "memory" {
  description = "Memory allocation (MB)"
  type        = number
  default     = 128
}

variable "promtail_config_path" {
  description = "Path to promtail config file"
  type        = string
  default     = "../../../../../cdktf/infra/nomad-jobs/logging/promtail/files/config.yaml"
}
