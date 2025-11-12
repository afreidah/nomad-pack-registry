# -------------------------------------------------------------------------------
# Service Deployment — [[ or .job_description "Managed service deployment" ]]
#
# Project: Munchbox / Author: Alex Freidah
#
# This template supports both 'service' and 'system' job types. System jobs run
# on all nodes matching constraints, while service jobs run with specified count.
# -------------------------------------------------------------------------------

job "[[ .job_name ]]" {
  type        = "[[ .job_type ]]"
  region      = "[[ .region ]]"
  datacenters = [[ .datacenters | toJson ]]
  namespace   = "[[ .namespace ]]"
  [[- if .node_pool ]]
  node_pool   = "[[ .node_pool ]]"
  [[- end ]]
  [[- if .priority ]]
  priority    = [[ .priority ]]
  [[- end ]]

  [[- if .meta ]]
  # --- Job metadata ---
  meta {
    [[- range $key, $value := .meta ]]
    [[ $key ]] = "[[ $value ]]"
    [[- end ]]
  }
  [[- end ]]

  [[- if eq .job_type "service" ]]
  [[- if .deployment_profile ]]
  # --- Job update strategy ---
  update {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
    auto_promote      = true
    stagger          = "30s"
  }
  [[- end ]]
  [[- else if eq .job_type "system" ]]
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
  #  [[ .job_name ]] Group
  # ---------------------------------------------------------------------------

  group "[[ .job_name ]]" {
    [[- if eq .job_type "service" ]]
    count = [[ .count ]]
    [[- end ]]

    # --- Network configuration ---
    network {
      [[- if eq .network_preset "host" ]]
      mode = "host"
      [[- else ]]
      mode = "[[ .network_preset ]]"
      [[- end ]]

      [[- range .ports ]]
      port "[[ .name ]]" {
        [[- if .static ]]
        static = [[ .static ]]
        [[- else if .to ]]
        to = [[ .to ]]
        [[- end ]]
      }
      [[- end ]]

      [[- if and (ne .network_preset "host") .dns_servers ]]
      dns {
        servers = [[ .dns_servers | toJson ]]
      }
      [[- end ]]
    }

    [[- if .restart_attempts ]]
    # --- Task restart behavior ---
    restart {
      attempts = [[ .restart_attempts ]]
      interval = "[[ .restart_interval ]]"
      delay    = "[[ .restart_delay ]]"
      mode     = "[[ .restart_mode ]]"
    }
    [[- end ]]

    [[- if and .reschedule_preset .reschedule_presets ]]
    [[- if index .reschedule_presets .reschedule_preset ]]
    [[- $reschedule := index .reschedule_presets .reschedule_preset ]]
    # --- Reschedule policy ---
    reschedule {
      attempts       = [[ $reschedule.max_reschedules ]]
      interval       = "2m"
      delay          = "[[ $reschedule.delay ]]"
      delay_function = "[[ $reschedule.delay_function ]]"
      unlimited      = [[ $reschedule.unlimited ]]
    }
    [[- end ]]
    [[- end ]]

    # -----------------------------------------------------------------------
    #  [[ .task.name ]] Task
    # -----------------------------------------------------------------------

    task "[[ .task.name ]]" {
      driver = "[[ .task.driver ]]"

      [[- if .task.user ]]
      user = "[[ .task.user ]]"
      [[- end ]]

      [[- if eq .task.driver "docker" ]]
      # --- Docker image configuration ---
      config {
        image = "[[ .task.config.image ]]"
        
        [[- if eq .network_preset "host" ]]
        network_mode = "host"
        [[- end ]]
        
        [[- if .task.config.ports ]]
        ports = [[ .task.config.ports | toJson ]]
        [[- end ]]
        
        [[- if .dns_servers ]]
        dns_servers = [[ .dns_servers | toJson ]]
        [[- end ]]
        
        [[- if .task.config.dns_search_domains ]]
        dns_search_domains = [[ .task.config.dns_search_domains | toJson ]]
        [[- end ]]
        
        [[- if .task.config.dns_options ]]
        dns_options = [[ .task.config.dns_options | toJson ]]
        [[- end ]]
        
        [[- if .task.config.args ]]
        args = [[ .task.config.args | toJson ]]
        [[- end ]]
        
        [[- if .task.config.volumes ]]
        volumes = [[ .task.config.volumes | toJson ]]
        [[- end ]]
        
        [[- if .task.config.command ]]
        command = "[[ .task.config.command ]]"
        [[- end ]]
        
        [[- if .task.config.privileged ]]
        privileged = [[ .task.config.privileged ]]
        [[- end ]]
        
        [[- if .task.config.cap_add ]]
        cap_add = [[ .task.config.cap_add | toJson ]]
        [[- end ]]
      }
      [[- end ]]

      [[- if .external_templates ]]
      # --- [[ (index .external_templates 0).destination | default "Configuration" ]] template ---
      [[- range .external_templates ]]
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
        data            = <<-YAML
<<INJECT:[[ $.external_files.base_path ]]/[[ .source_file ]]>>
YAML
        [[- else if .data ]]
        data = <<-EOF
[[ .data ]]
EOF
        [[- end ]]
      }
      [[- end ]]
      [[- end ]]

      [[- if .task.env ]]
      # --- Runtime environment ---
      env {
        [[- range $key, $value := .task.env ]]
        [[ $key ]] = "[[ $value ]]"
        [[- end ]]
        [[- if .use_node_hostname ]]
        HOSTNAME = "${node.unique.name}"
        [[- end ]]
      }
      [[- else if .use_node_hostname ]]
      # --- Runtime environment ---
      env {
        HOSTNAME = "${node.unique.name}"
      }
      [[- end ]]

      [[- if .standard_http_check_enabled ]]
      # --- Service registration ---
      service {
        name     = "[[ .standard_service_name ]]"
        port     = "[[ .standard_http_check_port ]]"
        provider = "consul"
        tags     = [[ .service_tags | toJson ]]

        check {
          name     = "[[ .job_name ]]-ready"
          type     = "http"
          path     = "[[ .standard_http_check_path ]]"
          interval = "10s"
          timeout  = "3s"
        }
      }
      [[- end ]]

      # --- Resource allocation ---
      [[- if and .task.resources .task.resources.tier .resource_tiers ]]
      [[- $tier := index .resource_tiers .task.resources.tier ]]
      resources {
        cpu    = [[ $tier.cpu ]]
        memory = [[ $tier.memory ]]
      }
      [[- else if .task.resources ]]
      resources {
        cpu    = [[ .task.resources.cpu ]]
        memory = [[ .task.resources.memory ]]
      }
      [[- else ]]
      resources {
        cpu    = 100
        memory = 128
      }
      [[- end ]]

      [[- if .kill_timeout ]]
      # --- Termination configuration ---
      kill_timeout = "[[ .kill_timeout ]]"
      [[- end ]]
      [[- if .kill_signal ]]
      kill_signal  = "[[ .kill_signal ]]"
      [[- end ]]
    }
  }
}
