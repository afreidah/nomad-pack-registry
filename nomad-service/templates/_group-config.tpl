# -------------------------------------------------------------------------------
# Project: Nomad Job Template
# Author: Alex Freidah
# -------------------------------------------------------------------------------
# Task Group Configuration
# -------------------------------------------------------------------------------

[[- define "group_config" -]]

# -----------------------------------------------------------------------
# Load and Resolve Configuration (needed for helper template)
# -----------------------------------------------------------------------

[[- $tier := var "resource_tier" . ]]
[[- $resource_tiers := var "resource_tiers" . ]]
[[- $resources := index $resource_tiers $tier ]]

[[- $network_preset := var "network_preset" . ]]
[[- $network_presets := var "network_presets" . ]]
[[- $network := index $network_presets $network_preset ]]

[[- $reschedule_preset := var "reschedule_preset" . ]]
[[- $reschedule_presets := var "reschedule_presets" . ]]
[[- $reschedule := index $reschedule_presets $reschedule_preset ]]

# --- Component pointer (advisory, no mutation) ---
[[- $component_key := var "component" . ]]
[[- $component_registry := var "component_registry" . ]]
[[- $c := index $component_registry $component_key ]]

# --- Environment overlay pointer (advisory, no mutation) ---
[[- $env_key := var "environment" . ]]
[[- $env_defaults := var "env_defaults" . ]]
[[- $ed := index $env_defaults $env_key ]]

# --- Effective ports (prefer var "ports", else component ports, else empty) ---
[[- $ports := (var "ports" .) ]]
[[- if and (not $ports) $c $c.ports ]]
[[- $ports = $c.ports ]]
[[- end ]]

# --- Effective DNS (prefer var dns_servers, else env overlay, else default) ---
[[- $dns := (var "dns_servers" . | default (list "192.168.68.62" "192.168.68.64")) ]]
[[- if and (not (var "dns_servers" .)) $ed $ed.dns_servers ]]
[[- $dns = $ed.dns_servers ]]
[[- end ]]

# -----------------------------------------------------------------------
# Task Group Definition
# -----------------------------------------------------------------------

group "[[ var "group_name" . | default (var "job_name" . | default (var "component" .)) ]]" {

  count = [[ var "count" . | default 1 ]]

  # -----------------------------------------------------------------------
  # Network Configuration (from network preset)
  # -----------------------------------------------------------------------

  network {
    mode = "[[ $network.mode ]]"

    [[- if var "network_hostname" . ]]
    hostname = "[[ var "network_hostname" . ]]"
    [[- end ]]

    # --- Port definitions ---
    [[- range $ports | default list ]]
    port "[[ .name ]]" {
      [[- if .static ]]
      static = [[ .static ]]
      [[- end ]]
      [[- if .port ]]
      to = [[ .port ]]
      [[- end ]]
      [[- if .host_network ]]
      host_network = "[[ .host_network ]]"
      [[- end ]]
    }
    [[- end ]]

    # --- DNS configuration ---
    dns {
      servers = [[ $dns | toJson ]]
      [[- if var "dns_searches" . ]]
      searches = [[ var "dns_searches" . | toJson ]]
      [[- end ]]
      [[- if var "dns_options" . ]]
      options  = [[ var "dns_options" . | toJson ]]
      [[- end ]]
    }
  }

  # -----------------------------------------------------------------------
  # Placement Constraints (from constraint preset)
  # -----------------------------------------------------------------------

  [[- if var "constraint_preset" . ]]
  [[- $constraint_presets := var "constraint_presets" . ]]
  [[- $constraint_preset := var "constraint_preset" . ]]
  [[- range index $constraint_presets $constraint_preset | default list ]]
  constraint {
    attribute = "[[ .attribute ]]"
    [[- if .operator ]]
    operator  = "[[ .operator ]]"
    [[- end ]]
    [[- if .value ]]
    value     = "[[ .value ]]"
    [[- end ]]
  }
  [[- end ]]
  [[- end ]]

  # --- Additional custom constraints ---
  [[- range var "constraints" . | default list ]]
  constraint {
    attribute = "[[ .attribute ]]"
    [[- if .operator ]]
    operator  = "[[ .operator ]]"
    [[- end ]]
    [[- if .value ]]
    value     = "[[ .value ]]"
    [[- end ]]
  }
  [[- end ]]

  # -----------------------------------------------------------------------
  # Storage Configuration
  # -----------------------------------------------------------------------

  [[- if var "volume" . ]]
  [[- if (var "volume" .).name ]]
  volume "[[ (var "volume" .).name ]]" {
    type      = "[[ (var "volume" .).type ]]"
    source    = "[[ (var "volume" .).source ]]"
    read_only = [[ (var "volume" .).read_only | default false ]]
    [[- if eq (var "volume" .).type "csi" ]]
    attachment_mode = "[[ (var "volume" .).attachment_mode | default "file-system" ]]"
    access_mode     = "[[ (var "volume" .).access_mode | default "single-node-writer" ]]"
    [[- end ]]
  }
  [[- end ]]
  [[- end ]]

  [[- if var "ephemeral_disk" . ]]
  [[- if (var "ephemeral_disk" .).size ]]
  ephemeral_disk {
    size    = [[ (var "ephemeral_disk" .).size ]]
    migrate = [[ (var "ephemeral_disk" .).migrate | default false ]]
    sticky  = [[ (var "ephemeral_disk" .).sticky | default false ]]
  }
  [[- end ]]
  [[- end ]]

  # -----------------------------------------------------------------------
  # Restart Behavior
  # -----------------------------------------------------------------------

  restart {
    attempts = [[ var "restart_attempts" . ]]
    interval = "[[ var "restart_interval" . ]]"
    delay    = "[[ var "restart_delay" . ]]"
    mode     = "[[ var "restart_mode" . ]]"
  }

  # -----------------------------------------------------------------------
  # Reschedule Policy (from reschedule preset)
  # -----------------------------------------------------------------------

  [[- if ne (var "job_type" .) "system" ]]
  reschedule {
    attempts       = [[ $reschedule.max_reschedules ]]
    interval       = "2m"
    delay          = "[[ $reschedule.delay ]]"
    delay_function = "[[ $reschedule.delay_function ]]"
    unlimited      = [[ $reschedule.unlimited ]]
  }
  [[- end ]]

[[- end -]]
