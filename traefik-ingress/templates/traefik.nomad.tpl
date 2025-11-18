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

      port "registry-tcp" {
        static = [[ var "registry_tcp_port" . ]]
        to     = [[ var "registry_tcp_port" . ]]
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
        ports        = ["http", "https", "dashboard", "registry-tcp"]
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

  [entryPoints.registry-tcp]
    address = ":[[ var "registry_tcp_port" . ]]"

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
[tls.certificates.0]
  certFile = "/alloc/data/munchbox.crt"
  keyFile  = "/alloc/data/munchbox.key"

[tls.stores.default.defaultCertificate]
  certFile = "/alloc/data/munchbox.crt"
  keyFile  = "/alloc/data/munchbox.key"

[tls.options.default]
  minVersion = "VersionTLS12"
  sniStrict  = true
  curvePreferences = ["CurveP521", "CurveP384"]
  cipherSuites = [
    "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
    "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
    "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256",
    "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256",
    "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
    "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
  ]

[http.routers.consul]
  rule        = "Host(`consul.munchbox`)"
  entryPoints = ["websecure"]
  service     = "consul-ui"
  middlewares = ["dashboard-allowlan"]

[http.routers.traefik-fallback]
  rule        = "Host(`traefik.munchbox`) || PathPrefix(`/dashboard`) || PathPrefix(`/api`)"
  entryPoints = ["traefik"]
  service     = "api@internal"
  middlewares = ["dashboard-auth", "dashboard-allowlan", "dashboard-redirect"]
  priority    = 2

[http.routers.resume-public]
  rule        = "Host(`resume.alexfreidah.com`) || Host(`www.resume.alexfreidah.com`)"
  entryPoints = ["web"]
  service     = "nginx-resume"
  middlewares = ["redirect-resume-www", "resume-sec", "resume-ratelimit", "resume-inflight"]
  priority    = 100

[http.routers.resume-apex-public]
  rule        = "Host(`alexfreidah.com`) || Host(`www.alexfreidah.com`)"
  entryPoints = ["web"]
  service     = "nginx-resume"
  middlewares = ["redirect-apex-www", "resume-sec", "resume-ratelimit", "resume-inflight"]
  priority    = 101

[http.routers.redirect-www-to-resume]
  rule        = "Host(`www.alexfreidah.com`)"
  entryPoints = ["web"]
  service     = "ping-svc"
  middlewares = ["redirect-www-to-resume"]
  priority    = 110

[http.routers.k3s-status-public]
  rule        = "Host(`k3s-status.alexfreidah.com`)"
  entryPoints = ["web"]
  service     = "health-checker-svc"
  middlewares = ["k3s-status-sec"]
  priority    = 102

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

[http.middlewares.dashboard-auth.basicAuth]
  users = ["alex:$2y$05$2pwj9TDZZ29xWxv.eUAKLeKOhm/RrbbrbNewMkzjg1aGm4Bp81yKS"]

[http.middlewares.dashboard-allowlan.ipAllowList]
  sourceRange = ["192.168.68.0/24", "127.0.0.1/32"]

[http.middlewares.dashboard-redirect.redirectRegex]
  regex       = "^https?://traefik\\.munchbox/?$"
  replacement = "https://traefik.munchbox/dashboard/"
  permanent   = true

[http.middlewares.redirect-https.redirectScheme]
  scheme = "https"

[http.middlewares.resume-ratelimit.rateLimit]
  average = 20
  burst   = 40
  [http.middlewares.resume-ratelimit.rateLimit.sourceCriterion]
    requestHeaderName = "CF-Connecting-IP"

[http.middlewares.resume-sec.headers.customResponseHeaders]
  Cross-Origin-Embedder-Policy = "unsafe-none"
  Cross-Origin-Opener-Policy   = "unsafe-none"
  Cross-Origin-Resource-Policy = "cross-origin"

[http.middlewares.resume-inflight.inFlightReq]
  amount = 100

[http.middlewares.redirect-resume-www.redirectRegex]
  regex       = "^https?://www\\.resume\\.alexfreidah\\.com/(.*)"
  replacement = "https://resume.alexfreidah.com/$1"
  permanent   = true

[http.middlewares.redirect-apex-www.redirectRegex]
  regex       = "^https?://www\\.alexfreidah\\.com/(.*)"
  replacement = "https://alexfreidah.com/$1"
  permanent   = true

[http.middlewares.redirect-www-to-resume.redirectRegex]
  regex       = "^https?://www\\.alexfreidah\\.com/(.*)"
  replacement = "https://resume.alexfreidah.com/$1"
  permanent   = true

[http.middlewares.resume-sec.headers]
  stsSeconds           = 31536000
  stsIncludeSubdomains = true
  forceSTSHeader       = true
  stsPreload           = false
  contentTypeNosniff       = true
  customFrameOptionsValue  = "SAMEORIGIN"
  referrerPolicy           = "no-referrer"
  permissionsPolicy = """
    geolocation=(), microphone=(), camera=(), usb=(),
    fullscreen=(self), payment=(), accelerometer=(),
    gyroscope=(), magnetometer=(), midi=(),
    picture-in-picture=(), clipboard-read=(), clipboard-write=(),
    browsing-topics=()
  """
  contentSecurityPolicy = """
    default-src 'self';
    base-uri 'self';
    object-src 'none';
    frame-ancestors 'self';
    img-src 'self' data: blob:;
    font-src 'self' data:;
    style-src 'self' 'unsafe-inline';
    script-src 'self' 'unsafe-inline';
    connect-src 'none';
    form-action 'self';
    upgrade-insecure-requests;
  """

[http.middlewares.k3s-status-sec.headers]
  stsSeconds              = 31536000
  stsIncludeSubdomains    = true
  forceSTSHeader          = true
  stsPreload              = false
  contentTypeNosniff      = true
  customFrameOptionsValue = "SAMEORIGIN"
  referrerPolicy          = "no-referrer"
  [http.middlewares.k3s-status-sec.headers.customResponseHeaders]
    Cache-Control                    = "no-store, no-cache, must-revalidate"
    Pragma                           = "no-cache"
    Cross-Origin-Embedder-Policy     = "unsafe-none"
    Cross-Origin-Opener-Policy       = "unsafe-none"
    Cross-Origin-Resource-Policy     = "cross-origin"
  contentSecurityPolicy = """
    default-src 'self' data: blob: https:;
    base-uri 'self';
    object-src 'none';
    frame-ancestors 'self';
    img-src 'self' data: blob: https:;
    font-src 'self' data: https:;
    style-src 'self' 'unsafe-inline' https:;
    script-src 'self' 'unsafe-inline' 'unsafe-eval' blob: https:;
    connect-src 'self' https: ws: wss: data: blob:;
    worker-src 'self' blob:;
    form-action 'self';
    upgrade-insecure-requests;
  """

[http.services.consul-ui.loadBalancer.servers.0]
  url = "http://127.0.0.1:8500/ui/"

[http.services.nginx-resume.loadBalancer.servers.0]
  url = "http://192.168.68.63:8080"

[http.services.ping-svc.loadBalancer.servers.0]
  url = "http://127.0.0.1:[[ var "dashboard_port" . ]]/ping"

[http.services.health-checker-svc.loadBalancer.servers.0]
  url = "http://health-checker.service.consul:18080"

# -----------------------------------------------------------------------
# Docker Registry TCP Router
# -----------------------------------------------------------------------

[tcp.routers.docker-registry]
  rule        = "HostSNI(`*`)"
  entryPoints = ["registry-tcp"]
  service     = "docker-registry-tcp"

[tcp.services.docker-registry-tcp.loadBalancer]
  servers = [
    { address = "docker-mirror.service.consul:5000" }
  ]
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
