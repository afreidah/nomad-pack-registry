# -------------------------------------------------------------------------------
# Variables for nomad-service pack
#
# Project: Munchbox / Author: Alex Freidah
#
# NO TYPE SPECIFICATIONS FOR COMPLEX VARIABLES
# Nomad-pack doesn't support 'any' or complex nested types
# -------------------------------------------------------------------------------

# --- Component selection ---
variable "component" {
  description = "Name of component from component_registry to deploy"
  type        = string
  default     = ""
}

variable "component_registry" {
  description = "Registry of predefined component configurations"
  # NO TYPE - nomad-pack can't handle complex types
  default = {}
}

# --- Job configuration ---
variable "job_name" {
  description = "Name of the Nomad job"
  type        = string
  default     = ""
}

variable "job_type" {
  description = "Job type: service or system"
  type        = string
  default     = "service"
}

variable "job_description" {
  description = "Description for the job"
  type        = string
  default     = ""
}

variable "region" {
  description = "Region for job deployment"
  type        = string
  default     = "global"
}

variable "datacenters" {
  description = "List of datacenters"
  type        = list(string)
  default     = ["dc1"]
}

variable "namespace" {
  description = "Nomad namespace"
  type        = string
  default     = "default"
}

variable "node_pool" {
  description = "Node pool for job placement"
  type        = string
  default     = ""
}

variable "priority" {
  description = "Job priority (0-100)"
  type        = number
  default     = 50
}

variable "category" {
  description = "Service category for tagging"
  type        = string
  default     = "service"
}

# --- Group configuration ---
variable "group_name" {
  description = "Name of the task group"
  type        = string
  default     = ""
}

variable "count" {
  description = "Number of instances (service jobs only)"
  type        = number
  default     = 1
}

# --- Constraints ---
variable "constraints" {
  description = "Job-level placement constraints"
  # NO TYPE
  default = []
}

variable "group_constraints" {
  description = "Group-level placement constraints"
  # NO TYPE
  default = []
}

# --- Network ---
variable "network_preset" {
  description = "Network mode preset name"
  type        = string
  default     = "bridge"
}

variable "network_presets" {
  description = "Network configuration presets"
  # NO TYPE
  default = {
    bridge = { mode = "bridge" }
    host   = { mode = "host" }
  }
}

variable "ports" {
  description = "Port definitions"
  # NO TYPE
  default = []
}

variable "dns_servers" {
  description = "DNS servers for the job"
  type        = list(string)
  default     = []
}

# --- Storage ---
variable "volume" {
  description = "Host volume configuration"
  # NO TYPE
  default = {}
}

# --- Task configuration ---
variable "task" {
  description = "Task configuration"
  # NO TYPE
  default = {}
}

variable "env" {
  description = "Environment variables"
  # NO TYPE
  default = {}
}

# --- Resources ---
variable "resource_tier" {
  description = "Resource tier name"
  type        = string
  default     = "small"
}

variable "resource_tiers" {
  description = "Resource tier definitions"
  # NO TYPE
  default = {
    tiny   = { cpu = 50, memory = 64 }
    small  = { cpu = 100, memory = 128 }
    medium = { cpu = 500, memory = 512 }
    large  = { cpu = 1000, memory = 1024 }
  }
}

variable "resources" {
  description = "Direct resource specification"
  # NO TYPE
  default = {}
}

# --- Templates ---
variable "external_files" {
  description = "External files configuration"
  # NO TYPE
  default = {}
}

variable "external_templates" {
  description = "Template configurations"
  # NO TYPE
  default = []
}

# --- Service configuration ---
variable "standard_http_check_enabled" {
  description = "Enable standard HTTP health check"
  type        = bool
  default     = false
}

variable "standard_http_check_path" {
  description = "HTTP health check path"
  type        = string
  default     = "/"
}

variable "standard_http_check_port" {
  description = "HTTP health check port name"
  type        = string
  default     = "http"
}

variable "standard_http_check_interval" {
  description = "Health check interval"
  type        = string
  default     = "10s"
}

variable "standard_http_check_timeout" {
  description = "Health check timeout"
  type        = string
  default     = "3s"
}

variable "standard_service_name" {
  description = "Service name for Consul"
  type        = string
  default     = ""
}

variable "service_tags" {
  description = "Service tags for Consul"
  type        = list(string)
  default     = []
}

# --- Traefik integration ---
variable "traefik_enable" {
  description = "Enable Traefik routing"
  type        = bool
  default     = false
}

variable "traefik_internal_host" {
  description = "Internal hostname for Traefik"
  type        = string
  default     = ""
}

variable "traefik_internal_entrypoint" {
  description = "Traefik entrypoint"
  type        = string
  default     = "websecure"
}

variable "traefik_service_name" {
  description = "Traefik service name"
  type        = string
  default     = ""
}

variable "traefik_service_port" {
  description = "Port for Traefik service"
  type        = number
  default     = 80
}

# --- Deployment ---
variable "deployment_profile" {
  description = "Deployment profile name"
  type        = string
  default     = "standard"
}

variable "deployment_profiles" {
  description = "Deployment profile definitions"
  # NO TYPE
  default = {
    standard = {
      max_parallel      = 1
      health_check      = "checks"
      min_healthy_time  = "30s"
      healthy_deadline  = "5m"
      progress_deadline = "10m"
      auto_revert       = true
      auto_promote      = true
    }
  }
}

# --- Metadata ---
variable "meta" {
  description = "Job metadata"
  # NO TYPE
  default = {}
}

variable "meta_profile" {
  description = "Metadata profile name"
  type        = string
  default     = ""
}

variable "meta_profiles" {
  description = "Metadata profile definitions"
  # NO TYPE
  default = {}
}

# --- Restart policy ---
variable "restart_attempts" {
  description = "Number of restart attempts"
  type        = number
  default     = 3
}

variable "restart_interval" {
  description = "Restart interval"
  type        = string
  default     = "5m"
}

variable "restart_delay" {
  description = "Restart delay"
  type        = string
  default     = "30s"
}

variable "restart_mode" {
  description = "Restart mode"
  type        = string
  default     = "fail"
}

variable "restart_preset" {
  description = "Restart profile name"
  type        = string
  default     = ""
}

variable "restart_profiles" {
  description = "Restart profile definitions"
  # NO TYPE
  default = {}
}

# --- Reschedule policy ---
variable "reschedule_preset" {
  description = "Reschedule profile name"
  type        = string
  default     = ""
}

variable "reschedule_presets" {
  description = "Reschedule profile definitions"
  # NO TYPE
  default = {
    standard = {
      max_reschedules = 3
      delay           = "5s"
      delay_function  = "exponential"
      unlimited       = false
    }
  }
}

# --- Termination ---
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

# --- Environment ---
variable "environment" {
  description = "Environment name (dev/home/prod)"
  type        = string
  default     = ""
}

variable "env_defaults" {
  description = "Environment-specific defaults"
  # NO TYPE
  default = {}
}
