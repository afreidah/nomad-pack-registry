# -------------------------------------------------------------------------------
# nomad-service Pack Variables
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Job Configuration
# -------------------------------------------------------------------------------

variable "job_name" {
  description = "Name of the Nomad job"
  type        = string
}

variable "job_type" {
  description = "Job type: service or system"
  type        = string
  default     = "service"
}

variable "job_description" {
  description = "Job description for documentation"
  type        = string
  default     = ""
}

variable "region" {
  description = "Nomad region"
  type        = string
  default     = "global"
}

variable "datacenters" {
  description = "List of datacenters"
  type        = list(string)
  default     = ["pi-dc"]
}

variable "namespace" {
  description = "Nomad namespace"
  type        = string
  default     = "default"
}

variable "node_pool" {
  description = "Node pool for job placement"
  type        = string
  default     = "all"
}

variable "priority" {
  description = "Job priority (0-100)"
  type        = number
  default     = 50
}

variable "category" {
  description = "Service category for metadata tagging"
  type        = string
  default     = ""
}

# -------------------------------------------------------------------------------
# Group Configuration
# -------------------------------------------------------------------------------

variable "count" {
  description = "Number of instances (service jobs only)"
  type        = number
  default     = 1
}

variable "constraints" {
  description = "Job placement constraints"
  # Type: list(object) but nomad-pack doesn't support it
  default = []
}

# -------------------------------------------------------------------------------
# Network Configuration
# -------------------------------------------------------------------------------

variable "network_preset" {
  description = "Network mode: bridge or host"
  type        = string
  default     = "bridge"
}

variable "network_presets" {
  description = "Network preset definitions (for jobs that define custom presets)"
  # Type: map(object) but nomad-pack doesn't support it
  default = {
    bridge = { mode = "bridge" }
    host   = { mode = "host" }
  }
}

variable "ports" {
  description = "Port definitions"
  # Type: list(object) but nomad-pack doesn't support it
  default = []
}

variable "dns_servers" {
  description = "DNS servers for the network"
  type        = list(string)
  default     = []
}

variable "dns_searches" {
  description = "DNS search domains"
  type        = list(string)
  default     = []
}

variable "dns_options" {
  description = "DNS options"
  type        = list(string)
  default     = []
}

# -------------------------------------------------------------------------------
# Storage
# -------------------------------------------------------------------------------

variable "volume" {
  description = "Host volume configuration"
  # Type: object but nomad-pack doesn't support it
  default = {}
}

# -------------------------------------------------------------------------------
# Task Configuration
# -------------------------------------------------------------------------------

variable "task" {
  description = "Task configuration (driver, config, env, services, resources, etc.)"
  # Type: object but nomad-pack doesn't support it
  default = {}
}

# -------------------------------------------------------------------------------
# Resources
# -------------------------------------------------------------------------------

variable "resource_tier" {
  description = "Resource tier: nano, tiny, small, medium, large, xlarge"
  type        = string
  default     = "small"
}

variable "resource_tiers" {
  description = "Resource tier definitions"
  # Type: map(object) but nomad-pack doesn't support it
  default = {
    nano   = { cpu = 50,   memory = 64 }
    tiny   = { cpu = 100,  memory = 128 }
    small  = { cpu = 200,  memory = 256 }
    medium = { cpu = 500,  memory = 512 }
    large  = { cpu = 1000, memory = 1024 }
    xlarge = { cpu = 2000, memory = 2048 }
  }
}

# -------------------------------------------------------------------------------
# Deployment Strategy
# -------------------------------------------------------------------------------

variable "deployment_profile" {
  description = "Deployment profile: standard, canary, rolling"
  type        = string
  default     = "standard"
}

variable "deployment_profiles" {
  description = "Deployment profile definitions"
  # Type: map(object) but nomad-pack doesn't support it
  default = {
    standard = {
      max_parallel      = 1
      canary            = 1
      health_check      = "checks"
      min_healthy_time  = "30s"
      healthy_deadline  = "5m"
      progress_deadline = "10m"
      auto_revert       = true
      auto_promote      = true
    }
    canary = {
      max_parallel      = 1
      canary            = 1
      health_check      = "checks"
      min_healthy_time  = "30s"
      healthy_deadline  = "5m"
      progress_deadline = "10m"
      auto_revert       = true
      auto_promote      = true
    }
    rolling = {
      max_parallel      = 2
      canary            = 0
      health_check      = "checks"
      min_healthy_time  = "10s"
      healthy_deadline  = "3m"
      progress_deadline = "10m"
      auto_revert       = true
      auto_promote      = false
    }
  }
}

