# -------------------------------------------------------------------------------
# Nomad Service Pack - Variables
#
# Project: Munchbox / Author: Alex Freidah
#
# Complete variable definitions with types, defaults, and documentation.
# Variables are organized by functional area for easier navigation.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Core Job Configuration
# -------------------------------------------------------------------------------

variable "job_name" {
  description = "Name of the Nomad job (used for job ID, service name, task group name)"
  type        = string
}

variable "job_type" {
  description = "Job type: 'service' (long-running) or 'system' (runs on every node)"
  type        = string
  default     = "service"
}

variable "job_description" {
  description = "Human-readable job description for documentation"
  type        = string
  default     = ""
}

variable "region" {
  description = "Nomad region for job placement"
  type        = string
  default     = "global"
}

variable "datacenters" {
  description = "List of datacenters where this job can run"
  type        = list(string)
  default     = ["pi-dc"]
}

variable "namespace" {
  description = "Nomad namespace for job isolation"
  type        = string
  default     = "default"
}

variable "node_pool" {
  description = "Node pool for job placement (e.g., 'all', 'core', 'utility')"
  type        = string
  default     = "all"
}

variable "priority" {
  description = "Job scheduling priority (0-100, higher is more important)"
  type        = number
  default     = 50
}

variable "category" {
  description = "Service category for metadata tagging (e.g., 'monitoring', 'logging', 'infrastructure')"
  type        = string
  default     = ""
}

# -------------------------------------------------------------------------------
# Group Configuration
# -------------------------------------------------------------------------------

variable "count" {
  description = "Number of task group instances (service jobs only, system jobs ignore this)"
  type        = number
  default     = 1
}

variable "constraints" {
  description = "Job placement constraints as list of objects. Example: [{ attribute = \"$${node.unique.name}\", operator = \"=\", value = \"cabot\" }]"
  default     = []
}

# -------------------------------------------------------------------------------
# Network Configuration
# -------------------------------------------------------------------------------

variable "network_preset" {
  description = "Network mode: 'bridge' (isolated with port mapping) or 'host' (direct host networking)"
  type        = string
  default     = "bridge"
}

variable "ports" {
  description = "Port definitions as list of objects. For bridge: [{ name = \"http\", to = 8080 }] (dynamic host port). For host: [{ name = \"http\", static = 8080 }] (bind to host port)"
  default     = []
}

variable "dns_servers" {
  description = "DNS servers for bridge networking (not used for host mode)"
  type        = list(string)
  default     = []
}

variable "dns_searches" {
  description = "DNS search domains for bridge networking"
  type        = list(string)
  default     = []
}

variable "dns_options" {
  description = "DNS resolver options for bridge networking (e.g., ['timeout:2', 'attempts:3'])"
  type        = list(string)
  default     = []
}

# -------------------------------------------------------------------------------
# Storage
# -------------------------------------------------------------------------------

variable "volume" {
  description = "Host volume configuration. Example: { name = \"data\", type = \"host\", source = \"app-data\", mount_path = \"/data\", read_only = false }"
  default     = {}
}

# -------------------------------------------------------------------------------
# Task Configuration
# -------------------------------------------------------------------------------

variable "task" {
  description = "Complete task configuration as an object. Required: name, driver, config. Optional: user, env, resources, templates, vault"
  default     = {}
}

# -------------------------------------------------------------------------------
# Resources
# -------------------------------------------------------------------------------

variable "resource_tier" {
  description = "Predefined resource tier: nano, tiny, small, medium, large, xlarge. Ignored if 'resources' variable is set."
  type        = string
  default     = "small"
}

variable "resource_tiers" {
  description = "Predefined resource tier definitions (CPU in MHz, memory in MB)"
  default = {
    nano   = { cpu = 50, memory = 64 }
    tiny   = { cpu = 100, memory = 128 }
    small  = { cpu = 200, memory = 256 }
    medium = { cpu = 500, memory = 512 }
    large  = { cpu = 1000, memory = 1024 }
    xlarge = { cpu = 2000, memory = 2048 }
  }
}

variable "resources" {
  description = "Explicit resource configuration (overrides resource_tier when non-empty). Example: { cpu = 500, memory = 512, memory_max = 1024 }"
  default     = {}
}

# -------------------------------------------------------------------------------
# Deployment Strategy
# -------------------------------------------------------------------------------

variable "deployment_profile" {
  description = "Deployment profile: 'standard' (canary), 'canary' (canary), 'rolling' (no canary)"
  type        = string
  default     = "standard"
}

variable "deployment_profiles" {
  description = "Predefined deployment strategy definitions"
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
  description = "Metadata profile name (determines tier classification)"
  type        = string
  default     = "tier2"
}

