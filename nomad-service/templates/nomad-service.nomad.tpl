# packs/registry/nomad-service/templates/nomad-service.nomad.tpl
# -------------------------------------------------------------------------------
# Service Deployment — [[ or .job_description "Managed service deployment" ]]
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

job "[[ var "job_name" . ]]" {
  type        = "[[ var "job_type" . ]]"
  datacenters = [[ var "datacenters" . | toJson ]]
  namespace   = "[[ var "namespace" . ]]"
  [[- if var "node_pool" . ]]
  node_pool   = "[[ var "node_pool" . ]]"
  [[- end ]]
  [[- if var "priority" . ]]
  priority    = [[ var "priority" . ]]
  [[- end ]]

  [[- if var "meta" . ]]
  # --- Job metadata ---
  meta {
    [[- range $key, $value := (var "meta" . | default dict) ]]
    [[ $key ]] = "[[ $value ]]"
    [[- end ]]
  }
  [[- end ]]

  [[- if eq (var "job_type" .) "service" ]]
  [[- $deployment_profile := (var "deployment_profile" .) ]]
  [[- $deployment_profiles := (var "deployment_profiles" . | default dict) ]]
  [[- if and $deployment_profile (index $deployment_profiles $deployment_profile) ]]
  [[- $profile := index $deployment_profiles $deployment_profile ]]
  # --- Job update strategy ---
  update {
    max_parallel      = [[ $profile.max_parallel | default 1 ]]
    [[- if $profile.canary ]]
    canary            = [[ $profile.canary ]]
    [[- end ]]
    health_check      = "[[ $profile.health_check | default "checks" ]]"
    min_healthy_time  = "[[ $profile.min_healthy_time | default "30s" ]]"
    healthy_deadline  = "[[ $profile.healthy_deadline | default "5m" ]]"
    progress_deadline = "[[ $profile.progress_deadline | default "10m" ]]"
    auto_revert       = [[ $profile.auto_revert | default true ]]
    [[- if $profile.auto_promote ]]
    auto_promote      = [[ $profile.auto_promote ]]
    [[- end ]]
    [[- if $profile.stagger ]]
    stagger           = "[[ $profile.stagger ]]"
    [[- end ]]
  }
  [[- end ]]
  [[- else if eq (var "job_type" .) "system" ]]
  # --- Job update strategy ---
  update {
    max_parallel     = 1
    min_healthy_time = "10s"
    healthy_deadline = "3m"
    auto_revert      = true
    stagger          = "30s"
  }
  [[- end ]]

  # ---------------------------------------------------------------------------
  #  Group
  # ---------------------------------------------------------------------------

  group "[[ var "job_name" . ]]" {
    [[- if eq (var "job_type" .) "service" ]]
    count = [[ var "count" . | default 1 ]]
    [[- end ]]

    [[- if var "constraints" . ]]
    # --- Placement constraints ---
    [[- range var "constraints" . ]]
    constraint {
      [[- if .attribute ]]
      attribute = "[[ .attribute ]]"
      [[- end ]]
      [[- if .operator ]]
      operator  = "[[ .operator ]]"
      [[- end ]]
      [[- if .value ]]
      value     = "[[ .value ]]"
      [[- end ]]
      [[- if .version ]]
      version   = "[[ .version ]]"
      [[- end ]]
      [[- if .regexp ]]
      regexp    = "[[ .regexp ]]"
      [[- end ]]
    }
    [[- end ]]
    [[- end ]]

    # --- Network configuration ---
    [[- $network_preset := (var "network_preset" .) ]]
    [[- $ports          := (var "ports" . | default list) ]]
    [[- $dns_servers    := (var "dns_servers" . | default list) ]]

    network {
      [[- if eq $network_preset "host" ]]
      mode = "host"
      [[- else ]]
      mode = "[[ $network_preset ]]"
      [[- end ]]

      [[- range $ports ]]
      port "[[ .name ]]" {
        [[- if .static ]]
        static = [[ .static ]]
        [[- else if .to ]]
        to = [[ .to ]]
        [[- end ]]
      }
      [[- end ]]

      [[- if and (ne $network_preset "host") (gt (len $dns_servers) 0) ]]
      dns {
        servers = [[ $dns_servers | toJson ]]
      }
      [[- end ]]
    }

    [[- $vol := var "volume" . ]]
    [[- if and $vol (index $vol "name") ]]
    # --- Persistent storage volume ---
    volume "[[ index $vol "name" ]]" {
      type      = "[[ index $vol "type" ]]"
      source    = "[[ index $vol "source" ]]"
      read_only = [[ index $vol "read_only" | default false ]]
    }
    [[- end ]]

    [[- if var "restart_attempts" . ]]
    # --- Task restart behavior ---
    restart {
      attempts = [[ var "restart_attempts" . ]]
      interval = "[[ var "restart_interval" . ]]"
      delay    = "[[ var "restart_delay" . ]]"
      mode     = "[[ var "restart_mode" . ]]"
    }
    [[- end ]]

    [[- $reschedule_preset  := (var "reschedule_preset" .) ]]
    [[- $reschedule_presets := (var "reschedule_presets" . | default dict) ]]
    [[- if and $reschedule_preset (index $reschedule_presets $reschedule_preset) (eq (var "job_type" .) "service") ]]
    [[- $reschedule := index $reschedule_presets $reschedule_preset ]]
    # --- Reschedule policy ---
    reschedule {
      attempts       = [[ $reschedule.max_reschedules ]]
      interval       = "2m"
      delay          = "[[ $reschedule.delay ]]"
      delay_function = "[[ $reschedule.delay_function ]]"
      unlimited      = [[ $reschedule.unlimited ]]
    }
    [[- end ]]

    # ---------------------- Resolve vars for v2 parser ----------------------
    [[- $task    := (var "task" .) ]]
    [[- $ext     := (var "external_templates" . | default list) ]]
    [[- $ef      := (var "external_files" .     | default dict) ]]
    [[- $ef_enabled := (index $ef "enabled" | default false) ]]
    [[- $ef_base := (index $ef "base_path"  | default "") ]]

    # -----------------------------------------------------------------------
    #  Task
    # -----------------------------------------------------------------------

    task "[[ index $task "name" ]]" {
      driver = "[[ index $task "driver" ]]"

      [[- if (index $task "user") ]]
      user = "[[ index $task "user" ]]"
      [[- end ]]

      [[- if ne (var "vault_role" .) "" ]]
      # --- Workload identity ---
      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      # --- Vault integration ---
      vault {
        role = "[[ var "vault_role" . ]]"
      }
      [[- end ]]

      [[- if eq (index $task "driver") "docker" ]]
      # --- Docker image configuration ---
      [[- $cfg := (index $task "config") ]]
      config {
        image = "[[ index $cfg "image" ]]"

        [[- if (index $cfg "image_pull_timeout") ]]
        image_pull_timeout = "[[ index $cfg "image_pull_timeout" ]]"
        [[- end ]]

        [[- if eq $network_preset "host" ]]
        network_mode = "host"
        [[- end ]]

        [[- if (index $cfg "pid_mode") ]]
        pid_mode = "[[ index $cfg "pid_mode" ]]"
        [[- end ]]

        [[- if (index $cfg "ports") ]]
        ports = [[ (index $cfg "ports") | toJson ]]
        [[- end ]]

        [[- if (gt (len $dns_servers) 0) ]]
        dns_servers = [[ $dns_servers | toJson ]]
        [[- end ]]

        [[- if (index $cfg "dns_search_domains") ]]
        dns_search_domains = [[ (index $cfg "dns_search_domains") | toJson ]]
        [[- end ]]

        [[- if (index $cfg "dns_options") ]]
        dns_options = [[ (index $cfg "dns_options") | toJson ]]
        [[- end ]]

        [[- if (index $cfg "args") ]]
        args = [[ (index $cfg "args") | toJson ]]
        [[- end ]]

        [[- if (index $cfg "entrypoint") ]]
        entrypoint = [[ (index $cfg "entrypoint") | toJson ]]
        [[- end ]]

        [[- if (index $cfg "volumes") ]]
        volumes = [[ (index $cfg "volumes") | toJson ]]
        [[- end ]]

        [[- if (index $cfg "command") ]]
        command = "[[ index $cfg "command" ]]"
        [[- end ]]

        [[- if (index $cfg "privileged") ]]
        privileged = [[ index $cfg "privileged" ]]
        [[- end ]]

        [[- if (index $cfg "cap_add") ]]
        cap_add = [[ (index $cfg "cap_add") | toJson ]]
        [[- end ]]

        [[- if (index $cfg "devices") ]]
        devices = [[ (index $cfg "devices") | toJson ]]
        [[- end ]]

        [[- if (index $cfg "extra_hosts") ]]
        extra_hosts = [[ (index $cfg "extra_hosts") | toJson ]]
        [[- end ]]
      }
      [[- else if or (eq (index $task "driver") "raw_exec") (eq (index $task "driver") "exec") ]]
      # --- Exec/Raw_exec configuration ---
      [[- $cfg := (index $task "config") ]]
      config {
        [[- if (index $cfg "command") ]]
        command = "[[ index $cfg "command" ]]"
        [[- end ]]
        [[- if (index $cfg "args") ]]
        args = [[ (index $cfg "args") | toJson ]]
        [[- end ]]
      }
      [[- end ]]

      [[- $vol := var "volume" . ]]
      [[- if and $vol (index $vol "name") ]]
      # --- Volume mount ---
      volume_mount {
        volume      = "[[ index $vol "name" ]]"
        destination = "[[ index $vol "mount_path" ]]"
        read_only   = [[ index $vol "read_only" | default false ]]
      }
      [[- end ]]

      [[- if and $ef_enabled (gt (len $ext) 0) ]]
      # --- External configuration templates ---
      [[- range $ext ]]
      template {
        destination     = "[[ .destination ]]"
        [[- if .env ]]
        env             = [[ .env ]]
        [[- end ]]
        [[- if .perms ]]
        perms           = "[[ .perms ]]"
        [[- end ]]
        change_mode     = "[[ .change_mode ]]"
        [[- if .change_signal ]]
        change_signal   = "[[ .change_signal ]]"
        [[- end ]]
        [[- if .left_delimiter ]]
        left_delimiter  = "[[ .left_delimiter ]]"
        [[- end ]]
        [[- if .right_delimiter ]]
        right_delimiter = "[[ .right_delimiter ]]"
        [[- end ]]

        [[- if .source_file ]]
        data = <<-EOT
[[ fileContents (printf "%s/%s" $ef_base .source_file) ]]
EOT
        [[- else if .data ]]
        data = <<-EOT
[[ .data ]]
EOT
        [[- end ]]
      }
      [[- end ]]
      [[- end ]]

      # --- Runtime environment ---
      [[- if (index $task "env") ]]
      [[- $tenv := (index $task "env") ]]
      env {
        [[- range $key, $value := $tenv ]]
        [[ $key ]] = "[[ $value ]]"
        [[- end ]]
        [[- if var "use_node_hostname" . ]]
        HOSTNAME = "${node.unique.name}"
        [[- end ]]
      }
      [[- else if var "use_node_hostname" . ]]
      env {
        HOSTNAME = "${node.unique.name}"
      }
      [[- end ]]

      # --- Service registration ---
      [[- if var "standard_service_enabled" . ]]
      # --- Standard service with automatic Traefik configuration ---
      service {
        name     = "[[ var "job_name" . ]]"
        port     = "[[ var "standard_service_port" . ]]"
        provider = "consul"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.[[ var "job_name" . ]].rule=Host(`[[ var "job_name" . ]].munchbox`)",
          "traefik.http.routers.[[ var "job_name" . ]].entrypoints=websecure",
          "traefik.http.routers.[[ var "job_name" . ]].tls=true",
          "traefik.http.routers.[[ var "job_name" . ]].middlewares=dashboard-allowlan@file",
          "traefik.http.services.[[ var "job_name" . ]].loadbalancer.server.port=[[ var "standard_service_port_number" . ]]",
          [[- range var "additional_tags" . | default list ]]
          "[[ . ]]",
          [[- end ]]
        ]

        [[- if var "standard_http_check_enabled" . ]]
        check {
          name     = "[[ var "job_name" . ]]-ready"
          type     = "http"
          path     = "[[ var "standard_http_check_path" . | default "/" ]]"
          interval = "10s"
          timeout  = "3s"
        }
        [[- end ]]
      }
      [[- else if (index $task "services") ]]
      # --- Multiple services ---
      [[- range (index $task "services") ]]
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
      [[- else if (index $task "service") ]]
      # --- Single service ---
      [[- $svc := (index $task "service") ]]
      service {
        name     = "[[ index $svc "name" ]]"
        [[- if index $svc "port" ]]
        port     = "[[ index $svc "port" ]]"
        [[- end ]]
        provider = "[[ index $svc "provider" | default "consul" ]]"
        tags     = [[ index $svc "tags" | default list | toJson ]]

        [[- range index $svc "checks" | default list ]]
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

      # --- Resource allocation ---
      [[- $resource_tiers := (var "resource_tiers" . | default dict) ]]
      [[- if (index $task "resources") ]]
      [[- $tres := (index $task "resources") ]]
      [[- if (index $tres "tier") ]]
      [[- $tier := index $resource_tiers (index $tres "tier") ]]
      resources {
        cpu    = [[ $tier.cpu ]]
        memory = [[ $tier.memory ]]
      }
      [[- else ]]
      resources {
        cpu    = [[ (index $tres "cpu" | default 100) ]]
        memory = [[ (index $tres "memory" | default 128) ]]
      }
      [[- end ]]
      [[- else ]]
      resources {
        cpu    = 100
        memory = 128
      }
      [[- end ]]

      # --- Termination configuration ---
      [[- if var "kill_timeout" . ]]
      kill_timeout = "[[ var "kill_timeout" . ]]"
      [[- end ]]
      [[- if var "kill_signal" . ]]
      kill_signal  = "[[ var "kill_signal" . ]]"
      [[- end ]]
    }
  }
}