# -------------------------------------------------------------------------------
# Metadata
# -------------------------------------------------------------------------------

variable "meta_profile" {
  description = "Metadata profile name"
  type        = string
  default     = "tier2"
}

variable "meta_profiles" {
  description = "Metadata profile definitions"
  # Type: map(object) but nomad-pack doesn't support it
  default = {
    tier1 = { tier = "critical" }
    tier2 = { tier = "important" }
  }
}

# -------------------------------------------------------------------------------
# Restart Policy
# -------------------------------------------------------------------------------

variable "restart_attempts" {
  description = "Number of restart attempts within interval"
  type        = number
  default     = 3
}

variable "restart_interval" {
  description = "Restart interval window"
  type        = string
  default     = "5m"
}

variable "restart_delay" {
  description = "Delay between restart attempts"
  type        = string
  default     = "30s"
}

variable "restart_mode" {
  description = "Restart mode: fail, delay"
  type        = string
  default     = "fail"
}

# -------------------------------------------------------------------------------
# Reschedule Policy
# -------------------------------------------------------------------------------

variable "reschedule_preset" {
  description = "Reschedule preset: standard, aggressive, extended"
  type        = string
  default     = "standard"
}

variable "reschedule_presets" {
  description = "Reschedule preset definitions"
  # Type: map(object) but nomad-pack doesn't support it
  default = {
    standard = {
      max_reschedules = 3
      interval        = "5m"
      delay           = "5s"
      delay_function  = "exponential"
      unlimited       = false
    }
    aggressive = {
      max_reschedules = 10
      interval        = "1h"
      delay           = "5s"
      delay_function  = "exponential"
      unlimited       = false
    }
    extended = {
      max_reschedules = 5
      interval        = "15m"
      delay           = "10s"
      delay_function  = "exponential"
      unlimited       = false
    }
  }
}

# -------------------------------------------------------------------------------
# External Configuration Files
# -------------------------------------------------------------------------------

variable "external_files" {
  description = "External file injection configuration"
  # Type: object but nomad-pack doesn't support it
  default = {
    enabled   = false
    base_path = ""
  }
}

variable "external_templates" {
  description = "External template file configurations"
  # Type: list(object) but nomad-pack doesn't support it
  default = []
}

# -------------------------------------------------------------------------------
# Vault Integration
# -------------------------------------------------------------------------------

variable "vault_role" {
  description = "Vault role for workload identity (enables Vault when set)"
  type        = string
  default     = ""
}

# -------------------------------------------------------------------------------
# Service Registration (Standard Pattern)
# -------------------------------------------------------------------------------

variable "standard_service_enabled" {
  description = "Enable standard service with Traefik auto-configuration"
  type        = bool
  default     = false
}

variable "standard_service_port" {
  description = "Port name for standard service registration"
  type        = string
  default     = "http"
}

variable "standard_service_port_number" {
  description = "Port number for Traefik loadbalancer.server.port"
  type        = number
  default     = 80
}

variable "standard_http_check_enabled" {
  description = "Enable HTTP health check for standard service"
  type        = bool
  default     = false
}

variable "standard_http_check_path" {
  description = "HTTP health check path"
  type        = string
  default     = "/"
}

variable "additional_tags" {
  description = "Additional Consul tags for standard service"
  type        = list(string)
  default     = []
}

# -------------------------------------------------------------------------------
# Termination
# -------------------------------------------------------------------------------

variable "kill_timeout" {
  description = "Task kill timeout"
  type        = string
  default     = "30s"
}

variable "kill_signal" {
  description = "Task kill signal"
  type        = string
  default     = "SIGTERM"
}

# -------------------------------------------------------------------------------
# Utilities
# -------------------------------------------------------------------------------

variable "use_node_hostname" {
  description = "Inject HOSTNAME env var from node.unique.name"
  type        = bool
  default     = false
}
