# -------------------------------------------------------------------------------
# Task Group Configuration
#
# Defines task group-level settings including networking, storage, placement
# constraints, and restart/reschedule policies. These apply to all tasks in
# the group.
# -------------------------------------------------------------------------------

group "[[ var "group_name" . | default (var "job_name" .) ]]" {

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
    [[- range var "ports" . ]]
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
      servers  = [[ var "dns_servers" . | default (list "172.17.0.1") | toJson ]]
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

  [[- range $constraints ]]
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

  # --- Additional custom constraints ---
  [[- range var "constraints" . ]]
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
  # --- Persistent volume ---
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

  [[- if var "ephemeral_disk" . ]]
  # --- Ephemeral disk ---
  ephemeral_disk {
    size    = [[ (var "ephemeral_disk" .).size ]]
    migrate = [[ (var "ephemeral_disk" .).migrate | default false ]]
    sticky  = [[ (var "ephemeral_disk" .).sticky | default false ]]
  }
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

  reschedule {
    attempts       = [[ $reschedule.max_reschedules ]]
    interval       = "[[ $reschedule.delay ]]"
    delay          = "[[ $reschedule.delay ]]"
    delay_function = "[[ $reschedule.delay_function ]]"
    unlimited      = [[ $reschedule.unlimited ]]
  }
