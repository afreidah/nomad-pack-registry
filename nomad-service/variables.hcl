# -------------------------------------------------------------------------------
# Project: Nomad Job Template
# Author: Alex Freidah
# -------------------------------------------------------------------------------
# Nomad Pack variables for nomad-service. Defines all available configuration
# options including resource tiers, deployment profiles, constraint presets,
# and network configurations.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Core Job Configuration
# -----------------------------------------------------------------------

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

# -----------------------------------------------------------------------
# Constraints
# -----------------------------------------------------------------------

variable "constraints" {
  description = "Placement constraints for task group"
  type        = list(map(string))
  default     = []
}

# -----------------------------------------------------------------------
# Task Configuration
# -----------------------------------------------------------------------

variable "task" {
  description = "Single task configuration"
  type        = map(string)
  default     = null
}

variable "tasks" {
  description = "Multiple task configurations"
  type        = list(map(string))
  default     = []
}

# -----------------------------------------------------------------------
# Restart Behavior
# -----------------------------------------------------------------------

variable "restart_attempts" {
  description = "Number of restart attempts before giving up"
  type        = number
  default     = 2
}

variable "restart_interval" {
  description = "Time interval for restart attempts"
  type        = string
  default     = "30m"
}

variable "restart_delay" {
  description = "Delay before restarting failed task"
  type        = string
  default     = "15s"
}

variable "restart_mode" {
  description = "Restart mode (fail, delay)"
  type        = string
  default     = "fail"
}

# -----------------------------------------------------------------------
# Resource Configuration
# -----------------------------------------------------------------------

variable "resource_tier" {
  description = "Named resource tier (nano, tiny, small, medium, large, xlarge)"
  type        = string
  default     = "medium"
}

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

# -----------------------------------------------------------------------
# Deployment Profiles
# -----------------------------------------------------------------------

variable "deployment_profile" {
  description = "Named deployment profile (standard, canary, production)"
  type        = string
  default     = "standard"
}

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

# -----------------------------------------------------------------------
# Meta Profiles
# -----------------------------------------------------------------------

variable "meta_profile" {
  description = "Named meta profile (tier1, tier2, tier3)"
  type        = string
  default     = "tier3"
}

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

# -----------------------------------------------------------------------
# Category Defaults
# -----------------------------------------------------------------------

variable "category" {
  description = "Service category (web, database, cache, monitoring, worker)"
  type        = string
  default     = "web"
}

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

# -----------------------------------------------------------------------
# Reschedule Presets
# -----------------------------------------------------------------------

variable "reschedule_preset" {
  description = "Named reschedule preset (standard, aggressive, stateful)"
  type        = string
  default     = "standard"
}

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
      delay            = "5s"
      delay_function   = "exponential"
      max_reschedules  = 5
      unlimited        = false
    }
    aggressive = {
      delay            = "1s"
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

# -----------------------------------------------------------------------
# Network Presets
# -----------------------------------------------------------------------

variable "network_preset" {
  description = "Named network preset (bridge, host)"
  type        = string
  default     = "bridge"
}

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

# -----------------------------------------------------------------------
# Constraint Presets
# -----------------------------------------------------------------------

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

# -----------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------

variable "dns_servers" {
  description = "DNS servers for task group"
  type        = list(string)
  default     = ["172.17.0.1"]
}
