job "[[ var "job_name" . ]]" {
  region      = "[[ var "region" . ]]"
  datacenters = [[ var "datacenters" . | toJson ]]
  type        = "service"
  node_pool   = "[[ var "node_pool" . ]]"

  meta {
    managed_by = "nomad-pack"
    project    = "munchbox"
    tier       = "monitoring"
    version    = "[[ var "prometheus_version" . ]]"
  }

  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  group "prometheus" {
    count = 1

    constraint {
      attribute = "$${node.unique.name}"
      operator  = "="
      value     = "[[ var "constraint_node" . ]]"
    }

    volume "prometheus-data" {
      type      = "host"
      source    = "prometheus-data"
      read_only = false
    }

    network {
      mode = "host"
      port "web" {
        static = [[ var "web_port" . ]]
        to     = [[ var "web_port" . ]]
      }
    }

    restart {
      attempts = 5
      interval = "10m"
      delay    = "30s"
      mode     = "fail"
    }

    reschedule {
      attempts       = 3
      interval       = "30m"
      delay          = "5s"
      delay_function = "exponential"
      max_delay      = "1m"
      unlimited      = false
    }

    task "prometheus" {
      driver = "docker"
      user   = "root"

      vault {
        role = "nomad-workloads"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }

      config {
        image              = "prom/prometheus:v[[ var "prometheus_version" . ]]"
        network_mode       = "host"
        ports              = ["web"]
        image_pull_timeout = "10m"
        extra_hosts = [
        [[- range var "extra_hosts" . ]]
          "[[ . ]]",
        [[- end ]]
        ]
        dns_servers        = [[ var "consul_servers" . | toJson ]]
        dns_search_domains = ["service.consul"]
        dns_options        = ["timeout:2", "attempts:3", "ndots:1"]
        args = [
          "--config.file=/etc/prometheus/config/prometheus.yml",
          "--storage.tsdb.path=/opt/nomad/data/prometheus-data",
          "--web.listen-address=0.0.0.0:[[ var "web_port" . ]]",
          "--web.enable-lifecycle",
          "--web.enable-admin-api",
          "--storage.tsdb.retention.time=[[ var "retention_days" . ]]d",
          "--storage.tsdb.wal-compression",
          "--web.page-title=Munchbox Prometheus"
        ]
        volumes = [
          "local/config:/etc/prometheus/config:ro",
          "local/secrets:/etc/prometheus/secrets:ro"
        ]
      }

      volume_mount {
        volume      = "prometheus-data"
        destination = "/opt/nomad/data/prometheus-data"
        read_only   = false
      }

      service {
        name     = "prometheus"
        port     = "web"
        provider = "consul"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.prometheus.rule=Host(`prometheus.munchbox`)",
          "traefik.http.routers.prometheus.entrypoints=websecure",
          "traefik.http.routers.prometheus.tls=true",
          "traefik.http.routers.prometheus.middlewares=dashboard-allowlan@file",
          "traefik.http.services.prometheus.loadbalancer.server.port=[[ var "web_port" . ]]",
          "traefik.http.services.prometheus.loadbalancer.healthcheck.path=/-/ready",
          "traefik.http.services.prometheus.loadbalancer.healthcheck.interval=30s",
          "traefik.http.services.prometheus.loadbalancer.healthcheck.timeout=5s",
          "monitoring",
          "prometheus",
          "metrics"
        ]

        check {
          name     = "prometheus-ready"
          type     = "http"
          path     = "/-/ready"
          interval = "10s"
          timeout  = "3s"
        }

        check {
          name     = "prometheus-healthy"
          type     = "http"
          path     = "/-/healthy"
          interval = "30s"
          timeout  = "5s"
        }
      }

      template {
        destination = "local/config/prometheus.yml"
        change_mode = "restart"
        perms       = "0644"
        data        = <<-EOH
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'munchbox'
    datacenter: 'pi-dc'

rule_files:
  - /etc/prometheus/config/alert_rules.yml

alerting:
  alertmanagers:
    - scheme: http
      static_configs:
        - targets: ["alertmanager.service.consul:9093"]

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["127.0.0.1:9090"]
        labels:
          service: "prometheus"

  - job_name: "nomad"
    metrics_path: "/v1/metrics"
    params:
      format: ["prometheus"]
    scheme: "https"
    tls_config:
      insecure_skip_verify: true
    static_configs:
      - targets:
          - "mccoy:4646"
          - "stabler:4646"
          - "cabot:4646"
          - "goren:4646"
        labels:
          cluster: "nomad"
          role: "server"

  - job_name: "vault"
    metrics_path: "/v1/sys/metrics"
    params:
      format: ["prometheus"]
    scheme: "https"
    bearer_token_file: "/etc/prometheus/secrets/vault_token"
    tls_config:
      insecure_skip_verify: true
    static_configs:
      - targets: ["mccoy:8200"]
        labels:
          cluster: "vault-cluster-b193d95f"
          service: "vault"

  - job_name: "node-exporter"
    scrape_interval: 15s
    metrics_path: "/metrics"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        token: '{{ with secret "kv/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}'
        services: ["prometheus-node-exporter"]
        datacenter: "dc1"
    relabel_configs:
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - source_labels: ["__meta_consul_dc"]
        target_label: "consul_dc"
      - source_labels: ["__meta_consul_node_metadata_role"]
        target_label: "node_role"

  - job_name: "consul"
    metrics_path: "/v1/agent/metrics"
    params:
      format: ["prometheus"]
    scheme: "http"
    authorization:
      credentials_file: "/etc/prometheus/secrets/consul_token"
    static_configs:
      - targets:
          - "mccoy:8500"
          - "stabler:8500"
          - "cabot:8500"
          - "goren:8500"
        labels:
          cluster: "consul"

  - job_name: "site_https"
    metrics_path: "/probe"
    params:
      module: ["https_2xx"]
    static_configs:
      - targets:
          - "https://resume.alexfreidah.com/"
        labels:
          vantage: "internal"
    relabel_configs:
      - source_labels: ["__address__"]
        target_label: "__param_target"
      - source_labels: ["__param_target"]
        target_label: "instance"
      - target_label: "__address__"
        replacement: "127.0.0.1:9115"

  - job_name: "traefik"
    scheme: "http"
    consul_sd_configs:
      - server: "127.0.0.1:8500"
        token: '{{ with secret "kv/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}'
        services: ["traefik"]
        datacenter: "dc1"
    relabel_configs:
      - source_labels: ["__meta_consul_service_address"]
        regex: "(.+)"
        target_label: "__address__"
        replacement: "$1:8081"
      - source_labels: ["__meta_consul_service"]
        target_label: "service"
      - source_labels: ["__meta_consul_node"]
        target_label: "instance"
      - source_labels: ["__meta_consul_tags"]
        target_label: "consul_tags"
        EOH
      }

      template {
        destination     = "local/config/alert_rules.yml"
        change_mode     = "signal"
        change_signal   = "SIGHUP"
        perms           = "0644"
        left_delimiter  = "{{{"
        right_delimiter = "}}}"
        data            = <<-EOH
groups:
- name: infrastructure-health
  interval: 30s
  rules:
    - alert: ServiceDown
      expr: up == 0
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "Service {{ $labels.instance }} is down"
        description: "{{ $labels.job }} service on {{ $labels.instance }} has been down for more than 2 minutes."

    - alert: HighCPUUsage
      expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High CPU usage on {{ $labels.instance }}"
        description: "CPU usage is above 80% for more than 5 minutes on {{ $labels.instance }}."

    - alert: HighMemoryUsage
      expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage on {{ $labels.instance }}"
        description: "Memory usage is above 85% for more than 5 minutes on {{ $labels.instance }}."

    - alert: DiskSpaceLow
      expr: (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100 > 90
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Disk space low on {{ $labels.instance }}"
        description: "Disk usage is above 90% on {{ $labels.instance }} ({{ $labels.mountpoint }})."

- name: nomad-health
  interval: 30s
  rules:
    - alert: NomadScrapeDown
      expr: min by () (up{job="nomad"}) == 0
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "Prometheus cannot scrape any Nomad server"
        description: "All Nomad scrape targets are down or unauthorized."

    - alert: NomadJobFailed
      expr: "((max without(instance, __address__) (nomad_nomad_job_summary_failed{namespace!=\"__internal\"} + nomad_nomad_job_summary_lost{namespace!=\"__internal\"})) > 0) and on (job_id, namespace) (max by (job_id, namespace) (nomad_nomad_job_status_running + nomad_nomad_job_status_pending) > 0)"
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "Nomad job has failed allocations: {{ $labels.job_id }}"
        description: "Job {{ $labels.job_id }} in namespace {{ $labels.namespace }} has failed or lost allocations."

    - alert: NomadLeaderElection
      expr: increase(nomad_nomad_leader_leadership_lost_total[5m]) > 0
      for: 1m
      labels:
        severity: warning
      annotations:
        summary: "Nomad leader election occurred"
        description: "Nomad cluster experienced a leader election in the last 5 minutes."

- name: site-uptime
  interval: 30s
  rules:
    - alert: SiteDown
      expr: "probe_success{job=\"site_https\"} == 0 and on (instance) (probe_http_status_code{job=\"site_https\"} != 401 and probe_http_status_code{job=\"site_https\"} != 403)"
      for: 2m
      labels:
        severity: critical
        team: web
      annotations:
        summary: "Site is down: {{ $labels.instance }}"
        description: "Site {{ $labels.instance }} has been unreachable for more than 2 minutes (non-auth failure)."

    - alert: SiteTLSCertExpiring
      expr: (probe_ssl_earliest_cert_expiry{job="site_https"} - time()) < 21*24*60*60
      for: 5m
      labels:
        severity: warning
        team: web
      annotations:
        summary: "TLS certificate expiring soon: {{ $labels.instance }}"
        description: "TLS certificate for {{ $labels.instance }} expires within 21 days."

    - alert: SiteSlowResponse
      expr: probe_duration_seconds{job="site_https"} > 5
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Slow response time: {{ $labels.instance }}"
        description: "Site {{ $labels.instance }} response time is above 5 seconds."

- name: consul-health
  interval: 30s
  rules:
    - alert: ConsulPeersFailed
      expr: consul_raft_peers < 3
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "Consul cluster has lost peers"
        description: "Consul cluster has fewer than 3 peers. Current: {{ $value }}"

    - alert: ConsulLeaderElection
      expr: increase(consul_raft_leader_leadership_lost_total[5m]) > 0
      for: 1m
      labels:
        severity: warning
      annotations:
        summary: "Consul leader election occurred"
        description: "Consul cluster experienced a leader election."
        EOH
      }

      template {
        destination = "local/secrets/consul_token"
        change_mode = "restart"
        perms       = "0600"
        data        = <<-EOH
{{ with secret "kv/data/prometheus" }}{{ .Data.data.consul_token }}{{ end }}
        EOH
      }

      template {
        destination = "local/secrets/vault_token"
        change_mode = "restart"
        perms       = "0600"
        data        = <<-EOH
{{ env "VAULT_TOKEN" }}
        EOH
      }

      env {
        TZ                              = "America/Los_Angeles"
        CONSUL_HTTP_ADDR                = "127.0.0.1:8500"
        PROMETHEUS_WEB_ENABLE_LIFECYCLE = "true"
        PROMETHEUS_WEB_ENABLE_ADMIN_API = "true"
      }

      resources {
        cpu    = [[ var "cpu" . ]]
        memory = [[ var "memory" . ]]
      }

      kill_timeout   = "60s"
      kill_signal    = "SIGTERM"
      shutdown_delay = "30s"
    }
  }
}
