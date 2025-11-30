# -------------------------------------------------------------------------------
# Munchbox Service Pack — Variables
#
# Project: Munchbox / Author: Alex Freidah
#
# Minimal configuration with smart defaults. Most jobs need only: name, image,
# port. Everything else has sensible defaults for the Munchbox cluster.
# -------------------------------------------------------------------------------

# -------------------------------------------------------------------------------
# Required
# -------------------------------------------------------------------------------

variable "name" {
  description = "Job name (used for job ID, service name, task group)"
  type        = string
}

variable "image" {
  description = "Docker image"
  type        = string
  default     = ""
}

# -------------------------------------------------------------------------------
# Job Type & Scheduling
# -------------------------------------------------------------------------------

variable "type" {
  description = "Job type: 'service', 'system', or 'batch'"
  type        = string
  default     = "service"
}

variable "count" {
  description = "Number of instances (service jobs only)"
  type        = number
  default     = 1
}

variable "node" {
  description = "Pin to specific node (e.g., 'cabot', 'mccoy') or 'any'"
  type        = string
  default     = "any"
}

variable "priority" {
  description = "Job priority (1-100)"
  type        = number
  default     = 50
}

# -------------------------------------------------------------------------------
# Networking
# -------------------------------------------------------------------------------

variable "port" {
  description = "Primary container port"
  type        = number
  default     = 0
}

variable "port_name" {
  description = "Port label"
  type        = string
  default     = "http"
}

variable "host_network" {
  description = "Use host networking instead of bridge"
  type        = bool
  default     = false
}

variable "static_port" {
  description = "Bind to specific host port (implies host_network for that port)"
  type        = number
  default     = 0
}

variable "extra_ports" {
  description = "Additional ports: [{ name = 'grpc', port = 9090, static = false }]"
  type        = list(map(string))
  default     = []
}

variable "dns" {
  description = "Custom DNS servers (bridge mode only)"
  type        = list(string)
  default     = ["192.168.68.62", "192.168.68.64"]
}

# -------------------------------------------------------------------------------
# Resources
# -------------------------------------------------------------------------------

variable "size" {
  description = "Resource preset: tiny(100/128), small(200/256), medium(500/512), large(1000/1024), xlarge(2000/2048)"
  type        = string
  default     = "small"
}

variable "cpu" {
  description = "CPU MHz (overrides size)"
  type        = number
  default     = 0
}

variable "memory" {
  description = "Memory MB (overrides size)"
  type        = number
  default     = 0
}

variable "memory_max" {
  description = "Memory max MB (for memory oversubscription)"
  type        = number
  default     = 0
}

# -------------------------------------------------------------------------------
# Storage
#
# Three tiers:
#   - "ephemeral" (default): No persistence, container-local only
#   - "shared": NFS mount via gdrive, survives restarts, portable across nodes
#   - "local": Bind mount to /opt/nomad/data/<job>/, pinned to node, future Ceph
# -------------------------------------------------------------------------------

variable "storage" {
  description = "Storage tier: 'ephemeral', 'shared', or 'local'"
  type        = string
  default     = "ephemeral"
}

variable "storage_path" {
  description = "Container mount path for storage (required if storage != ephemeral)"
  type        = string
  default     = "/data"
}

variable "storage_subdir" {
  description = "Override subdirectory name (default: job name)"
  type        = string
  default     = ""
}

variable "storage_owner" {
  description = "Owner for local storage directory (uid:gid)"
  type        = string
  default     = "root:root"
}

variable "volumes" {
  description = "Additional Docker bind mounts: ['/host:/container:ro']"
  type        = list(string)
  default     = []
}

# -------------------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------------------

variable "env" {
  description = "Environment variables"
  type        = map(string)
  default     = {}
}

variable "args" {
  description = "Container arguments"
  type        = list(string)
  default     = []
}

variable "entrypoint" {
  description = "Override entrypoint"
  type        = list(string)
  default     = []
}

variable "user" {
  description = "Container user"
  type        = string
  default     = ""
}

# -------------------------------------------------------------------------------
# Templates & Files
#
# Files are loaded from: <job_dir>/files/<filename>
# The Makefile passes job_dir automatically.
# -------------------------------------------------------------------------------

variable "job_dir" {
  description = "Path to job directory (set by Makefile)"
  type        = string
  default     = ""
}

variable "templates" {
  description = "Template files: [{ src = 'config.yml', dest = '/etc/app/config.yml', env = false, change_mode = 'restart' }]"
  type        = list(map(string))
  default     = []
}

# -------------------------------------------------------------------------------
# Vault Integration
# -------------------------------------------------------------------------------

variable "vault" {
  description = "Enable Vault workload identity"
  type        = bool
  default     = false
}

variable "vault_role" {
  description = "Vault role name"
  type        = string
  default     = "nomad-workloads"
}

# -------------------------------------------------------------------------------
# Service Discovery & Ingress
# -------------------------------------------------------------------------------

variable "traefik" {
  description = "Enable Traefik routing"
  type        = bool
  default     = false
}

variable "traefik_host" {
  description = "Traefik hostname (default: <name>.munchbox)"
  type        = string
  default     = ""
}

variable "traefik_public" {
  description = "Skip LAN-only middleware (for public routes)"
  type        = bool
  default     = false
}

variable "health_path" {
  description = "HTTP health check path (empty to disable)"
  type        = string
  default     = "/"
}

variable "health_type" {
  description = "Health check type: 'http', 'tcp', or 'none'"
  type        = string
  default     = "http"
}

variable "tags" {
  description = "Additional Consul service tags"
  type        = list(string)
  default     = []
}

variable "register_service" {
  description = "Register with Consul"
  type        = bool
  default     = true
}

# -------------------------------------------------------------------------------
# Advanced / Docker Config
# -------------------------------------------------------------------------------

variable "privileged" {
  description = "Run privileged container"
  type        = bool
  default     = false
}

variable "devices" {
  description = "Device mappings: [{ host = '/dev/dri', container = '/dev/dri' }]"
  type        = list(map(string))
  default     = []
}

variable "cap_add" {
  description = "Linux capabilities to add"
  type        = list(string)
  default     = []
}

variable "docker_extra" {
  description = "Additional Docker config (merged)"
  type        = map(string)
  default     = {}
}

variable "image_pull_timeout" {
  description = "Image pull timeout"
  type        = string
  default     = "10m"
}

# -------------------------------------------------------------------------------
# Raw Exec (for non-Docker tasks)
# -------------------------------------------------------------------------------

variable "driver" {
  description = "Task driver: 'docker' or 'raw_exec'"
  type        = string
  default     = "docker"
}

variable "command" {
  description = "Command for raw_exec"
  type        = string
  default     = ""
}

# -------------------------------------------------------------------------------
# Lifecycle
# -------------------------------------------------------------------------------

variable "kill_timeout" {
  description = "Graceful shutdown timeout"
  type        = string
  default     = "30s"
}

variable "kill_signal" {
  description = "Shutdown signal"
  type        = string
  default     = "SIGTERM"
}
