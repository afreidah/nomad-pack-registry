# -------------------------------------------------------------------------------
# Project: Munchbox
# Author: Alex Freidah
# -------------------------------------------------------------------------------
# Traefik Ingress Controller — System Job
# -------------------------------------------------------------------------------

job "[[ var "job_name" . ]]" {
  region      = "[[ var "region" . ]]"
  datacenters = [[ var "datacenters" . | toJson ]]
  type        = "system"
  node_pool   = "[[ var "node_pool" . ]]"

  meta {
    managed_by = "nomad-pack"
    project    = "munchbox"
    tier       = "infrastructure"
    version    = "[[ var "traefik_version" . ]]"
  }

  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
    auto_promote      = true
  }

  constraint {
    attribute = "$${meta.role}"
    operator  = "="
    value     = "[[ var "ingress_node_constraint" . ]]"
  }

  group "traefik" {
    network {
      mode = "host"

      port "dashboard" {
        static = [[ var "dashboard_port" . ]]
        to     = [[ var "dashboard_port" . ]]
      }

      port "http" {
        static = [[ var "http_port" . ]]
        to     = [[ var "http_port" . ]]
      }

      port "https" {
        static = [[ var "https_port" . ]]
        to     = [[ var "https_port" . ]]
      }
    }

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    # -----------------------------------------------------------------------
    # Certificate Generation Prestart Task
    # -----------------------------------------------------------------------

    task "certgen" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image   = "alpine:latest"
        command = "sh"
        args    = ["-c", "apk add --no-cache openssl && /local/generate-certs.sh"]
      }

      template {
        destination = "local/generate-certs.sh"
        perms       = "0755"
        data        = <<-EOT
#!/bin/sh
set -e
CERT_DIR=/alloc/data
if [ -f $CERT_DIR/munchbox.crt ] && [ -f $CERT_DIR/munchbox.key ]; then
  if openssl x509 -in $CERT_DIR/munchbox.crt -noout 2>/dev/null; then
    echo "Valid certificates already exist, skipping generation"
    exit 0
  else
    echo "Invalid certificates found, regenerating..."
    rm -f $CERT_DIR/munchbox.crt $CERT_DIR/munchbox.key
  fi
fi
echo "Generating self-signed certificate for [[ var "certificate_cn" . ]]..."
openssl req -x509 -newkey rsa:4096 -nodes \
  -keyout $CERT_DIR/munchbox.key \
  -out $CERT_DIR/munchbox.crt \
  -days [[ var "certificate_days" . ]] \
  -subj "/CN=[[ var "certificate_cn" . ]]" \
  -addext "subjectAltName=DNS:[[ var "certificate_cn" . ]],DNS:munchbox"
echo "Certificate generated successfully"
openssl x509 -in $CERT_DIR/munchbox.crt -text -noout | head -5
        EOT
      }

      resources {
        cpu    = 300
        memory = 128
      }
    }

    # -----------------------------------------------------------------------
    # Traefik Reverse Proxy Task
    # -----------------------------------------------------------------------

    task "traefik" {
      driver = "docker"

      [[- if var "vault_enabled" . ]]
      vault {
        role = "[[ var "vault_role" . ]]"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }
      [[- end ]]

      config {
        image        = "traefik:[[ var "traefik_version" . ]]"
        network_mode = "host"
        ports        = ["http", "https", "dashboard"]
        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
          "local/traefik_dynamic.toml:/etc/traefik/traefik_dynamic.toml"
        ]
      }

      # --- Consul token from Vault ---
      template {
        destination = "secrets/consul.env"
        env         = true
        data        = <<-EOT
{{- with secret "[[ var "consul_token_path" . ]]" }}
CONSUL_TOKEN={{ .Data.data.consul_token }}
{{- end }}
        EOT
      }

      # --- Static configuration ---
      template {
        destination = "local/traefik.toml"
        perms       = "0644"
        data        = <<-EOT
[entryPoints]
  [entryPoints.web]
    address = ":[[ var "http_port" . ]]"
    [entryPoints.web.forwardedHeaders]
      trustedIPs = ["127.0.0.1/32"]

  [entryPoints.websecure]
    address = ":[[ var "https_port" . ]]"
    [entryPoints.websecure.forwardedHeaders]
      trustedIPs = ["127.0.0.1/32"]

  [entryPoints.traefik]
    address = ":[[ var "dashboard_port" . ]]"

[api]
  dashboard = true
  insecure  = false

[ping]
  entryPoint = "traefik"

[metrics]
  [metrics.prometheus]
    entryPoint = "traefik"

[providers.consulCatalog]
  refreshInterval = "15s"
  prefix          = "traefik"
  exposedByDefault = false
  [providers.consulCatalog.endpoint]
    address = "[[ var "consul_address" . ]]"
{{- with secret "[[ var "consul_token_path" . ]]" }}
    token = "{{ .Data.data.consul_token }}"
{{- end }}

[providers.file]
  filename = "/etc/traefik/traefik_dynamic.toml"

[accessLog]
[log]
  level = "INFO"
        EOT
      }

      # --- Dynamic configuration ---
      template {
        destination = "local/traefik_dynamic.toml"
        change_mode = "restart"
        perms       = "0644"
        data        = <<-EOT
[[[tls.certificates]]]
  certFile = "/alloc/data/munchbox.crt"
  keyFile  = "/alloc/data/munchbox.key"

[tls.stores]
  [tls.stores.default.defaultCertificate]
    certFile = "/alloc/data/munchbox.crt"
    keyFile  = "/alloc/data/munchbox.key"

[tls.options]
  [tls.options.default]
    minVersion = "VersionTLS12"
    sniStrict  = true

[http.routers]
  [http.routers.http-redirect]
    rule        = "HostRegexp(`{host:.+\\.munchbox}`)"
    entryPoints = ["web"]
    middlewares = ["redirect-https"]
    service     = "ping-svc"
    priority    = 1

  [http.routers.ping]
    rule        = "Host(`traefik.munchbox`) && Path(`/ping`)"
    entryPoints = ["websecure"]
    service     = "ping-svc"

[http.middlewares]
  [http.middlewares.redirect-https.redirectScheme]
    scheme = "https"

[http.services]
  [http.services.ping-svc.loadBalancer]
    [[[http.services.ping-svc.loadBalancer.servers]]]
      url = "http://127.0.0.1:[[ var "dashboard_port" . ]]/ping"
        EOT
      }

      env {
        TZ = "UTC"
      }

      service {
        name = "traefik"
        port = "https"

        check {
          name     = "traefik-https"
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

      service {
        name = "traefik-dashboard"
        port = "dashboard"

        check {
          name     = "traefik-ping"
          type     = "http"
          path     = "/ping"
          interval = "10s"
          timeout  = "2s"
        }
      }

      resources {
        cpu    = [[ var "cpu" . ]]
        memory = [[ var "memory" . ]]
      }
    }
  }
}
