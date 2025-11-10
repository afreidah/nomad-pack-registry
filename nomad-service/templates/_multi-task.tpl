# -------------------------------------------------------------------------------
# Project: Nomad Job Template
# Author: Alex Freidah
# -------------------------------------------------------------------------------
# Multi-Task Configuration
#
# Template for jobs with multiple tasks (prestart hooks, sidecars, etc).
# Supports lifecycle management and per-task resource allocation.
# -------------------------------------------------------------------------------

[[- define "multi_task" -]]

# -----------------------------------------------------------------------
# Load and Resolve Configuration (needed for helper template)
# -----------------------------------------------------------------------

[[- $tier := var "resource_tier" . ]]
[[- $resource_tiers := var "resource_tiers" . ]]
[[- $resources := index $resource_tiers $tier ]]

# -----------------------------------------------------------------------
# Multi-Task Definition
# -----------------------------------------------------------------------

[[- if var "tasks" . ]]
[[- range var "tasks" . ]]
task "[[ .name ]]" {

  driver = "[[ .driver ]]"

  [[- if .user ]]
  user = "[[ .user ]]"
  [[- end ]]

  # -----------------------------------------------------------------------
  # Lifecycle Hook (for prestart/poststart/sidecar tasks)
  # -----------------------------------------------------------------------

  [[- if .lifecycle ]]
  lifecycle {
    hook    = "[[ .lifecycle.hook ]]"
    sidecar = [[ .lifecycle.sidecar | default false ]]
  }
  [[- end ]]

  # -----------------------------------------------------------------------
  # Workload Identity and Secrets
  # -----------------------------------------------------------------------

  [[- if .identity ]]
  # --- Custom identity configuration ---
  identity {
    env  = [[ .identity.env | default true ]]
    file = [[ .identity.file | default false ]]
    [[- if .identity.aud ]]
    aud  = [[ .identity.aud | toJson ]]
    [[- end ]]
  }
  [[- else if var "vault" . ]]
  [[- if index (var "vault" .) "enabled" ]]
  # --- Default identity for Vault integration ---
  identity {
    env  = true
    file = false
  }
  [[- end ]]
  [[- end ]]

  # -----------------------------------------------------------------------
  # Driver Configuration - Docker
  # -----------------------------------------------------------------------

  [[- if eq .driver "docker" ]]
  config {
    image = "[[ .config.image ]]"

    [[- if .config.command ]]
    command = "[[ .config.command ]]"
    [[- end ]]

    [[- if .config.args ]]
    args = [[ .config.args | toJson ]]
    [[- end ]]

    [[- if .config.ports ]]
    ports = [[ .config.ports | toJson ]]
    [[- end ]]

    # --- Container runtime options ---
    [[- if .config.image_pull_timeout ]]
    image_pull_timeout = "[[ .config.image_pull_timeout ]]"
    [[- end ]]

    [[- if .config.network_mode ]]
    network_mode = "[[ .config.network_mode ]]"
    [[- end ]]

    # --- DNS configuration ---
    [[- if .config.dns_servers ]]
    dns_servers = [[ .config.dns_servers | toJson ]]
    [[- end ]]

    [[- if .config.dns_search_domains ]]
    dns_search_domains = [[ .config.dns_search_domains | toJson ]]
    [[- end ]]

    [[- if .config.dns_options ]]
    dns_options = [[ .config.dns_options | toJson ]]
    [[- end ]]

    # --- Volume configuration ---
    [[- if .config.volumes ]]
    volumes = [[ .config.volumes | toJson ]]
    [[- end ]]
  }
  [[- end ]]

  # -----------------------------------------------------------------------
  # Driver Configuration - Exec
  # -----------------------------------------------------------------------

  [[- if eq .driver "exec" ]]
  config {
    command = "[[ .config.command ]]"
    [[- if .config.args ]]
    args = [[ .config.args | toJson ]]
    [[- end ]]
  }
  [[- end ]]

  # -----------------------------------------------------------------------
  # Volume Mount
  # -----------------------------------------------------------------------

  [[- if .volume_mount ]]
  # --- Task-specific volume mount ---
  volume_mount {
    volume      = "[[ .volume_mount.volume ]]"
    destination = "[[ .volume_mount.destination ]]"
    read_only   = [[ .volume_mount.read_only | default false ]]
  }
  [[- else if var "volume" . ]]
  # --- Shared volume mount from group ---
  volume_mount {
    volume      = "[[ (var "volume" .).name ]]"
    destination = "[[ (var "volume" .).mount_path ]]"
    read_only   = [[ (var "volume" .).read_only | default false ]]
  }
  [[- end ]]

  # -----------------------------------------------------------------------
  # Runtime Environment
  # -----------------------------------------------------------------------

  [[- if .env ]]
  # --- Non-secret environment variables ---
  env {
    [[- range $key, $value := .env | default dict ]]
    [[ $key ]] = "[[ $value ]]"
    [[- end ]]
  }
  [[- end ]]

  # --- Custom templates ---
  [[- range .templates | default list ]]
  template {
    destination = "[[ .destination ]]"
    [[- if .env ]]
    env         = [[ .env ]]
    [[- end ]]
    [[- if .perms ]]
    perms       = "[[ .perms ]]"
    [[- end ]]
    [[- if .change_mode ]]
    change_mode = "[[ .change_mode ]]"
    [[- end ]]
    [[- if .data ]]
    data = <<-EOT
[[ .data ]]
    EOT
    [[- end ]]
  }
  [[- end ]]
  [[- end ]]

  # -----------------------------------------------------------------------
  # Service Registration
  # -----------------------------------------------------------------------

  [[- if .service ]]
  service {
    name     = "[[ .service.name | default (var "job_name" .) ]]"
    [[- if .service.port ]]
    port     = "[[ .service.port ]]"
    [[- end ]]
    provider = "[[ .service.provider | default "consul" ]]"

    # --- Service tags ---
    tags = [
      [[- range .service.tags | default list ]]
      "[[ . ]]",
      [[- end ]]
    ]

    # --- Health checks ---
    [[- range .service.checks | default list ]]
    check {
      name     = "[[ .name ]]"
      type     = "[[ .type ]]"
      [[- if .port ]]
      port     = "[[ .port ]]"
      [[- end ]]
      [[- if eq .type "http" ]]
      path     = "[[ .path ]]"
      [[- end ]]
      interval = "[[ .interval | default "10s" ]]"
      timeout  = "[[ .timeout | default "2s" ]]"
    }
    [[- end ]]
  }
  [[- end ]]

  # -----------------------------------------------------------------------
  # Resource Allocation (from resource tier or custom)
  # -----------------------------------------------------------------------

  [[- if .resources ]]
  [[- if .resources.tier ]]
  # --- Using named resource tier ---
  [[- $task_tier := index $resource_tiers .resources.tier ]]
  resources {
    cpu        = [[ $task_tier.cpu ]]
    memory     = [[ $task_tier.memory ]]
    memory_max = [[ $task_tier.memory ]]
  }
  [[- else ]]
  # --- Custom resource allocation ---
  resources {
    cpu        = [[ .resources.cpu | default $resources.cpu ]]
    memory     = [[ .resources.memory | default $resources.memory ]]
    [[- if .resources.memory_max ]]
    memory_max = [[ .resources.memory_max ]]
    [[- else ]]
    memory_max = [[ $resources.memory ]]
    [[- end ]]
  }
  [[- end ]]
  [[- else ]]
  # --- Default resource allocation from job tier ---
  resources {
    cpu        = [[ $resources.cpu ]]
    memory     = [[ $resources.memory ]]
    memory_max = [[ $resources.memory ]]
  }
  [[- end ]]

  # -----------------------------------------------------------------------
  # Termination Configuration
  # -----------------------------------------------------------------------

  [[- if .kill_timeout ]]
  kill_timeout = "[[ .kill_timeout ]]"
  [[- end ]]

  # --- Task restart behavior ---
  [[- if .restart ]]
  restart {
    attempts = [[ .restart.attempts ]]
    interval = "[[ .restart.interval ]]"
    delay    = "[[ .restart.delay ]]"
    mode     = "[[ .restart.mode ]]"
  }
  [[- end ]]
}
[[- end ]]

[[- end -]]
