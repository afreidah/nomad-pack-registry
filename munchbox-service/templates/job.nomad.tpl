# -------------------------------------------------------------------------------
# [[ var "name" . ]] — Munchbox Deployment
#
# Project: Munchbox / Author: Alex Freidah
# -------------------------------------------------------------------------------

[[- $name := var "name" . ]]
[[- $port := var "port" . ]]
[[- $port_name := var "port_name" . ]]
[[- $host_network := var "host_network" . ]]
[[- $static_port := var "static_port" . ]]
[[- $job_type := var "type" . ]]
[[- $node := var "node" . ]]
[[- $storage := var "storage" . ]]
[[- $storage_path := var "storage_path" . ]]
[[- $storage_subdir := var "storage_subdir" . ]]
[[- if eq $storage_subdir "" ]][[ $storage_subdir = $name ]][[ end ]]

[[- /* Resource size presets */ -]]
[[- $sizes := dict "tiny" (dict "cpu" 100 "memory" 128) "small" (dict "cpu" 200 "memory" 256) "medium" (dict "cpu" 500 "memory" 512) "large" (dict "cpu" 1000 "memory" 1024) "xlarge" (dict "cpu" 2000 "memory" 2048) ]]
[[- $size_preset := index $sizes (var "size" .) ]]
[[- $cpu := var "cpu" . ]]
[[- $memory := var "memory" . ]]
[[- if eq $cpu 0 ]][[ $cpu = index $size_preset "cpu" ]][[ end ]]
[[- if eq $memory 0 ]][[ $memory = index $size_preset "memory" ]][[ end ]]

[[- /* Storage paths */ -]]
[[- $nfs_server := "192.168.68.63" ]]
[[- $nfs_base := "/mnt/gdrive/nomad-data" ]]
[[- $local_base := "/opt/nomad/data" ]]

