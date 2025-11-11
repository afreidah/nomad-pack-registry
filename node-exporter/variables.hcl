variable "job_name" {
  description = "Name of the Nomad job"
  type        = string
  default     = "node-exporter"
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

variable "exporter_version" {
  description = "Node exporter version"
  type        = string
  default     = "1.8.2"
}

variable "http_port" {
  description = "HTTP metrics port"
  type        = number
  default     = 9100
}

variable "cpu" {
  description = "CPU allocation"
  type        = number
  default     = 150
}

variable "memory" {
  description = "Memory allocation (MB)"
  type        = number
  default     = 64
}
