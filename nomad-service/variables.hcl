# -------------------------------------------------------------------------------
# Project: Munchbox
# Author: Alex Freidah
# -------------------------------------------------------------------------------
# Nomad Pack variables for nomad-service. Defines all available configuration
# options including resource tiers, deployment profiles, constraint presets,
# and network configurations for the generic service pack.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Job Configuration
# -------------------------------------------------------------------------------

# --- Core Job Configuration
variable "job_name" {
  description = "Name of the Nomad job"
  type        = string
}

variable "job_description" {
  description = "Job description for header comments"
  type        = string
  default     = "Nomad service job template"
}

variable "job_type" {
  description = "Job type (service, batch, sysbatch)"
  type        = string
  default     = "service"
}

variable "datacenters" {
  description = "List of datacenters where job can be placed"
  type        = list(string)
  default     = ["pi-dc"]
}

variable "namespace" {
  description = "Nomad namespace for the job"
  type        = string
  default     = "default"
}

variable "priority" {
  description = "Job priority (0-100)"
  type        = number
  default     = 50
}

variable "region" {
  description = "Job region"
  type        = string
  default     = ""
}

variable "node_pool" {
  description = "Node pool for job placement"
  type        = string
  default     = ""
}

# -------------------------------------------------------------------------------
# Placement & Constraints
# -------------------------------------------------------------------------------

# --- Node Placement Constraints
variable "constraints" {
  description = "Placement constraints for task group"
  type        = list(map(string))
  default     = []
}

# --- Constraint Presets
variable "constraint_preset" {
  description = "Named constraint preset (mccoy_only, stabler_only, avoid_goren, tier1_nodes, or empty for none)"
  type        = string
  default     = ""
}

variable "constraint_presets" {
  description = "Predefined node placement constraints"
  type = map(list(object({
    attribute = string
    operator  = string
    value     = string
  })))
  default = {
    mccoy_only = [
      {
        attribute = "node.hostname"
        operator  = "="
        value     = "mccoy"
      }
    ]
    stabler_only = [
      {
        attribute = "node.hostname"
        operator  = "="
        value     = "stabler"
      }
    ]
    avoid_goren = [
      {
        attribute = "node.hostname"
        operator  = "!="
        value     = "goren"
      }
    ]
    tier1_nodes = [
      {
        attribute = "node.class"
        operator  = "="
        value     = "tier1"
      }
    ]
  }
}

# -------------------------------------------------------------------------------
# Task Configuration
# -------------------------------------------------------------------------------

# --- Single Task Configuration
variable "task" {
  description = "Single task configuration"
  type        = map(string)
  default     = null
}

# --- Multiple Task Configurations
variable "tasks" {
  description = "Multiple task configurations"
  type        = list(map(string))
  default     = []
}

# -------------------------------------------------------------------------------
# Restart Behavior
# -------------------------------------------------------------------------------

# --- Restart Attempts
variable "restart_attempts" {
  description = "Number of restart attempts before giving up"
  type        = number
  default     = 2
}

# --- Restart Interval
variable "restart_interval" {
  description = "Time interval for restart attempts"
  type        = string
  default     = "30m"
}

# --- Restart Delay
variable "restart_delay" {
  description = "Delay before restarting failed task"
  type        = string
  default     = "15s"
}

# --- Restart Mode
variable "restart_mode" {
  description = "Restart mode (fail, delay)"
  type        = string
  default     = "fail"
}

# -------------------------------------------------------------------------------
# Resource Configuration
# -------------------------------------------------------------------------------

# --- Resource Tier Selection
variable "resource_tier" {
  description = "Named resource tier (nano, tiny, small, medium, large, xlarge)"
  type        = string
  default     = "medium"
}

# --- Resource Tier Presets
variable "resource_tiers" {
  description = "Predefined resource tiers mapping tier names to CPU/memory/disk"
  type = map(object({
    cpu             = number
    memory          = number
    ephemeral_disk  = number
  }))
  default = {
    nano = {
      cpu             = 50
      memory          = 128
      ephemeral_disk  = 100
    }
    tiny = {
      cpu             = 100
      memory          = 256
      ephemeral_disk  = 200
    }
    small = {
      cpu             = 250
      memory          = 512
      ephemeral_disk  = 500
    }
    medium = {
      cpu             = 500
      memory          = 1024
      ephemeral_disk  = 1000
    }
    large = {
      cpu             = 1000
      memory          = 2048
      ephemeral_disk  = 2000
    }
    xlarge = {
      cpu             = 2000
      memory          = 4096
      ephemeral_disk  = 4000
    }
  }
}