job "[[ $name ]]" {
  region      = "global"
  datacenters = ["munchbox"]
  type        = "[[ $job_type ]]"
  node_pool   = "all"
  priority    = [[ var "priority" . ]]

  # ---------------------------------------------------------------------------
  # Metadata
  # ---------------------------------------------------------------------------

  meta {
    managed_by = "nomad-pack"
    project    = "munchbox"
  }

  # ---------------------------------------------------------------------------
  # Update Strategy
  # ---------------------------------------------------------------------------

  [[- if eq $job_type "service" ]]
  update {
    max_parallel      = 1
    canary            = 1
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
    auto_promote      = true
  }
  [[- else if eq $job_type "system" ]]
  update {
    max_parallel     = 1
    min_healthy_time = "10s"
    healthy_deadline = "3m"
    auto_revert      = true
    stagger          = "30s"
  }
  [[- end ]]

  # ---------------------------------------------------------------------------
  # Placement
  # ---------------------------------------------------------------------------

  [[- if ne $node "any" ]]
  constraint {
    attribute = "${node.unique.name}"
    operator  = "="
    value     = "[[ $node ]]"
  }
  [[- end ]]

  # ---------------------------------------------------------------------------
  # Task Group: [[ $name ]]
  # ---------------------------------------------------------------------------

  group "[[ $name ]]" {
    [[- if eq $job_type "service" ]]
    count = [[ var "count" . ]]
    [[- end ]]

    # --- Network Configuration ---
    network {
      [[- if or $host_network (gt $static_port 0) ]]
      mode = "host"
      [[- else ]]
      mode = "bridge"
      [[- end ]]

      [[- if gt $port 0 ]]
      port "[[ $port_name ]]" {
        [[- if gt $static_port 0 ]]
        static = [[ $static_port ]]
        [[- else if or $host_network (gt $static_port 0) ]]
        static = [[ $port ]]
        [[- else ]]
        to = [[ $port ]]
        [[- end ]]
      }
      [[- end ]]

      [[- range var "extra_ports" . ]]
      port "[[ .name ]]" {
        [[- if .static ]]
        static = [[ .port ]]
        [[- else ]]
        to = [[ .port ]]
        [[- end ]]
      }
      [[- end ]]

      [[- if and (not $host_network) (eq $static_port 0) ]]
      dns {
        servers = [[ var "dns" . | toJson ]]
      }
      [[- end ]]
    }

    # --- Restart Policy ---
    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    [[- if eq $job_type "service" ]]
    # --- Reschedule Policy ---
    reschedule {
      attempts       = 3
      interval       = "30m"
      delay          = "5s"
      delay_function = "exponential"
      max_delay      = "1m"
      unlimited      = false
    }
    [[- end ]]

    # --- Service Registration ---
    [[- if and (var "register_service" .) (gt $port 0) ]]
    service {
      name     = "[[ $name ]]"
      port     = "[[ $port_name ]]"
      provider = "consul"

      tags = [
        [[- if var "traefik" . ]]
        "traefik.enable=true",
        [[- $host := var "traefik_host" . ]]
        [[- if eq $host "" ]][[ $host = printf "%s.munchbox" $name ]][[ end ]]
        "traefik.http.routers.[[ $name ]].rule=Host(`[[ $host ]]`)",
        "traefik.http.routers.[[ $name ]].entrypoints=websecure",
        "traefik.http.routers.[[ $name ]].tls=true",
        [[- if not (var "traefik_public" .) ]]
        "traefik.http.routers.[[ $name ]].middlewares=dashboard-allowlan@file",
        [[- end ]]
        [[- if or $host_network (gt $static_port 0) ]]
        "traefik.http.services.[[ $name ]].loadbalancer.server.port=[[ $port ]]",
        [[- end ]]
        [[- else ]]
        "traefik.enable=false",
        [[- end ]]
        [[- range var "tags" . ]]
        "[[ . ]]",
        [[- end ]]
      ]

      [[- if and (ne (var "health_type" .) "none") (ne (var "health_path" .) "") ]]
      check {
        name     = "[[ $name ]]-health"
        type     = "[[ var "health_type" . ]]"
        [[- if eq (var "health_type" .) "http" ]]
        path     = "[[ var "health_path" . ]]"
        [[- end ]]
        port     = "[[ $port_name ]]"
        interval = "[[ var "health_interval" . ]]"
        timeout  = "[[ var "health_timeout" . ]]"
      }
      [[- end ]]
    }
    [[- end ]]

    [[- /* ===================================================================
           LOCAL STORAGE: Prestart task to create directory
           =================================================================== */ -]]
    [[- if eq $storage "local" ]]

    # -------------------------------------------------------------------------
    # Init Task: Create local storage directory
    # -------------------------------------------------------------------------

    task "init-storage" {
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      driver = "docker"

      config {
        image   = "busybox:latest"
        command = "sh"
        args    = ["-c", "mkdir -p /init-data && chown -R [[ var "storage_owner" . ]] /init-data && chmod 755 /init-data"]
        volumes = [
          "[[ $local_base ]]/[[ $storage_subdir ]]:/init-data"
        ]
      }

      resources {
        cpu    = 50
        memory = 32
      }
    }
    [[- end ]]

    # -------------------------------------------------------------------------
    # Task: [[ $name ]]
    # -------------------------------------------------------------------------

    task "[[ $name ]]" {
      driver = "[[ var "driver" . ]]"

      [[- if ne (var "user" .) "" ]]
      user = "[[ var "user" . ]]"
      [[- end ]]

      [[- /* Vault Integration */ -]]
      [[- if var "vault" . ]]
      vault {
        role = "[[ var "vault_role" . ]]"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }
      [[- end ]]

      [[- /* Docker Driver Config */ -]]
      [[- if eq (var "driver" .) "docker" ]]
      config {
        image              = "[[ var "image" . ]]"
        image_pull_timeout = "[[ var "image_pull_timeout" . ]]"
        [[- if gt $port 0 ]]
        ports              = ["[[ $port_name ]]"[[- range var "extra_ports" . ]], "[[ .name ]]"[[- end ]]]
        [[- end ]]
        [[- if or $host_network (gt $static_port 0) ]]
        network_mode       = "host"
        [[- end ]]

        [[- if gt (len (var "args" .)) 0 ]]
        args = [[ var "args" . | toJson ]]
        [[- end ]]

        [[- if gt (len (var "entrypoint" .)) 0 ]]
        entrypoint = [[ var "entrypoint" . | toJson ]]
        [[- end ]]

        [[- if var "privileged" . ]]
        privileged = true
        [[- end ]]

        [[- if gt (len (var "cap_add" .)) 0 ]]
        cap_add = [[ var "cap_add" . | toJson ]]
        [[- end ]]

        [[- if gt (len (var "devices" .)) 0 ]]
        devices = [
          [[- range var "devices" . ]]
          {
            host_path          = "[[ .host ]]"
            container_path     = "[[ .container ]]"
            cgroup_permissions = "rwm"
          },
          [[- end ]]
        ]
        [[- end ]]

        [[- /* ===============================================================
               STORAGE MOUNTS
               =============================================================== */ -]]
        [[- $all_volumes := var "volumes" . ]]

        [[- /* Local storage: simple bind mount */ -]]
        [[- if eq $storage "local" ]]
        [[- $all_volumes = append $all_volumes (printf "%s/%s:%s" $local_base $storage_subdir $storage_path) ]]
        [[- end ]]

        [[- /* Template file volumes - mount from local/ or secrets/ */ -]]
        [[- range var "templates" . ]]
        [[- if not .env ]]
        [[- $src_dir := "local" ]]
        [[- $filename := .src ]]
        [[- if .vault ]]
        [[- $src_dir = "secrets" ]]
        [[- $filename = trimSuffix ".tpl" .src ]]
        [[- end ]]
        [[- $all_volumes = append $all_volumes (printf "%s/%s:%s:ro" $src_dir $filename .dest) ]]
        [[- end ]]
        [[- end ]]

        [[- if gt (len $all_volumes) 0 ]]
        volumes = [[ $all_volumes | toJson ]]
        [[- end ]]

        [[- /* Shared storage: NFS via Docker volume driver */ -]]
        [[- if eq $storage "shared" ]]
        mounts = [
          {
            type     = "volume"
            target   = "[[ $storage_path ]]"
            source   = "[[ $name ]]-data"
            volume_options = {
              driver_config = {
                name = "local"
                options = {
                  type   = "nfs"
                  o      = "addr=[[ $nfs_server ]],rw,nolock,soft,timeo=100"
                  device = ":[[ $nfs_base ]]/[[ $storage_subdir ]]"
                }
              }
            }
          }
        ]
        [[- end ]]

        [[- range $k, $v := var "docker_extra" . ]]
        [[ $k ]] = [[ $v | toJson ]]
        [[- end ]]
      }
      [[- else ]]
      [[- /* Raw Exec Driver Config */ -]]
      config {
        command = "[[ var "command" . ]]"
        [[- if gt (len (var "args" .)) 0 ]]
        args    = [[ var "args" . | toJson ]]
        [[- end ]]
      }
      [[- end ]]

      [[- /* Environment Variables */ -]]
      [[- $env := var "env" . ]]
      [[- if gt (len $env) 0 ]]
      env {
        [[- range $k, $v := $env ]]
        [[ $k ]] = "[[ $v ]]"
        [[- end ]]
      }
      [[- end ]]

      [[- /* Template Files */ -]]
      [[- $job_dir := var "job_dir" . ]]
      [[- range var "templates" . ]]
      template {
        [[- if $job_dir ]]
        data = <<EOH
[[ fileContents (printf "%s/files/%s" $job_dir .src) ]]
EOH
        [[- else ]]
        data = "# ERROR: job_dir not set - cannot load [[ .src ]]"
        [[- end ]]
        [[- if .env ]]
        destination = "secrets/[[ .src ]]"
        env         = true
        [[- else if .vault ]]
        destination = "secrets/[[ trimSuffix ".tpl" .src ]]"
        [[- else ]]
        destination = "local/[[ .src ]]"
        [[- end ]]
        [[- if .change_mode ]]
        change_mode = "[[ .change_mode ]]"
        [[- else ]]
        change_mode = "restart"
        [[- end ]]
      }
      [[- end ]]

      # --- Resources ---
      resources {
        cpu    = [[ $cpu ]]
        memory = [[ $memory ]]
        [[- if gt (var "memory_max" .) 0 ]]
        memory_max = [[ var "memory_max" . ]]
        [[- end ]]
      }

      # --- Termination ---
      kill_timeout = "[[ var "kill_timeout" . ]]"
      kill_signal  = "[[ var "kill_signal" . ]]"
    }
  }
}
