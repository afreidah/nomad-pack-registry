job "[[ var "job_name" . ]]" {
  region      = "[[ var "region" . ]]"
  datacenters = [[ var "datacenters" . | toJson ]]
  type        = "system"
  node_pool   = "[[ var "node_pool" . ]]"

  meta {
    managed_by = "nomad-pack"
    project    = "munchbox"
    tier       = "logging"
    version    = "[[ var "promtail_version" . ]]"
  }

  update {
    max_parallel     = 1
    min_healthy_time = "10s"
    healthy_deadline = "3m"
    auto_revert      = true
  }

  group "promtail" {
    network {
      mode = "host"
      port "http" {
        static = [[ var "http_port" . ]]
        to     = [[ var "http_port" . ]]
      }
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "delay"
    }

    task "promtail" {
      driver = "docker"

      config {
        image              = "grafana/promtail:[[ var "promtail_version" . ]]"
        network_mode       = "host"
        ports              = ["http"]
        dns_servers        = [[ var "dns_servers" . | toJson ]]
        dns_search_domains = ["service.consul"]
        dns_options        = ["timeout:2", "attempts:3", "ndots:1"]
        args = [
          "-config.file=/etc/promtail/config.yaml"
        ]
        volumes = [
          "/var/log/journal:/var/log/journal:ro",
          "/run/log/journal:/run/log/journal:ro",
          "/etc/machine-id:/etc/machine-id:ro",
          "local/config:/etc/promtail:ro",
          "/opt/nomad/alloc:/opt/nomad/alloc:ro",
          "/opt/nomad/data/alloc:/opt/nomad/data/alloc:ro"
        ]
      }

      template {
        destination = "local/config/config.yaml"
        change_mode = "restart"
        perms       = "0644"
        data        = <<EOH
server:
  http_listen_port: [[ var "http_port" . ]]
  log_level: info

clients:
  - url: [[ var "loki_address" . ]]/loki/api/v1/push

scrape_configs:
  - job_name: systemd-journal
    journal:
      path: /var/log/journal
      max_age: 12h
      labels:
        job: systemd-journal
        node: default

    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'
      - source_labels: ['__journal__hostname']
        target_label: 'hostname'
      - source_labels: ['__journal__syslog_identifier']
        regex: '(.+)'
        target_label: 'service'
      - source_labels: ['__journal__priority']
        target_label: 'priority'

    pipeline_stages:
      - template:
          source: level
          template: |
            {%raw%}{{- $p := .Labels.priority -}}
            {{- if eq $p "0" -}}emerg
            {{- else if eq $p "1" -}}alert
            {{- else if eq $p "2" -}}crit
            {{- else if eq $p "3" -}}error
            {{- else if eq $p "4" -}}warning
            {{- else if eq $p "5" -}}notice
            {{- else if eq $p "6" -}}info
            {{- else if eq $p "7" -}}debug
            {{- else -}}unknown{{- end -}}{%endraw%}
      - labels:
          level:
      - json:
          expressions:
            msg: message
            level: level

  - job_name: systemd-journal-volatile
    journal:
      path: /run/log/journal
      max_age: 12h
      labels:
        job: systemd-journal
        node: default

    relabel_configs:
      - source_labels: ['__journal__systemd_unit']
        target_label: 'unit'
      - source_labels: ['__journal__hostname']
        target_label: 'hostname'
      - source_labels: ['__journal__syslog_identifier']
        regex: '(.+)'
        target_label: 'service'
      - source_labels: ['__journal__priority']
        target_label: 'priority'

    pipeline_stages:
      - template:
          source: level
          template: |
            {%raw%}{{- $p := .Labels.priority -}}
            {{- if eq $p "0" -}}emerg
            {{- else if eq $p "1" -}}alert
            {{- else if eq $p "2" -}}crit
            {{- else if eq $p "3" -}}error
            {{- else if eq $p "4" -}}warning
            {{- else if eq $p "5" -}}notice
            {{- else if eq $p "6" -}}info
            {{- else if eq $p "7" -}}debug
            {{- else -}}unknown{{- end -}}{%endraw%}
      - labels:
          level:
      - json:
          expressions:
            msg: message
            level: level

  - job_name: nomad-stdout
    static_configs:
      - targets: [localhost]
        labels:
          job: nomad-alloc
          node: default
          stream: stdout
          __path__: /opt/nomad/alloc/*/alloc/logs/*.stdout.[0-9]*

      - targets: [localhost]
        labels:
          job: nomad-alloc
          node: default
          stream: stdout
          __path__: /opt/nomad/data/alloc/*/alloc/logs/*.stdout.[0-9]*

    pipeline_stages:
      - regex:
          source: filename
          expression: '.*/alloc/(?P<alloc_id>[^/]+)/alloc/logs/(?P<task_name>[^.]+)\.stdout\.\d+'
      - labels:
          alloc_id:
          task_name:
      - json:
          expressions:
            level: level
            msg: msg
            message: message
      - match:
          selector: '{job="nomad-alloc"}'
          stages:
            - drop:
                expression: '^\s*$'

  - job_name: nomad-stderr
    static_configs:
      - targets: [localhost]
        labels:
          job: nomad-alloc
          node: default
          stream: stderr
          __path__: /opt/nomad/alloc/*/alloc/logs/*.stderr.[0-9]*

      - targets: [localhost]
        labels:
          job: nomad-alloc
          node: default
          stream: stderr
          __path__: /opt/nomad/data/alloc/*/alloc/logs/*.stderr.[0-9]*

    pipeline_stages:
      - regex:
          source: filename
          expression: '.*/alloc/(?P<alloc_id>[^/]+)/alloc/logs/(?P<task_name>[^.]+)\.stderr\.\d+'
      - labels:
          alloc_id:
          task_name:
      - json:
          expressions:
            level: level
            msg: msg
            message: message
      - match:
          selector: '{job="nomad-alloc"}'
          stages:
            - drop:
                expression: '^\s*$'

positions:
  filename: /alloc/data/positions.yaml

limits_config:
  readline_rate_enabled: true
  readline_rate: 10000
  readline_burst: 20000
  readline_rate_drop: false
EOH
      }

      env {
        TZ = "America/Los_Angeles"
      }

      service {
        name     = "promtail"
        port     = "http"
        provider = "consul"
        tags = [
          "logging",
          "promtail"
        ]

        check {
          name     = "promtail-ready"
          type     = "http"
          path     = "/ready"
          interval = "10s"
          timeout  = "3s"
        }
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
