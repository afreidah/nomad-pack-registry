# -------------------------------------------------------------------------------
# Project: Nomad Job Template
# Author: Alex Freidah
# -------------------------------------------------------------------------------
# Single Task Configuration
#
# Template for jobs with a single main task. Includes driver configuration,
# workload identity, Traefik integration, service registration, and resource
# allocation.
# -------------------------------------------------------------------------------

[[- define "single_task" -]]

# -----------------------------------------------------------------------
# Load and Resolve Configuration (needed for helper template)
# -----------------------------------------------------------------------

[[- $tier := var "resource_tier" . ]]
[[- $resource_tiers := var "resource_tiers" . ]]
[[- $resources := index $resource_tiers $tier ]]

# -----------------------------------------------------------------------
# Single Task Definition
# -----------------------------------------------------------------------

task "[[ (var "task" .).name ]]" {

  driver = "[[ (var "task" .).driver ]]"

  [[- if (var "task" .).user ]]
  user = "[[ (var "task" .).user ]]"
  [[- end ]]

  # -----------------------------------------------------------------------
  # Workload Identity and Secrets
  # -----------------------------------------------------------------------

  [[- if (var "task" .).identity ]]
  # --- Custom identity configuration ---
  identity {
    env  = [[ (var "task" .).identity.env | default true ]]
    file = [[ (var "task" .).identity.file | default false ]]
    [[- if (var "task" .).identity.aud ]]
    aud  = [[ (var "task" .).identity.aud | toJson ]]
    [[- end ]]
    [[- if (var "task" .).identity.ttl ]]
    ttl  = "[[ (var "task" .).identity.ttl ]]"
    [[- end ]]
  }
  [[- else if var "vault" . ]]
  [[- if index (var "vault" .) "enabled" ]]
  # --- Default identity for Vault integration ---
  identity {
    env  = true
    file = false
    [[- if index (var "vault" .) "aud" ]]
    aud  = [[ index (var "vault" .) "aud" | toJson ]]
    [[- end ]]
  }
  [[- end ]]
  [[- end ]]

  # -----------------------------------------------------------------------
  # Driver Configuration - Docker
  # -----------------------------------------------------------------------

  [[- if eq (var "task" .).driver "docker" ]]
  config {
    image = "[[ (var "task" .).config.image ]]"

    [[- if (var "task" .).config.command ]]
    command = "[[ (var "task" .).config.command ]]"
    [[- end ]]

    [[- if (var "task" .).config.args ]]
    args = [[ (var "task" .).config.args | toJson ]]
    [[- end ]]

    [[- if (var "task" .).config.ports ]]
    ports = [[ (var "task" .).config.ports | toJson ]]
    [[- end ]]

    # --- Container runtime options ---
    [[- if (var "task" .).config.image_pull_timeout ]]
    image_pull_timeout = "[[ (var "task" .).config.image_pull_timeout ]]"
    [[- end ]]

    [[- if (var "task" .).config.force_pull ]]
    force_pull = [[ (var "task" .).config.force_pull ]]
    [[- end ]]

    [[- if (var "task" .).config.network_mode ]]
    network_mode = "[[ (var "task" .).config.network_mode ]]"
    [[- end ]]

    # --- DNS configuration ---
    [[- if (var "task" .).config.dns_servers ]]
    dns_servers = [[ (var "task" .).config.dns_servers | toJson ]]
    [[- end ]]

    [[- if (var "task" .).config.dns_search_domains ]]
    dns_search_domains = [[ (var "task" .).config.dns_search_domains | toJson ]]
    [[- end ]]

    [[- if (var "task" .).config.dns_options ]]
    dns_options = [[ (var "task" .).config.dns_options | toJson ]]
    [[- end ]]

    # --- Volume configuration ---
    [[- if (var "task" .).config.volumes ]]
    volumes = [[ (var "task" .).config.volumes | toJson ]]
    [[- end ]]

    # --- Traefik labels (auto-generated from traefik block) ---
    [[- if var "traefik" . ]]
    [[- if (var "traefik" .).enabled ]]
    labels {
      "traefik.enable" = "true"

      [[- if (var "traefik" .).routes ]]
      # --- Multiple routes for multi-port services ---
      [[- range (var "traefik" .).routes | default list ]]
      "traefik.http.routers.[[ .name ]].rule"        = "Host(`[[ .hostname ]].[[ (var "traefik" .).domain | default "munchbox.local" ]]`)"
      "traefik.http.routers.[[ .name ]].entrypoints" = "[[ (var "traefik" .).entrypoint | default "websecure" ]]"
      "traefik.http.routers.[[ .name ]].tls"         = "true"
      "traefik.http.services.[[ .name ]].loadbalancer.server.port" = "[[ .port ]]"
      [[- if (var "traefik" .).middlewares ]]
      "traefik.http.routers.[[ .name ]].middlewares" = "[[ join "," (var "traefik" .).middlewares ]]"
      [[- end ]]
      [[- end ]]
      [[- else ]]
      # --- Single route for simple services ---
      "traefik.http.routers.[[ var "job_name" . ]].rule"        = "Host(`[[ (var "traefik" .).hostname ]].[[ (var "traefik" .).domain | default "munchbox.local" ]]`)"
      "traefik.http.routers.[[ var "job_name" . ]].entrypoints" = "[[ (var "traefik" .).entrypoint | default "websecure" ]]"
      "traefik.http.routers.[[ var "job_name" . ]].tls"         = "true"
      "traefik.http.services.[[ var "job_name" . ]].loadbalancer.server.port" = "[[ (var "traefik" .).port ]]"
      [[- if (var "traefik" .).middlewares ]]
      "traefik.http.routers.[[ var "job_name" . ]].middlewares" = "[[ join "," (var "traefik" .).middlewares ]]"
      [[- end ]]
      [[- end ]]
    }
    [[- end ]]
    [[- end ]]
  }
  [[- end ]]

  # -----------------------------------------------------------------------
  # Driver Configuration - Exec
  # -----------------------------------------------------------------------

  [[- if eq (var "task" .).driver "exec" ]]
  config {
    command = "[[ (var "task" .).config.command ]]"
    [[- if (var "task" .).config.args ]]
    args = [[ (var "task" .).config.args | toJson ]]
    [[- end ]]
  }
  [[- end ]]

  # -----------------------------------------------------------------------
  # Volume Mount
  # -----------------------------------------------------------------------

  [[- if var "volume" . ]]
  volume_mount {
    volume      = "[[ (var "volume" .).name ]]"
    destination = "[[ (var "volume" .).mount_path ]]"
    read_only   = [[ (var "volume" .).read_only | default false ]]
  }
  [[- end ]]

  [[- range (var "task" .).volume_mounts | default list ]]
  volume_mount {
    volume      = "[[ .volume ]]"
    destination = "[[ .destination ]]"
    read_only   = [[ .read_only | default false ]]
  }
  [[- end ]]

  # -----------------------------------------------------------------------
  # Runtime Environment
  # -----------------------------------------------------------------------

  [[- if (var "task" .).env ]]
  # --- Non-secret environment variables ---
  env {
    [[- range $key, $value := (var "task" .).env | default dict ]]
    [[ $key ]] = "[[ $value ]]"
    [[- end ]]
  }
  [[- end ]]

  # --- Vault secrets template (auto-generated) ---
  [[- if var "vault" . ]]
  [[- if index (var "vault" .) "enabled" ]]
  [[- if index (var "vault" .) "secrets" ]]
  template {
    data = <<-EOT
    [[- range $key, $path := index (var "vault" .) "secrets" | default dict ]]
{{ with secret "[[ $path ]]" }}
[[ upper (replace $key "_" "") ]]="{{ .Data.data.value }}"
{{ end }}
    [[- end ]]
    EOT
    destination = "secrets/env"
    env         = true
    change_mode = "restart"
  }
  [[- end ]]
  [[- end ]]
  [[- end ]]

  # --- Additional custom templates ---
  [[- range (var "task" .).templates | default list ]]
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
    [[- if .change_signal ]]
    change_signal = "[[ .change_signal ]]"
    [[- end ]]
    [[- if .data ]]
    data = <<-EOT
[[ .data ]]
    EOT
    [[- end ]]
  }
  [[- end ]]

  # -----------------------------------------------------------------------
  # Service Registration
  # -----------------------------------------------------------------------

  [[- if (var "task" .).service ]]
  service {
    name     = "[[ (var "task" .).service.name | default (var "job_name" .) ]]"
    [[- if (var "task" .).service.port ]]
    port     = "[[ (var "task" .).service.port ]]"
    [[- end ]]
    provider = "[[ (var "task" .).service.provider | default "consul" ]]"

    # --- Tags ---
    tags = [[ (var "task" .).service.tags | default list | toJson ]]

    # --- Health checks ---
    [[- range (var "task" .).service.checks | default list ]]
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

      [[- if .check_restart ]]
      check_restart {
        limit = [[ .check_restart.limit | default 3 ]]
        grace = "[[ .check_restart.grace | default "5s" ]]"
      }
      [[- end ]]
    }
    [[- end ]]
  }
  [[- end ]]

  # -----------------------------------------------------------------------
  # Resource Allocation (from resource tier)
  # -----------------------------------------------------------------------

  [[- if (var "task" .).resources ]]
  [[- if (var "task" .).resources.tier ]]
  # --- Using named resource tier ---
  [[- $task_tier := index $resource_tiers (var "task" .).resources.tier ]]
  resources {
    cpu        = [[ $task_tier.cpu ]]
    memory     = [[ $task_tier.memory ]]
    memory_max = [[ $task_tier.memory ]]
  }
  [[- else ]]
  # --- Custom resource allocation ---
  resources {
    cpu        = [[ (var "task" .).resources.cpu | default $resources.cpu ]]
    memory     = [[ (var "task" .).resources.memory | default $resources.memory ]]
    [[- if (var "task" .).resources.memory_max ]]
    memory_max = [[ (var "task" .).resources.memory_max ]]
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

  [[- if (var "task" .).kill_timeout ]]
  kill_timeout = "[[ (var "task" .).kill_timeout ]]"
  [[- end ]]

  [[- if (var "task" .).kill_signal ]]
  kill_signal = "[[ (var "task" .).kill_signal ]]"
  [[- end ]]

  [[- if (var "task" .).shutdown_delay ]]
  shutdown_delay = "[[ (var "task" .).shutdown_delay ]]"
  [[- end ]]

  # --- Task restart behavior ---
  [[- if (var "task" .).restart ]]
  restart {
    attempts = [[ (var "task" .).restart.attempts ]]
    interval = "[[ (var "task" .).restart.interval ]]"
    delay    = "[[ (var "task" .).restart.delay ]]"
    mode     = "[[ (var "task" .).restart.mode ]]"
  }
  [[- end ]]

  # --- Log retention ---
  logs {
    max_files     = [[ var "log_max_files" . | default 10 ]]
    max_file_size = [[ var "log_max_file_size" . | default 10 ]]
  }
}

[[- end -]]
