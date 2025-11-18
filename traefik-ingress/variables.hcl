# -------------------------------------------------------------------------------
# Traefik Pack Variables
# -------------------------------------------------------------------------------

variable "job_name" {
  description = "Name of the Nomad job"
  type        = string
  default     = "traefik"
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
  description = "Node pool for placement"
  type        = string
  default     = "core"
}

variable "priority" {
  description = "Job priority"
  type        = number
  default     = 50
}

# -----------------------------------------------------------------------
# Placement
# -----------------------------------------------------------------------

variable "ingress_node_constraint" {
  description = "Node selector for ingress role"
  type        = string
  default     = "ingress"
}

# -----------------------------------------------------------------------
# Traefik Configuration
# -----------------------------------------------------------------------

variable "traefik_version" {
  description = "Traefik Docker image version"
  type        = string
  default     = "v3.5.3"
}

variable "dashboard_port" {
  description = "Dashboard port (LAN-only)"
  type        = number
  default     = 8081
}

variable "http_port" {
  description = "HTTP port"
  type        = number
  default     = 80
}

variable "https_port" {
  description = "HTTPS port"
  type        = number
  default     = 443
}

variable "certificate_cn" {
  description = "Certificate Common Name"
  type        = string
  default     = "*.munchbox"
}

variable "certificate_days" {
  description = "Certificate validity days"
  type        = number
  default     = 3650
}

# -----------------------------------------------------------------------
# Consul Integration
# -----------------------------------------------------------------------

variable "consul_address" {
  description = "Consul API address"
  type        = string
  default     = "127.0.0.1:8500"
}

variable "consul_token_path" {
  description = "Vault path to Consul token"
  type        = string
  default     = "kv/data/traefik"
}

# -----------------------------------------------------------------------
# Resources
# -----------------------------------------------------------------------

variable "cpu" {
  description = "CPU allocation"
  type        = number
  default     = 200
}

variable "memory" {
  description = "Memory allocation (MB)"
  type        = number
  default     = 256
}

# -----------------------------------------------------------------------
# Vault
# -----------------------------------------------------------------------

variable "vault_enabled" {
  description = "Enable Vault integration"
  type        = bool
  default     = true
}

variable "vault_role" {
  description = "Vault role for workload identity"
  type        = string
  default     = "nomad-workloads"
}
