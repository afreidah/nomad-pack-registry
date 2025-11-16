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
  priority    = [[ var "priority" . ]]

  # -------------------------------------------------------------------------------
  # Job Metadata
  #
  # Tags and categorization for monitoring, organization, and filtering. Uses
  # meta_profile to pull tier designation from predefined profiles.
  # -------------------------------------------------------------------------------

  # --- Resolve meta profile to get tier designation ---
  [[- $meta_profile := var "meta_profile" . ]]
  [[- $meta := index (var "meta_profiles" .) $meta_profile ]]

  meta {
    managed_by = "nomad-pack"
    project    = "munchbox"
    tier       = "[[ $meta.tier ]]"
    [[- if var "category" . ]]
    category   = "[[ var "category" . ]]"
    [[- end ]]
  }

  # -------------------------------------------------------------------------------
  # Update Strategy
  #
  # Controls how Nomad deploys updates to running allocations. Service jobs use
  # deployment profiles (standard, canary, rolling) while system jobs use simple
  # rolling updates with stagger.
  # -------------------------------------------------------------------------------

  [[- if eq (var "job_type" .) "service" ]]
  # -----------------------------------------------------------------------
  # Service Job Deployment Profile
  # -----------------------------------------------------------------------

  [[- $profile := index (var "deployment_profiles" .) (var "deployment_profile" .) ]]

  update {
    max_parallel      = [[ $profile.max_parallel ]]
    [[- if gt $profile.canary 0 ]]
    canary            = [[ $profile.canary ]]
    auto_promote      = [[ $profile.auto_promote ]]
    [[- end ]]
    health_check      = "[[ $profile.health_check ]]"
    min_healthy_time  = "[[ $profile.min_healthy_time ]]"
    healthy_deadline  = "[[ $profile.healthy_deadline ]]"
    progress_deadline = "[[ $profile.progress_deadline ]]"
    auto_revert       = [[ $profile.auto_revert ]]
  }

  [[- else if eq (var "job_type" .) "system" ]]
  # -----------------------------------------------------------------------
  # System Job Rolling Update
  # -----------------------------------------------------------------------

  update {
    max_parallel     = 1
    min_healthy_time = "10s"
    healthy_deadline = "3m"
    auto_revert      = true
    stagger          = "30s"
  }
  [[- end ]]

  # -------------------------------------------------------------------------------
  # Task Group
  #
  # Defines the collection of tasks that run together on the same node. Includes
  # placement constraints, networking, volumes, and restart/reschedule policies.
  # -------------------------------------------------------------------------------

  group "[[ var "job_name" . ]]" {
    [[- if eq (var "job_type" .) "service" ]]
    count = [[ var "count" . ]]
    [[- end ]]

    # -----------------------------------------------------------------------
    # Placement Constraints
    # -----------------------------------------------------------------------

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
    # Network Configuration
    # -----------------------------------------------------------------------

    network {
      [[- if eq (var "network_preset" .) "host" ]]
      mode = "host"
      [[- else ]]
      mode = "[[ var "network_preset" . ]]"
      [[- end ]]

      # --- Port definitions ---
      [[- range var "ports" . ]]
      port "[[ .name ]]" {
        [[- if .static ]]
        static = [[ .static ]]
        [[- else if .to ]]
        to = [[ .to ]]
        [[- end ]]
      }
      [[- end ]]

      # --- DNS configuration for non-host networking ---
      [[- $dns := var "dns_servers" . ]]
      [[- if and (ne (var "network_preset" .) "host") (gt (len $dns) 0) ]]
      dns {
        servers = [[ $dns | toJson ]]
        [[- if var "dns_searches" . ]]
        searches = [[ var "dns_searches" . | toJson ]]
        [[- end ]]
        [[- if var "dns_options" . ]]
        options  = [[ var "dns_options" . | toJson ]]
        [[- end ]]
      }
      [[- end ]]
    }

    # -----------------------------------------------------------------------
    # Persistent Storage
    # -----------------------------------------------------------------------

    [[- $vol := var "volume" . ]]
    [[- if and $vol (index $vol "name") ]]
    volume "[[ index $vol "name" ]]" {
      type      = "[[ index $vol "type" ]]"
      source    = "[[ index $vol "source" ]]"
      read_only = [[ index $vol "read_only" | default false ]]
    }
    [[- end ]]

    # -----------------------------------------------------------------------
    # Restart Policy
    # -----------------------------------------------------------------------

    restart {
      attempts = [[ var "restart_attempts" . ]]
      interval = "[[ var "restart_interval" . ]]"
      delay    = "[[ var "restart_delay" . ]]"
      mode     = "[[ var "restart_mode" . ]]"
    }

    # -----------------------------------------------------------------------
    # Reschedule Policy
    # -----------------------------------------------------------------------

    [[- if eq (var "job_type" .) "service" ]]
    [[- $reschedule := index (var "reschedule_presets" .) (var "reschedule_preset" .) ]]

    reschedule {
      attempts       = [[ $reschedule.max_reschedules ]]
      interval       = "[[ $reschedule.interval ]]"
      delay          = "[[ $reschedule.delay ]]"
      delay_function = "[[ $reschedule.delay_function ]]"
      unlimited      = [[ $reschedule.unlimited ]]
    }
    [[- end ]]

    # -------------------------------------------------------------------------------
    # Task Definition
    #
    # The main workload specification including driver configuration, secrets,
    # runtime environment, service registration, and resource allocation.
    # -------------------------------------------------------------------------------

    [[- $task := var "task" . ]]

    task "[[ index $task "name" ]]" {
      driver = "[[ index $task "driver" ]]"

      [[- if index $task "user" ]]
      user = "[[ index $task "user" ]]"
      [[- end ]]

      # -----------------------------------------------------------------------
      # Vault Integration
      # -----------------------------------------------------------------------

      [[- if ne (var "vault_role" .) "" ]]
      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      vault {
        role = "[[ var "vault_role" . ]]"
      }
      [[- end ]]

      # -----------------------------------------------------------------------
      # Driver Configuration
      # -----------------------------------------------------------------------

      [[- $cfg := index $task "config" ]]

      [[- if eq (index $task "driver") "docker" ]]
      config {
        image = "[[ index $cfg "image" ]]"

        # --- Image pull settings ---
        [[- if index $cfg "image_pull_timeout" ]]
        image_pull_timeout = "[[ index $cfg "image_pull_timeout" ]]"
        [[- end ]]
        [[- if index $cfg "force_pull" ]]
        force_pull = [[ index $cfg "force_pull" ]]
        [[- end ]]

        # --- Network mode (inherit from group or override) ---
        [[- if eq (var "network_preset" .) "host" ]]
        network_mode = "host"
        [[- else if index $cfg "network_mode" ]]
        network_mode = "[[ index $cfg "network_mode" ]]"
        [[- end ]]

        # --- Process isolation ---
        [[- if index $cfg "pid_mode" ]]
        pid_mode = "[[ index $cfg "pid_mode" ]]"
        [[- end ]]

        # --- Port mappings ---
        [[- if index $cfg "ports" ]]
        ports = [[ index $cfg "ports" | toJson ]]
        [[- end ]]

        # --- Container startup customization ---
        [[- if index $cfg "entrypoint" ]]
        entrypoint = [[ index $cfg "entrypoint" | toJson ]]
        [[- end ]]
        [[- if index $cfg "command" ]]
        command = "[[ index $cfg "command" ]]"
        [[- end ]]
        [[- if index $cfg "args" ]]
        args = [[ index $cfg "args" | toJson ]]
        [[- end ]]

        # --- Security and capabilities ---
        [[- if index $cfg "privileged" ]]
        privileged = [[ index $cfg "privileged" ]]
        [[- end ]]
        [[- if index $cfg "cap_add" ]]
        cap_add = [[ index $cfg "cap_add" | toJson ]]
        [[- end ]]

        # --- Device access (GPU, hardware transcoding, etc.) ---
        [[- if index $cfg "devices" ]]
        devices = [[ index $cfg "devices" | toJson ]]
        [[- end ]]

        # --- Volume mounts ---
        [[- if index $cfg "volumes" ]]
        volumes = [[ index $cfg "volumes" | toJson ]]
        [[- end ]]

        # --- Host resolution overrides ---
        [[- if index $cfg "extra_hosts" ]]
        extra_hosts = [[ index $cfg "extra_hosts" | toJson ]]
        [[- end ]]

        # --- DNS configuration ---
        [[- $dns := var "dns_servers" . ]]
        [[- if gt (len $dns) 0 ]]
        dns_servers = [[ $dns | toJson ]]
        [[- end ]]
        [[- if index $cfg "dns_search_domains" ]]
        dns_search_domains = [[ index $cfg "dns_search_domains" | toJson ]]
        [[- end ]]
        [[- if index $cfg "dns_options" ]]
        dns_options = [[ index $cfg "dns_options" | toJson ]]
        [[- end ]]
      }

      [[- else if or (eq (index $task "driver") "raw_exec") (eq (index $task "driver") "exec") ]]
      config {
        [[- if index $cfg "command" ]]
        command = "[[ index $cfg "command" ]]"
        [[- end ]]
        [[- if index $cfg "args" ]]
        args = [[ index $cfg "args" | toJson ]]
        [[- end ]]
      }
      [[- end ]]

      # -----------------------------------------------------------------------
      # Volume Mount
      # -----------------------------------------------------------------------

      [[- $vol := var "volume" . ]]
      [[- if and $vol (index $vol "name") ]]
      volume_mount {
        volume      = "[[ index $vol "name" ]]"
        destination = "[[ index $vol "mount_path" ]]"
        read_only   = [[ index $vol "read_only" | default false ]]
      }
      [[- end ]]

      # -----------------------------------------------------------------------
      # External Configuration Templates
      # -----------------------------------------------------------------------

      [[- $ef := var "external_files" . ]]
      [[- if and $ef (index $ef "enabled") ]]
      [[- $base := index $ef "base_path" ]]

      [[- range var "external_templates" . ]]
      template {
        destination = "[[ .destination ]]"

        # --- Template behavior settings ---
        [[- if .env ]]
        env         = [[ .env ]]
        [[- end ]]
        [[- if .perms ]]
        perms       = "[[ .perms ]]"
        [[- end ]]
        change_mode = "[[ .change_mode | default "restart" ]]"
        [[- if .change_signal ]]
        change_signal = "[[ .change_signal ]]"
        [[- end ]]

        # --- Custom delimiters for Consul template syntax ---
        [[- if .left_delimiter ]]
        left_delimiter  = "[[ .left_delimiter ]]"
        [[- end ]]
        [[- if .right_delimiter ]]
        right_delimiter = "[[ .right_delimiter ]]"
        [[- end ]]

        data = <<-EOT
[[ fileContents (printf "%s/%s" $base .source_file) ]]
EOT
      }
      [[- end ]]
      [[- end ]]

      # -----------------------------------------------------------------------
      # Runtime Environment
      # -----------------------------------------------------------------------

      [[- if or (index $task "env") (var "use_node_hostname" .) ]]
      env {
        [[- range $key, $value := (index $task "env" | default dict) ]]
        [[ $key ]] = "[[ $value ]]"
        [[- end ]]
        [[- if var "use_node_hostname" . ]]
        HOSTNAME = "${node.unique.name}"
        [[- end ]]
      }
      [[- end ]]

      # -----------------------------------------------------------------------
      # Service Registration
      # -----------------------------------------------------------------------

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
          [[- range var "additional_tags" . ]]
          "[[ . ]]",
          [[- end ]]
        ]

        [[- if var "standard_http_check_enabled" . ]]
        check {
          name     = "[[ var "job_name" . ]]-ready"
          type     = "http"
          path     = "[[ var "standard_http_check_path" . ]]"
          interval = "10s"
          timeout  = "3s"
        }
        [[- end ]]
      }

      [[- else if index $task "services" ]]
      # --- Multiple custom services ---
      [[- range index $task "services" ]]
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

      [[- else if index $task "service" ]]
      # --- Single custom service ---
      [[- $svc := index $task "service" ]]
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

      # -----------------------------------------------------------------------
      # Resource Allocation
      # -----------------------------------------------------------------------

      [[- $tres := index $task "resources" | default dict ]]

      [[- if index $tres "tier" ]]
      # --- Named resource tier ---
      [[- $tier := index (var "resource_tiers" .) (index $tres "tier") ]]
      resources {
        cpu    = [[ $tier.cpu ]]
        memory = [[ $tier.memory ]]
      }

      [[- else if index $tres "cpu" ]]
      # --- Direct resource specification ---
      resources {
        cpu    = [[ index $tres "cpu" ]]
        memory = [[ index $tres "memory" ]]
      }

      [[- else ]]
      # --- Job-level resource tier ---
      [[- $tier := index (var "resource_tiers" .) (var "resource_tier" .) ]]
      resources {
        cpu    = [[ $tier.cpu ]]
        memory = [[ $tier.memory ]]
      }
      [[- end ]]

      # -----------------------------------------------------------------------
      # Termination Behavior
      # -----------------------------------------------------------------------

      [[- if var "kill_timeout" . ]]
      kill_timeout = "[[ var "kill_timeout" . ]]"
      [[- end ]]
      [[- if var "kill_signal" . ]]
      kill_signal  = "[[ var "kill_signal" . ]]"
      [[- end ]]
    }
  }
}
