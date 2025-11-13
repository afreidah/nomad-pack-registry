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
  [[- if var "deployment_profile" . ]]
  # --- Job update strategy ---
  update {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
    auto_promote      = true
    stagger           = "30s"
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

      [[- if eq (index $task "driver") "docker" ]]
      # --- Docker image configuration ---
      [[- $cfg := (index $task "config") ]]
      config {
        image = "[[ index $cfg "image" ]]"

        [[- if eq $network_preset "host" ]]
        network_mode = "host"
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
      }
      [[- end ]]

      [[- if and $ef_enabled (gt (len $ext) 0) ]]
      # --- External configuration templates ---
      [[- range $ext ]]
      template {
        destination     = "[[ .destination ]]"
        change_mode     = "[[ .change_mode ]]"
        [[- if .left_delimiter ]]
        left_delimiter  = "[[ .left_delimiter ]]"
        [[- end ]]
        [[- if .right_delimiter ]]
        right_delimiter = "[[ .right_delimiter ]]"
        [[- end ]]

        [[- if .source_file ]]
        data = <<-YAML
[[ fileContents (printf "%s/%s" $ef_base .source_file) ]]
YAML
        [[- else if .data ]]
        data = <<-EOF
[[ .data ]]
EOF
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
      [[- if var "standard_http_check_enabled" . ]]
      service {
        name     = "[[ var "standard_service_name" . ]]"
        port     = "[[ var "standard_http_check_port" . ]]"
        provider = "consul"
        tags     = [[ var "service_tags" . | toJson ]]

        check {
          name     = "[[ var "job_name" . ]]-ready"
          type     = "http"
          path     = "[[ var "standard_http_check_path" . ]]"
          interval = "10s"
          timeout  = "3s"
        }
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
