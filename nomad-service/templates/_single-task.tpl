# -------------------------------------------------------------------------------
# Project: Nomad Job Template
# Author: Alex Freidah
# -------------------------------------------------------------------------------
# Single Task Template
#
# Template for jobs with a single main task. Includes driver configuration,
# workload identity, service registration, resource allocation, and external
# templates. Values prefer explicit pack variables and fall back to the
# component registry when present.
#
# Note:
# - Avoids undefined helpers like setvar/cond
# - Guards restart durations to prevent empty-string durations
# -------------------------------------------------------------------------------

[[- define "single_task" -]]

# -----------------------------------------------------------------------
# Resolve configurations
# -----------------------------------------------------------------------

[[- $tier := var "resource_tier" . ]]
[[- $resource_tiers := var "resource_tiers" . ]]
[[- $resources := index $resource_tiers $tier ]]

[[- $component_key := var "component" . ]]
[[- $component_registry := var "component_registry" . ]]
[[- $c := index $component_registry $component_key ]]

[[- $task := (var "task" .) ]]
[[- if and (not $task) $c $c.task ]]
[[- $task = $c.task ]]
[[- end ]]

# -----------------------------------------------------------------------
# External file / template resolution
# -----------------------------------------------------------------------

# pack-level external_files
[[- $pf := (var "external_files" .) ]]
[[- $pf_enabled := false ]]
[[- $pf_base := "" ]]
[[- if $pf ]]
[[- $pf_enabled = (index $pf "enabled" | default false) ]]
[[- $pf_base    = (index $pf "base_path" | default "") ]]
[[- end ]]

# component-level external_files
[[- $cf := (and $c $c.external_files) ]]
[[- $cf_enabled := false ]]
[[- $cf_base := "" ]]
[[- if $cf ]]
[[- $cf_enabled = (index $cf "enabled" | default false) ]]
[[- $cf_base    = (index $cf "base_path" | default "") ]]
[[- end ]]

# effective base and enable
[[- $ef_enabled := (or $pf_enabled $cf_enabled) ]]
[[- $ef_base := $pf_base ]]
[[- if and (not $pf_enabled) $cf_enabled ]]
[[- $ef_base = $cf_base ]]
[[- else ]]
[[- if and (eq $ef_base "") (ne $cf_base "") ]]
[[- $ef_base = $cf_base ]]
[[- end ]]
[[- end ]]

# effective external_templates
[[- $pt := (var "external_templates" .) ]]
[[- $ext := $pt ]]
[[- if or (not $pt) (eq (len $pt) 0) ]]
[[- if and $c $c.external_templates ]]
[[- $ext = $c.external_templates ]]
[[- else ]]
[[- $ext = list ]]
[[- end ]]
[[- end ]]

# -----------------------------------------------------------------------
# Generated HTTP check defaults
# -----------------------------------------------------------------------

[[- $std_enabled := (var "standard_http_check_enabled" .) ]]
[[- if and (not $std_enabled) $c $c.standard_http_check_enabled ]]
[[- $std_enabled = $c.standard_http_check_enabled ]]
[[- end ]]

[[- $std_port := (var "standard_http_check_port" . | default "") ]]
[[- if and (eq $std_port "") $c $c.standard_http_check_port ]]
[[- $std_port = $c.standard_http_check_port ]]
[[- end ]]
[[- if eq $std_port "" ]]
[[- $std_port = "http" ]]
[[- end ]]

[[- $std_path := (var "standard_http_check_path" . | default "") ]]
[[- if and (eq $std_path "") $c $c.standard_http_check_path ]]
[[- $std_path = $c.standard_http_check_path ]]
[[- end ]]
[[- if eq $std_path "" ]]
[[- $std_path = "/ready" ]]
[[- end ]]

[[- $std_name := (var "standard_service_name" . | default "") ]]
[[- if and (eq $std_name "") $c $c.standard_service_name ]]
[[- $std_name = $c.standard_service_name ]]
[[- end ]]
[[- if eq $std_name "" ]]
[[- $std_name = (var "job_name" . | default $component_key) ]]
[[- end ]]