variable "meta_profiles" {
  description = "Metadata profile definitions (used for job meta tags)"
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
  description = "Restart interval window (e.g., '5m', '1h')"
  type        = string
  default     = "5m"
}

variable "restart_delay" {
  description = "Delay between restart attempts (e.g., '30s', '1m')"
  type        = string
  default     = "30s"
}

variable "restart_mode" {
  description = "Restart mode: 'fail' (give up after attempts) or 'delay' (keep trying)"
  type        = string
  default     = "fail"
}

# -------------------------------------------------------------------------------
# Reschedule Policy
# -------------------------------------------------------------------------------

variable "reschedule_preset" {
  description = "Reschedule preset: 'standard', 'aggressive', 'extended'"
  type        = string
  default     = "standard"
}

variable "reschedule_presets" {
  description = "Reschedule preset definitions"
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
  description = "External file injection configuration. Example: { enabled = true, base_path = \"jobs/app/files\" }"
  default = {
    enabled   = false
    base_path = ""
  }
}

variable "external_templates" {
  description = "External template file configurations. Each template object can include: destination, source_file, env, perms, change_mode, change_signal, left_delimiter, right_delimiter"
  default     = []
}

# -------------------------------------------------------------------------------
# Vault Integration
# -------------------------------------------------------------------------------

variable "vault_role" {
  description = "Vault role for workload identity (enables Vault integration when set)"
  type        = string
  default     = ""
}

# -------------------------------------------------------------------------------
# Service Registration
# -------------------------------------------------------------------------------

variable "standard_service_enabled" {
  description = "Enable automatic service registration (set to false to use manual service configuration in task)"
  type        = bool
  default     = true
}

variable "standard_service_port" {
  description = "Port label for service registration (must match a port name in 'ports' variable)"
  type        = string
  default     = "http"
}

variable "standard_service_port_number" {
  description = "Actual port number for Traefik loadbalancer configuration"
  type        = number
  default     = 80
}

variable "standard_http_check_enabled" {
  description = "Enable HTTP health check for service"
  type        = bool
  default     = false
}

variable "standard_http_check_path" {
  description = "HTTP health check path (e.g., '/', '/health', '/-/ready')"
  type        = string
  default     = "/"
}

variable "additional_tags" {
  description = "Additional Consul service tags (appended to all service registrations)"
  type        = list(string)
  default     = []
}

# -------------------------------------------------------------------------------
# Traefik HTTP Ingress
# -------------------------------------------------------------------------------

variable "traefik_enabled" {
  description = "Enable Traefik HTTP/HTTPS routing for this service"
  type        = bool
  default     = false
}

variable "traefik_host" {
  description = "Hostname for Traefik routing (Host(`...`) rule). If empty, defaults to '<job_name>.munchbox' inside the template."
  type        = string
  default     = ""
}

variable "traefik_entrypoints" {
  description = "Traefik entrypoints (comma-separated if multiple, e.g., 'web,websecure')"
  type        = string
  default     = "websecure"
}

variable "traefik_tls_enabled" {
  description = "Enable TLS on the Traefik router"
  type        = bool
  default     = true
}

variable "traefik_middlewares" {
  description = "Traefik middlewares (comma-separated if multiple, e.g., 'auth@file,compress@file')"
  type        = string
  default     = "dashboard-allowlan@file"
}

# -------------------------------------------------------------------------------
# Consul Connect Service Mesh
# -------------------------------------------------------------------------------

variable "consul_connect_enabled" {
  description = "Enable Consul Connect service mesh with automatic mTLS"
  type        = bool
  default     = false
}

variable "connect_upstreams" {
  description = "Upstream services this service needs to connect to via Connect mesh. Example: [{ destination_name = \"database\", local_bind_port = 5432 }]"
  default     = []
}

variable "connect_sidecar_resources" {
  description = "Resource allocation for Envoy sidecar proxy (CPU in MHz, memory in MB)"
  default = {
    cpu    = 200
    memory = 128
  }
}

# -------------------------------------------------------------------------------
# Termination
# -------------------------------------------------------------------------------

variable "kill_timeout" {
  description = "Time to wait between SIGTERM and SIGKILL (e.g., '30s', '1m')"
  type        = string
  default     = "30s"
}

variable "kill_signal" {
  description = "Signal to send on task shutdown (SIGTERM, SIGINT, SIGKILL)"
  type        = string
  default     = "SIGTERM"
}

# -------------------------------------------------------------------------------
# Advanced / Utilities
# -------------------------------------------------------------------------------

variable "use_node_hostname" {
  description = "Inject HOSTNAME environment variable from node.unique.name"
  type        = bool
  default     = false
}

variable "standard_service_address_mode" {
  description = "Service address mode: 'alloc' (bridge IP) or 'host' (host IP + mapped port)"
  type        = string
  default     = "alloc"
}
