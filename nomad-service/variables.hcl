# -------------------------------------------------------------------------------
# Project: Munchbox
# Author: Alex Freidah
# -------------------------------------------------------------------------------
# Nomad Pack variables for nomad-service. Defines all available configuration
# options including resource tiers, deployment profiles, constraint presets,
# and network configurations for the generic service pack.
#
# This file is the single source of truth for defaults. It also supports:
#   - environment overlays (environment, env_defaults)
#   - component registry (component, component_registry) for DRY jobs
# -------------------------------------------------------------------------------


# -------------------------------------------------------------------------------
# Job Configuration
# -------------------------------------------------------------------------------

# --- Core Job Configuration
variable "job_name" {
  description = "Name of the Nomad job"
  type        = string
  default     = ""
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

variable "constraints" {
  description = "Placement constraints for task group"
  type        = list(map(string))
  default     = []
}

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

variable "task" {
  description = "Single task configuration"
  type        = map(string)
  default     = {}
}

variable "tasks" {
  description = "Multiple task configurations"
  type        = list(object({
    name   = string
    driver = string
  }))
  default = []
}


# -------------------------------------------------------------------------------
# Restart Behavior
# -------------------------------------------------------------------------------

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


# -------------------------------------------------------------------------------
# Resource Configuration
# -------------------------------------------------------------------------------

variable "resource_tier" {
  description = "Named resource tier (nano, tiny, small, medium, large, xlarge)"
  type        = string
  default     = "medium"
}

variable "resource_tiers" {
  description = "Predefined resource tiers mapping tier names to CPU/memory/disk"
  type = map(object({
    cpu            = number
    memory         = number
    ephemeral_disk = number
  }))
  default = {
    nano = {
      cpu            = 50
      memory         = 128
      ephemeral_disk = 100
    }
    tiny = {
      cpu            = 100
      memory         = 256
      ephemeral_disk = 200
    }
    small = {
      cpu            = 250
      memory         = 512
      ephemeral_disk = 500
    }
    medium = {
      cpu            = 500
      memory         = 1024
      ephemeral_disk = 1000
    }
    large = {
      cpu            = 1000
      memory         = 2048
      ephemeral_disk = 2000
    }
    xlarge = {
      cpu            = 2000
      memory         = 4096
      ephemeral_disk = 4000
    }
  }
}

variable "cpu" {
  description = "Optional: CPU mhz for the primary task (0 = use resource_tier)"
  type        = number
  default     = 0
}

variable "memory" {
  description = "Optional: Memory MB for the primary task (0 = use resource_tier)"
  type        = number
  default     = 0
}


# -------------------------------------------------------------------------------
# Deployment Profiles
# -------------------------------------------------------------------------------

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
    canary            = number
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
      canary            = 0
    }
    canary = {
      max_parallel      = 1
      health_check      = "checks"
      min_healthy_time  = "30s"
      healthy_deadline  = "5m"
      progress_deadline = "15m"
      auto_revert       = true
      auto_promote      = false
      canary            = 1
    }
    production = {
      max_parallel      = 1
      health_check      = "checks"
      min_healthy_time  = "60s"
      healthy_deadline  = "10m"
      progress_deadline = "30m"
      auto_revert       = true
      auto_promote      = false
      canary            = 0
    }
  }
}


# -------------------------------------------------------------------------------
# Metadata & Categorization
# -------------------------------------------------------------------------------

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
      ports         = ["http"]
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
      delay            = "15s"
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

variable "dns_servers" {
  description = "DNS servers for task group"
  type        = list(string)
  default     = ["192.168.68.62", "192.168.68.64"]
}


# -------------------------------------------------------------------------------
# Network Ports
# -------------------------------------------------------------------------------

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

variable "volume" {
  description = "Task group volume mount configuration"
  type = object({
    name            = string
    type            = string
    source          = string
    read_only       = bool
    mount_path      = string
    attachment_mode = string
    access_mode     = string
  })
  default = {
    name            = ""
    type            = ""
    source          = ""
    read_only       = false
    mount_path      = ""
    attachment_mode = ""
    access_mode     = ""
  }
}

variable "volume_mounts" {
  description = "Additional volume mounts for task"
  type = list(object({
    volume      = string
    destination = string
    read_only   = bool
  }))
  default = []
}

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