# -------------------------------------------------------------------------------
# Deployment Profiles
# -------------------------------------------------------------------------------

# --- Deployment Profile Selection
variable "deployment_profile" {
  description = "Named deployment profile (standard, canary, production)"
  type        = string
  default     = "standard"
}

# --- Deployment Profile Presets
variable "deployment_profiles" {
  description = "Predefined deployment profiles with update strategies"
  type = map(object({
    max_parallel      = number
    health_check      = string
    min_healthy_time  = string
    healthy_deadline  = string
    progress_deadline = string
    auto_revert       = bool
    auto_promote      = bool
  }))
  default = {
    standard = {
      max_parallel      = 1
      health_check      = "checks"
      min_healthy_time  = "10s"
      healthy_deadline  = "3m"
      progress_deadline = "10m"
      auto_revert       = true
      auto_promote      = true
    }
    canary = {
      max_parallel      = 1
      health_check      = "checks"
      min_healthy_time  = "30s"
      healthy_deadline  = "5m"
      progress_deadline = "15m"
      auto_revert       = true
      auto_promote      = false
    }
    production = {
      max_parallel      = 1
      health_check      = "checks"
      min_healthy_time  = "60s"
      healthy_deadline  = "10m"
      progress_deadline = "30m"
      auto_revert       = true
      auto_promote      = false
    }
  }
}

# -------------------------------------------------------------------------------
# Metadata & Categorization
# -------------------------------------------------------------------------------

# --- Metadata Profile Selection
variable "meta_profile" {
  description = "Named meta profile (tier1, tier2, tier3)"
  type        = string
  default     = "tier3"
}

# --- Metadata Profile Presets
variable "meta_profiles" {
  description = "Predefined meta profiles for job categorization"
  type = map(object({
    tier = string
  }))
  default = {
    tier1 = {
      tier = "critical"
    }
    tier2 = {
      tier = "important"
    }
    tier3 = {
      tier = "standard"
    }
  }
}

# --- Service Category
variable "category" {
  description = "Service category (web, database, cache, monitoring, worker)"
  type        = string
  default     = "web"
}

# --- Category Default Presets
variable "category_defaults" {
  description = "Category-specific defaults including resource tier and ports"
  type = map(object({
    resource_tier = string
    ports         = list(string)
  }))
  default = {
    web = {
      resource_tier = "medium"
      ports         = ["http"]
    }
    database = {
      resource_tier = "large"
      ports         = []
    }
    cache = {
      resource_tier = "medium"
      ports         = []
    }
    monitoring = {
      resource_tier = "small"
      ports         = []
    }
    worker = {
      resource_tier = "small"
      ports         = []
    }
  }
}

# -------------------------------------------------------------------------------
# Reschedule Policies
# -------------------------------------------------------------------------------

# --- Reschedule Preset Selection
variable "reschedule_preset" {
  description = "Named reschedule preset (standard, aggressive, stateful)"
  type        = string
  default     = "standard"
}

# --- Reschedule Policy Presets
variable "reschedule_presets" {
  description = "Predefined reschedule policies"
  type = map(object({
    delay            = string
    delay_function   = string
    max_reschedules  = number
    unlimited        = bool
  }))
  default = {
    standard = {
      delay            = "30s"
      delay_function   = "exponential"
      max_reschedules  = 3
      unlimited        = false
    }
    aggressive = {
      delay            = "5s"
      delay_function   = "exponential"
      max_reschedules  = 10
      unlimited        = false
    }
    stateful = {
      delay            = "30s"
      delay_function   = "exponential"
      max_reschedules  = 3
      unlimited        = false
    }
  }
}

# -------------------------------------------------------------------------------
# Network Configuration
# -------------------------------------------------------------------------------

# --- Network Preset Selection
variable "network_preset" {
  description = "Named network preset (bridge, host)"
  type        = string
  default     = "bridge"
}

# --- Network Preset Definitions
variable "network_presets" {
  description = "Predefined network modes"
  type = map(object({
    mode = string
  }))
  default = {
    bridge = {
      mode = "bridge"
    }
    host = {
      mode = "host"
    }
  }
}

# --- DNS Servers
variable "dns_servers" {
  description = "DNS servers for task group"
  type        = list(string)
  default     = ["172.17.0.1"]
}

# -------------------------------------------------------------------------------
# Network Ports
# -------------------------------------------------------------------------------

