job "[[ var "job_name" . ]]" {
  region      = "[[ var "region" . ]]"
  datacenters = [[ var "datacenters" . | toJson ]]
  type        = "system"
  node_pool   = "[[ var "node_pool" . ]]"

  meta {
    managed_by = "nomad-pack"
    project    = "munchbox"
    tier       = "monitoring"
    version    = "[[ var "exporter_version" . ]]"
  }

  group "prometheus_node_exporter" {
    network {
      mode = "host"
      port "http" {
        static = [[ var "http_port" . ]]
      }
    }

    restart {
      attempts = 10
      interval = "5m"
      delay    = "5s"
      mode     = "delay"
    }

    update {
      max_parallel     = 2
      min_healthy_time = "10s"
      healthy_deadline = "2m"
      auto_revert      = true
    }

    task "prometheus_node_exporter" {
      driver = "docker"

      config {
        image        = "quay.io/prometheus/node-exporter:v[[ var "exporter_version" . ]]"
        network_mode = "host"
        pid_mode     = "host"
        args = [
          "--path.rootfs=/host",
          "--web.listen-address=0.0.0.0:[[ var "http_port" . ]]",
          "--web.telemetry-path=/metrics",
          "--collector.processes",
          "--no-collector.wifi",
          "--no-collector.hwmon",
          "--collector.filesystem.fs-types-exclude=^(autofs|binfmt_misc|bpf|cgroup2?|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|iso9660|mqueue|nsfs|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|selinuxfs|squashfs|sysfs|tracefs|fuse\\.sshfs|tmpfs)$$",
          "--collector.filesystem.mount-points-exclude=^/(dev|proc|sys|var/lib/docker/.+|run/.+|mnt/gdrive)($$|/)"
        ]
        volumes = [
          "/:/host:ro,rslave"
        ]
      }

      service {
        name         = "prometheus-node-exporter"
        port         = "http"
        provider     = "consul"
        address_mode = "host"
        tags = [
          "monitoring",
          "node-exporter",
          "metrics",
          "system"
        ]

        check {
          name     = "node-exporter-alive"
          type     = "http"
          method   = "GET"
          path     = "/metrics"
          port     = "http"
          interval = "15s"
          timeout  = "3s"
          check_restart {
            limit = 3
            grace = "10s"
          }
        }

        check {
          name     = "node-exporter-metrics"
          type     = "http"
          method   = "GET"
          path     = "/metrics"
          port     = "http"
          interval = "60s"
          timeout  = "5s"
          header {
            Accept = ["text/plain"]
          }
        }
      }

      env {
        TZ                               = "America/Los_Angeles"
        NODE_EXPORTER_WEB_TELEMETRY_PATH = "/metrics"
      }

      resources {
        cpu    = [[ var "cpu" . ]]
        memory = [[ var "memory" . ]]
      }

      kill_timeout = "30s"
      kill_signal  = "SIGTERM"
    }
  }
}