# -----------------------------------------------------------------------
# Task definition
# -----------------------------------------------------------------------

task "[[ $task.name ]]" {

  driver = "[[ $task.driver ]]"

  [[- if $task.user ]]
  user = "[[ $task.user ]]"
  [[- end ]]

  # ---------------------------------------------------------------------
  # Workload identity and secrets
  # ---------------------------------------------------------------------

  [[- if $task.identity ]]
  identity {
    env  = [[ $task.identity.env | default true ]]
    file = [[ $task.identity.file | default false ]]
    [[- if $task.identity.aud ]]
    aud  = [[ $task.identity.aud | toJson ]]
    [[- end ]]
    [[- if $task.identity.ttl ]]
    ttl  = "[[ $task.identity.ttl ]]"
    [[- end ]]
  }
  [[- else if var "vault" . ]]
  [[- if index (var "vault" .) "enabled" ]]
  identity {
    env  = true
    file = false
    [[- if index (var "vault" .) "aud" ]]
    aud  = [[ index (var "vault" .) "aud" | toJson ]]
    [[- end ]]
  }
  [[- end ]]
  [[- end ]]

  # ---------------------------------------------------------------------
  # Docker configuration
  # ---------------------------------------------------------------------

  [[- if eq $task.driver "docker" ]]
  config {
    image = "[[ $task.config.image ]]"

    [[- if $task.config.entrypoint ]]
    entrypoint = [[ $task.config.entrypoint | toJson ]]
    [[- end ]]

    [[- if $task.config.command ]]
    command = "[[ $task.config.command ]]"
    [[- end ]]

    [[- if $task.config.args ]]
    args = [[ $task.config.args | toJson ]]
    [[- end ]]

    [[- if $task.config.ports ]]
    ports = [[ $task.config.ports | toJson ]]
    [[- end ]]

    [[- if $task.config.image_pull_timeout ]]
    image_pull_timeout = "[[ $task.config.image_pull_timeout ]]"
    [[- end ]]

    [[- if $task.config.force_pull ]]
    force_pull = [[ $task.config.force_pull ]]
    [[- end ]]

    [[- if $task.config.network_mode ]]
    network_mode = "[[ $task.config.network_mode ]]"
    [[- end ]]

    [[- if $task.config.cap_add ]]
    cap_add = [[ $task.config.cap_add | toJson ]]
    [[- end ]]

    [[- if $task.config.dns_servers ]]
    dns_servers = [[ $task.config.dns_servers | toJson ]]
    [[- end ]]

    [[- if $task.config.dns_search_domains ]]
    dns_search_domains = [[ $task.config.dns_search_domains | toJson ]]
    [[- end ]]

    [[- if $task.config.dns_options ]]
    dns_options = [[ $task.config.dns_options | toJson ]]
    [[- end ]]

    [[- if $task.config.volumes ]]
    volumes = [[ $task.config.volumes | toJson ]]
    [[- end ]]

    [[- if $task.config.devices ]]
    devices = [[ $task.config.devices | toJson ]]
    [[- end ]]
  }
  [[- end ]]

  # ---------------------------------------------------------------------
  # raw_exec / exec configuration
  # ---------------------------------------------------------------------

  [[- if eq $task.driver "raw_exec" ]]
  config {
    [[- if $task.config.command ]]
    command = "[[ $task.config.command ]]"
    [[- end ]]
    [[- if $task.config.args ]]
    args = [[ $task.config.args | toJson ]]
    [[- end ]]
  }
  [[- end ]]

  [[- if eq $task.driver "exec" ]]
  config {
    command = "[[ $task.config.command ]]"
    [[- if $task.config.args ]]
    args = [[ $task.config.args | toJson ]]
    [[- end ]]
  }
  [[- end ]]

  # ---------------------------------------------------------------------
  # Volume mounts
  # ---------------------------------------------------------------------

  [[- range $task.volume_mounts | default list ]]
  volume_mount {
    volume      = "[[ .volume ]]"
    destination = "[[ .destination ]]"
    read_only   = [[ .read_only | default false ]]
  }
  [[- end ]]

  # ---------------------------------------------------------------------
  # Runtime environment
  # ---------------------------------------------------------------------

  [[- if $task.env ]]
  env {
    [[- range $key, $value := $task.env ]]
    [[ $key ]] = "[[ $value ]]"
    [[- end ]]
  }
  [[- end ]]

  # ---------------------------------------------------------------------
  # Templates (inline)
  # ---------------------------------------------------------------------

  [[- range $task.templates | default list ]]
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

  # ---------------------------------------------------------------------
  # Templates (external fileContents)
  # ---------------------------------------------------------------------

  [[- if and $ef_enabled (gt (len $ext) 0) ]]
  [[- range $ext ]]
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
    [[- if .left_delimiter ]]
    left_delimiter  = "[[ .left_delimiter ]]"
    [[- end ]]
    [[- if .right_delimiter ]]
    right_delimiter = "[[ .right_delimiter ]]"
    [[- end ]]
    data = <<-EOT
[[ fileContents (printf "%s/%s" $ef_base .source_file) ]]
    EOT
  }
  [[- end ]]
  [[- end ]]

  # ---------------------------------------------------------------------
  # Service registration
  # ---------------------------------------------------------------------

  [[- if $std_enabled ]]
  service {
    name     = "[[ $std_name ]]"
    port     = "[[ $std_port ]]"
    provider = "consul"
    tags     = []

    check {
      name     = "http"
      type     = "http"
      path     = "[[ $std_path ]]"
      interval = "10s"
      timeout  = "2s"
    }
  }
  [[- else if $task.services ]]
  [[- range $task.services ]]
  service {
    name     = "[[ .name ]]"
    [[- if .port ]]
    port     = "[[ .port ]]"
    [[- end ]]
    provider = "[[ .provider | default "consul" ]]"
    tags     = [[ .tags | default list | toJson ]]

    [[- range .checks | default list ]]
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
  [[- else if $task.service ]]
  service {
    name     = "[[ $task.service.name | default (var "job_name" . | default (var "component" .)) ]]"
    [[- if $task.service.port ]]
    port     = "[[ $task.service.port ]]"
    [[- end ]]
    provider = "[[ $task.service.provider | default "consul" ]]"
    tags     = [[ $task.service.tags | default list | toJson ]]

    [[- range $task.service.checks | default list ]]
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

  # ---------------------------------------------------------------------
  # Resource allocation
  # ---------------------------------------------------------------------

  [[- if $task.resources ]]
  [[- if $task.resources.tier ]]
  [[- $t := index $resource_tiers $task.resources.tier ]]
  resources {
    cpu        = [[ $t.cpu ]]
    memory     = [[ $t.memory ]]
    memory_max = [[ $t.memory ]]
  }
  [[- else ]]
  resources {
    cpu        = [[ $task.resources.cpu | default $resources.cpu ]]
    memory     = [[ $task.resources.memory | default $resources.memory ]]
    memory_max = [[ $task.resources.memory_max | default ($task.resources.memory | default $resources.memory) ]]
  }
  [[- end ]]
  [[- else ]]
  resources {
    cpu        = [[ $resources.cpu ]]
    memory     = [[ $resources.memory ]]
    memory_max = [[ $resources.memory ]]
  }
  [[- end ]]

  # ---------------------------------------------------------------------
  # Restart policy (only emit valid values)
  # ---------------------------------------------------------------------

  [[- $r := $task.restart ]]
  [[- if and $r (or (gt ($r.attempts | default 0) 0) (ne ($r.interval | default "") "") (ne ($r.delay | default "") "") (ne ($r.mode | default "") "")) ]]
  restart {
    [[- if $r.attempts ]]
    attempts = [[ $r.attempts ]]
    [[- end ]]
    [[- if and $r (ne ($r.interval | default "") "") ]]
    interval = "[[ $r.interval ]]"
    [[- end ]]
    [[- if and $r (ne ($r.delay | default "") "") ]]
    delay    = "[[ $r.delay ]]"
    [[- end ]]
    [[- if and $r (ne ($r.mode | default "") "") ]]
    mode     = "[[ $r.mode ]]"
    [[- end ]]
  }
  [[- end ]]
}

[[- end -]]