# --- Port Definitions
variable "ports" {
  description = "Network port definitions for task group"
  type = list(object({
    name   = string
    static = number
    port   = number
  }))
  default = []
}

# -------------------------------------------------------------------------------
# Storage & Volumes
# -------------------------------------------------------------------------------

# --- Volume Definition
variable "volume" {
  description = "Task group volume mount configuration"
  type = object({
    name       = string
    type       = string
    source     = string
    read_only  = bool
    mount_path = string
  })
  default = null
}

# --- Additional Volume Mounts
variable "volume_mounts" {
  description = "Additional volume mounts for task"
  type = list(object({
    volume      = string
    destination = string
    read_only   = bool
  }))
  default = []
}

# --- Ephemeral Disk
variable "ephemeral_disk" {
  description = "Ephemeral disk configuration"
  type = object({
    size    = number
    migrate = bool
    sticky  = bool
  })
  default = {
    size    = 0
    migrate = false
    sticky  = false
  }
}

# -------------------------------------------------------------------------------
# Vault & Secrets
# -------------------------------------------------------------------------------

# --- Vault Integration
variable "vault" {
  description = "Vault workload identity configuration"
  type = object({
    enabled      = bool
    role         = string
    policy       = string
    change_mode  = string
    change_signal = string
    env          = bool
    namespace    = string
    secrets      = map(string)
    aud          = list(string)
  })
  default = {
    enabled       = false
    role          = ""
    policy        = ""
    change_mode   = "restart"
    change_signal = "SIGTERM"
    env           = true
    namespace     = ""
    secrets       = {}
    aud           = []
  }
}

# -------------------------------------------------------------------------------
# Traefik Routing
# -------------------------------------------------------------------------------

# --- Traefik Enable
variable "traefik_enable" {
  description = "Enable Traefik service routing"
  type        = bool
  default     = false
}

# --- Traefik Internal Hostname
variable "traefik_internal_host" {
  description = "Internal hostname for munchbox domain (e.g., 'resume' for resume.munchbox)"
  type        = string
  default     = ""
}

# --- Traefik External Hosts
variable "traefik_external_hosts" {
  description = "External hostnames for public routing (e.g., ['alexfreidah.com', 'www.alexfreidah.com'])"
  type        = list(string)
  default     = []
}

# --- Traefik Internal Middlewares
variable "traefik_internal_middlewares" {
  description = "Middlewares to apply to internal routes"
  type        = list(string)
  default     = []
}

# --- Traefik Internal Entrypoint
variable "traefik_internal_entrypoint" {
  description = "Entrypoint for internal routes (websecure, web, etc)"
  type        = string
  default     = "websecure"
}

# --- Traefik External Entrypoint
variable "traefik_external_entrypoint" {
  description = "Entrypoint for external routes (web, websecure, etc)"
  type        = string
  default     = "web"
}

# --- Traefik Service Port
variable "traefik_service_port" {
  description = "Service port for Traefik to route to"
  type        = number
  default     = 8080
}

# -------------------------------------------------------------------------------
# Logging Configuration
# -------------------------------------------------------------------------------

# --- Log Retention
variable "log_max_files" {
  description = "Maximum number of log files to retain"
  type        = number
  default     = 10
}

variable "log_max_file_size" {
  description = "Maximum log file size in MB"
  type        = number
  default     = 10
}

# -------------------------------------------------------------------------------
# Task Group Configuration
# -------------------------------------------------------------------------------

# --- Task Group Name
variable "group_name" {
  description = "Task group name (defaults to job name)"
  type        = string
  default     = ""
}

# --- Task Group Count
variable "count" {
  description = "Number of task group instances"
  type        = number
  default     = 1
}

# -------------------------------------------------------------------------------
# Network Hostname
# -------------------------------------------------------------------------------

# --- Network Hostname
variable "network_hostname" {
  description = "Hostname for task group network namespace"
  type        = string
  default     = ""
}

# --- DNS Search Domains
variable "dns_searches" {
  description = "DNS search domains for task group"
  type        = list(string)
  default     = []
}

# --- DNS Options
variable "dns_options" {
  description = "DNS resolver options"
  type        = list(string)
  default     = []
}

# -------------------------------------------------------------------------------
# Job Update Strategy
# -------------------------------------------------------------------------------

# --- Stagger Delay
variable "stagger" {
  description = "Time between task updates during rolling deployment"
  type        = string
  default     = "30s"
}
