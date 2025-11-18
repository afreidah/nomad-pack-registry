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
    # Consul Connect Service Registration (Group Level)
    #
    # This section wires service registration and, when enabled, Consul Connect.
    # Traefik routing defaults are applied based on consul_connect_enabled and
    # standard_service_enabled:
    #
    # - Connect + standard service:
    #     - Main service: classification tags only (mesh identity).
    #     - Sidecar service: Traefik routing tags (edge entrypoint).
    #
    # - Non-Connect + standard service:
    #     - Main service: Traefik routing tags and classification tags.
    #
    # Additional tags are always appended from additional_tags.
    # -----------------------------------------------------------------------

    [[- if var "consul_connect_enabled" . ]]
    [[- if var "standard_service_enabled" . ]]
    # --- Connect service with standard configuration ---
    service {
      name         = "[[ var "job_name" . ]]"
      port         = "[[ var "standard_service_port" . ]]"
      address_mode = "alloc"
      provider     = "consul"
      tags = [
        # Classification tags only; Traefik tags go on the sidecar.
        [[- range var "additional_tags" . ]]
        "[[ . ]]",
        [[- end ]]
      ]

      connect {
        sidecar_service {
          [[- if var "traefik_enabled" . ]]
          # --- Traefik routing via sidecar service (edge entrypoint) ---
          tags = [
            "traefik.enable=true",
            "traefik.http.routers.[[ var "job_name" . ]].rule=Host(`[[ default (printf "%s.munchbox" (var "job_name" .)) (var "traefik_host" .) ]]`)",
            "traefik.http.routers.[[ var "job_name" . ]].entrypoints=[[ var "traefik_entrypoints" . ]]",
            [[- if var "traefik_tls_enabled" . ]]
            "traefik.http.routers.[[ var "job_name" . ]].tls=true",
            [[- end ]]
            "traefik.http.routers.[[ var "job_name" . ]].middlewares=[[ var "traefik_middlewares" . ]]",
            "traefik.http.services.[[ var "job_name" . ]].loadbalancer.server.port=[[ var "standard_service_port_number" . ]]",
            [[- range var "additional_tags" . ]]
            "[[ . ]]",
            [[- end ]]
          ]
          [[- else ]]
          # --- Traefik explicitly disabled for this sidecar ---
          tags = [
            "traefik.enable=false",
            [[- range var "additional_tags" . ]]
            "[[ . ]]",
            [[- end ]]
          ]
          [[- end ]]

          proxy {
            [[- range var "connect_upstreams" . ]]
            upstreams {
              destination_name = "[[ .destination_name ]]"
              local_bind_port  = [[ .local_bind_port ]]
            }
            [[- end ]]
          }
        }

        sidecar_task {
          resources {
            cpu    = [[ index (var "connect_sidecar_resources" .) "cpu" | default 200 ]]
            memory = [[ index (var "connect_sidecar_resources" .) "memory" | default 128 ]]
          }
        }
      }

      [[- if var "standard_http_check_enabled" . ]]
      check {
        name         = "[[ var "job_name" . ]]-ready"
        type         = "http"
        port         = "[[ var "standard_service_port" . ]]"
        path         = "[[ var "standard_http_check_path" . ]]"
        address_mode = "alloc"
        interval     = "10s"
        timeout      = "3s"
      }
      [[- end ]]
    }

    [[- else ]]
    # --- Connect service with custom configuration ---
    [[- $task := var "task" . ]]
    [[- $svc := index $task "service" ]]

    service {
      name         = "[[ index $svc "name" ]]"
      [[- if index $svc "port" ]]
      port         = "[[ index $svc "port" ]]"
      [[- end ]]
      address_mode = "alloc"
      provider     = "[[ index $svc "provider" | default "consul" ]]"
      tags         = [[ index $svc "tags" | default (list) | toJson ]]

      connect {
        sidecar_service {
          [[- $sidecar := index $svc "sidecar_service" | default dict ]]
          tags = [[ index $sidecar "tags" | default (list) | toJson ]]

          proxy {
            [[- range var "connect_upstreams" . ]]
            upstreams {
              destination_name = "[[ .destination_name ]]"
              local_bind_port  = [[ .local_bind_port ]]
            }
            [[- end ]]
          }
        }

        sidecar_task {
          resources {
            cpu    = [[ index (var "connect_sidecar_resources" .) "cpu" | default 200 ]]
            memory = [[ index (var "connect_sidecar_resources" .) "memory" | default 128 ]]
          }
        }
      }

      [[- if var "standard_http_check_enabled" . ]]
      check {
        name         = "[[ var "job_name" . ]]-ready"
        type         = "http"
        port         = "[[ var "standard_service_port" . ]]"
        path         = "[[ var "standard_http_check_path" . ]]"
        address_mode = "alloc"
        interval     = "10s"
        timeout      = "3s"
      }
      [[- end ]]
    }
    [[- end ]]

    [[- else ]]
    [[- if var "standard_service_enabled" . ]]
    # --- Non-Connect standard service (Traefik on main service) ---
    service {
      name     = "[[ var "job_name" . ]]"
      port     = "[[ var "standard_service_port" . ]]"
      provider = "consul"

      [[- if var "traefik_enabled" . ]]
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.[[ var "job_name" . ]].rule=Host(`[[ default (printf "%s.munchbox" (var "job_name" .)) (var "traefik_host" .) ]]`)",
        "traefik.http.routers.[[ var "job_name" . ]].entrypoints=[[ var "traefik_entrypoints" . ]]",
        [[- if var "traefik_tls_enabled" . ]]
        "traefik.http.routers.[[ var "job_name" . ]].tls=true",
        [[- end ]]
        "traefik.http.routers.[[ var "job_name" . ]].middlewares=[[ var "traefik_middlewares" . ]]",
        "traefik.http.services.[[ var "job_name" . ]].loadbalancer.server.port=[[ var "standard_service_port_number" . ]]",
        [[- range var "additional_tags" . ]]
        "[[ . ]]",
        [[- end ]]
      ]
      [[- else ]]
      tags = [
        "traefik.enable=false",
        [[- range var "additional_tags" . ]]
        "[[ . ]]",
        [[- end ]]
      ]
      [[- end ]]

      [[- if var "standard_http_check_enabled" . ]]
      check {
        name         = "[[ var "job_name" . ]]-ready"
        type         = "http"
        port         = "[[ var "standard_service_port" . ]]"
        path         = "[[ var "standard_http_check_path" . ]]"
        address_mode = "alloc"
        interval     = "10s"
        timeout      = "3s"
      }
      [[- end ]]
    }
    [[- end ]]
    [[- end ]]

    # -----------------------------------------------------------------------
    # Main Task Definition
    #
    # Single primary task for this group. Task configuration is provided via
    # the "task" variable map to allow reuse across jobs and environments.
    # -----------------------------------------------------------------------

    [[- $task := var "task" . ]]

    task "[[ index $task "name" ]]" {
      driver = "[[ index $task "driver" ]]"

      # --- Task user (optional) ---
      [[- if index $task "user" ]]
      user = "[[ index $task "user" ]]"
      [[- end ]]

      # --- Task config map ---
      [[- if index $task "config" ]]
      config {
        [[- range $k, $v := index $task "config" ]]
        [[ $k ]] = [[ $v | toJson ]]
        [[- end ]]
      }
      [[- end ]]

      # --- Environment variables ---
      [[- if index $task "env" ]]
      env {
        [[- range $k, $v := index $task "env" ]]
        [[ $k ]] = "[[ $v ]]"
        [[- end ]]
      }
      [[- end ]]

      # --- Resources ---
      [[- $explicit := var "resources" . ]]
      [[- if gt (len $explicit) 0 ]]
      # Use explicit resources when provided
      resources {
        [[- if index $explicit "cpu" ]]
        cpu    = [[ index $explicit "cpu" ]]
        [[- end ]]
        [[- if index $explicit "memory" ]]
        memory = [[ index $explicit "memory" ]]
        [[- end ]]
        [[- if index $explicit "memory_max" ]]
        memory_max = [[ index $explicit "memory_max" ]]
        [[- end ]]
      }
      [[- else ]]
      # Fallback to resource_tier definition when explicit resources are not set
      [[- $tiers := var "resource_tiers" . ]]
      [[- $tier_name := var "resource_tier" . ]]
      [[- $res := index $tiers $tier_name ]]
      resources {
        [[- if index $res "cpu" ]]
        cpu    = [[ index $res "cpu" ]]
        [[- end ]]
        [[- if index $res "memory" ]]
        memory = [[ index $res "memory" ]]
        [[- end ]]
        # memory_max omitted by default when using tiers
      }
      [[- end ]]

      # --- Templates (optional) ---
      [[- if index $task "templates" ]]
      [[- range index $task "templates" ]]
      template {
        [[- range $k, $v := . ]]
        [[ $k ]] = [[ $v | toJson ]]
        [[- end ]]
      }
      [[- end ]]
      [[- end ]]

      # --- Vault configuration (optional) ---
      [[- if index $task "vault" ]]
      vault {
        [[- range $k, $v := index $task "vault" ]]
        [[ $k ]] = [[ $v | toJson ]]
        [[- end ]]
      }
      [[- end ]]
    }
  }
}

