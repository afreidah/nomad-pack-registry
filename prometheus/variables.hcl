variable "job_name" {
  description = "Name of the Nomad job"
  type        = string
  default     = "prometheus"
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

variable "prometheus_version" {
  description = "Prometheus version"
  type        = string
  default     = "2.54.1"
}

variable "constraint_node" {
  description = "Node constraint for placement"
  type        = string
  default     = "cabot"
}

variable "web_port" {
  description = "Prometheus web UI port"
  type        = number
  default     = 9090
}

variable "retention_days" {
  description = "TSDB retention period in days"
  type        = number
  default     = 30
}

variable "consul_servers" {
  description = "Consul server addresses for DNS"
  type        = list(string)
  default     = ["192.168.68.62", "192.168.68.64"]
}

variable "extra_hosts" {
  description = "Extra hosts mapping for DNS resolution"
  type        = list(string)
  default = [
    "goren:192.168.68.60",
    "green:192.168.68.62",
    "logan:192.168.68.64",
    "stabler:192.168.68.61",
    "mccoy:192.168.68.63",
    "cabot:192.168.68.59"
  ]
}

variable "cpu" {
  description = "CPU allocation"
  type        = number
  default     = 500
}

variable "memory" {
  description = "Memory allocation (MB)"
  type        = number
  default     = 1024
}

variable "prometheus_config_path" {
  description = "Path to prometheus.yml config file"
  type        = string
  default     = "prometheus.yml"
}

variable "alert_rules_path" {
  description = "Path to alert_rules.yml file"
  type        = string
  default     = "alert_rules.yml"
}