variable "vault" {
  description = "Vault workload identity configuration"
  type = object({
    enabled       = bool
    role          = string
    policy        = string
    change_mode   = string
    change_signal = string
    env           = bool
    namespace     = string
    secrets       = map(string)
    aud           = list(string)
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

variable "vault_enabled" {
  description = "Alias: enable Vault/OpenBao integration (maps to vault.enabled)"
  type        = bool
  default     = false
}

variable "vault_role" {
  description = "Alias: primary Vault/OpenBao role/policy (maps to vault.role/policy)"
  type        = string
  default     = ""
}

variable "vault_policies" {
  description = "Alias: additional Vault policies (supplemental to vault.policy)"
  type        = list(string)
  default     = []
}

variable "vault_change_mode" {
  description = "Alias: rotation behavior (signal|restart|noop) (maps to vault.change_mode)"
  type        = string
  default     = "restart"
}

variable "vault_change_signal" {
  description = "Alias: signal sent on rotation when mode = signal (maps to vault.change_signal)"
  type        = string
  default     = "SIGTERM"
}


# -------------------------------------------------------------------------------
# Traefik Routing
# -------------------------------------------------------------------------------

variable "traefik_enable" {
  description = "Enable Traefik service routing"
  type        = bool
  default     = false
}

variable "traefik_internal_host" {
  description = "Internal hostname for munchbox domain (e.g., 'resume' for resume.munchbox)"
  type        = string
  default     = ""
}

variable "traefik_external_hosts" {
  description = "External hostnames for public routing (e.g., ['alexfreidah.com', 'www.alexfreidah.com'])"
  type        = list(string)
  default     = []
}

variable "traefik_internal_middlewares" {
  description = "Middlewares to apply to internal routes"
  type        = list(string)
  default     = []
}

variable "traefik_internal_entrypoint" {
  description = "Entrypoint for internal routes (websecure, web, etc)"
  type        = string
  default     = "websecure"
}

variable "traefik_external_entrypoint" {
  description = "Entrypoint for external routes (web, websecure, etc)"
  type        = string
  default     = "web"
}

variable "traefik_service_port" {
  description = "Service port for Traefik to route to"
  type        = number
  default     = 8080
}


# -------------------------------------------------------------------------------
# Logging Configuration
# -------------------------------------------------------------------------------

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

variable "group_name" {
  description = "Task group name (defaults to job name)"
  type        = string
  default     = ""
}

variable "count" {
  description = "Number of task group instances"
  type        = number
  default     = 1
}


# -------------------------------------------------------------------------------
# Network Hostname
# -------------------------------------------------------------------------------

variable "network_hostname" {
  description = "Hostname for task group network namespace"
  type        = string
  default     = ""
}

variable "dns_searches" {
  description = "DNS search domains for task group"
  type        = list(string)
  default     = []
}

variable "dns_options" {
  description = "DNS resolver options"
  type        = list(string)
  default     = []
}


# -------------------------------------------------------------------------------
# Job Update Strategy
# -------------------------------------------------------------------------------

variable "stagger" {
  description = "Time between task updates during rolling deployment"
  type        = string
  default     = "30s"
}


# -------------------------------------------------------------------------------
# External File Configuration
# -------------------------------------------------------------------------------

variable "external_files" {
  description = "Load templates from external files using fileContents"
  type = object({
    enabled   = bool
    base_path = string
  })
  default = {
    enabled   = false
    base_path = ""
  }
}

variable "external_templates" {
  description = "External template file paths (relative to base_path)"
  type = list(object({
    destination     = string
    source_file     = string
    env             = bool
    perms           = string
    change_mode     = string
    change_signal   = string
    left_delimiter  = string
    right_delimiter = string
  }))
  default = []
}


# -----------------------------------------------------------------------
# Periodic Schedule Configuration
# -----------------------------------------------------------------------

variable "periodic" {
  description = "Periodic schedule configuration for batch jobs"
  type = object({
    enabled          = bool
    cron             = string
    prohibit_overlap = bool
    time_zone        = string
  })
  default = {
    enabled          = false
    cron             = ""
    prohibit_overlap = true
    time_zone        = "UTC"
  }
}


# -------------------------------------------------------------------------------
# Prometheus Configuration Paths
# -------------------------------------------------------------------------------

variable "prometheus_config_path" {
  description = "Absolute host path to prometheus.yml (mounted read-only when set)"
  type        = string
  default     = ""
}

variable "alert_rules_path" {
  description = "Absolute host path to a directory of alerting rules (mounted RO)"
  type        = string
  default     = ""
}


# -------------------------------------------------------------------------------
# Standard Service Shortcut (Generated HTTP Check)
# -------------------------------------------------------------------------------

variable "standard_http_check_enabled" {
  description = "Enable a default service with a single HTTP check"
  type        = bool
  default     = false
}

variable "standard_http_check_port" {
  description = "Port label for the default HTTP check"
  type        = string
  default     = "http"
}

variable "standard_http_check_path" {
  description = "HTTP path for the default check"
  type        = string
  default     = "/ready"
}

variable "standard_service_name" {
  description = "Optional override for generated service name (defaults to job_name)"
  type        = string
  default     = ""
}


# -------------------------------------------------------------------------------
# Service-specific Compatibility Variables
# -------------------------------------------------------------------------------

variable "loki_address" {
  description = "Destination Loki push endpoint for log shipping"
  type        = string
  default     = ""
}

variable "http_port" {
  description = "Optional HTTP listener port for services that expose a metrics/status endpoint"
  type        = number
  default     = 0
}


# -------------------------------------------------------------------------------
# Environment Overlays
# -------------------------------------------------------------------------------

variable "environment" {
  description = "Optional environment key to load from env_defaults (e.g., dev, home, prod)"
  type        = string
  default     = ""
}

variable "env_defaults" {
  description = "Per-environment defaults that can override common vars"
  type = map(object({
    namespace   = string
    node_pool   = string
    datacenters = list(string)
    dns_servers = list(string)
  }))
  default = {}
}


# -------------------------------------------------------------------------------
# Component Registry Selection
# -------------------------------------------------------------------------------

variable "component" {
  description = "Logical component key to load from component_registry"
  type        = string
  default     = ""
}

variable "component_registry" {
  description = "Registry of component definitions used to auto-populate pack vars"
  type = map(object({
    # -----------------------------------------------------------------------
    # Group-level configuration
    # -----------------------------------------------------------------------

    # job-wide type override (service | system | batch | sysbatch)
    job_type = string

    ports = list(object({
      name   = string
      static = number
      port   = number
    }))

    external_files = object({
      enabled   = bool
      base_path = string
    })

    external_templates = list(object({
      destination     = string
      source_file     = string
      env             = bool
      perms           = string
      change_mode     = string
      change_signal   = string
      left_delimiter  = string
      right_delimiter = string
    }))

    # -----------------------------------------------------------------------
    # Standard HTTP health check parameters (used by single_task.tpl)
    # -----------------------------------------------------------------------
    standard_http_check_enabled = bool
    standard_http_check_port    = string
    standard_http_check_path    = string
    standard_service_name       = string

    # -----------------------------------------------------------------------
    # Traefik-related configuration
    # -----------------------------------------------------------------------
    traefik_enable              = bool
    traefik_internal_host       = string
    traefik_internal_entrypoint = string
    traefik_service_port        = number

    # -----------------------------------------------------------------------
    # Task definition (fully explicit typing)
    # -----------------------------------------------------------------------
    task = object({
      name    = string
      driver  = string

      config = object({
        image              = string
        args               = list(string)
        ports              = list(string)
        volumes            = list(string)
        entrypoint         = list(string)
        command            = string
        devices            = list(string)
        network_mode       = string
        force_pull         = bool
        image_pull_timeout = string
        dns_servers        = list(string)
        dns_search_domains = list(string)
        dns_options        = list(string)
        cap_add            = list(string)
      })

      env = map(string)

      templates = list(object({
        destination   = string
        data          = string
        env           = bool
        perms         = string
        change_mode   = string
        change_signal = string
      }))

      volume_mounts = list(object({
        volume      = string
        destination = string
        read_only   = bool
      }))

      resources = object({
        tier       = string
        cpu        = number
        memory     = number
        memory_max = number
      })

      restart = object({
        attempts = number
        interval = string
        delay    = string
        mode     = string
      })

      kill_timeout   = string
      kill_signal    = string
      shutdown_delay = string
    })
  }))
  default = {}
}
