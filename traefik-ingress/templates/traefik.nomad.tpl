# -------------------------------------------------------------------------------
# Traefik Ingress Controller — Consul Connect Service Mesh Gateway
#
# Project: Munchbox / Author: Alex Freidah
#
# System job for HTTPS-first reverse proxy with native Consul Connect protocol
# support. Routes external traffic into service mesh via authenticated mTLS
# connections without requiring Envoy sidecar. Auto-generates self-signed
# certificates for *.munchbox domains.
# -------------------------------------------------------------------------------

job "[[ var "job_name" . ]]" {
  region      = "[[ var "region" . ]]"
  datacenters = [[ var "datacenters" . | toJson ]]
  type        = "system"
  node_pool   = "[[ var "node_pool" . ]]"

  # ---------------------------------------------------------------------------
  #  Job Metadata
  # ---------------------------------------------------------------------------

  meta {
    managed_by = "nomad-pack"
    project    = "munchbox"
    tier       = "infrastructure"
    version    = "[[ var "traefik_version" . ]]"
  }

  # ---------------------------------------------------------------------------
  #  Update Strategy
  # ---------------------------------------------------------------------------

  update {
    max_parallel      = 1
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "10m"
    auto_revert       = true
  }

  # ---------------------------------------------------------------------------
  #  Placement Constraints
  # ---------------------------------------------------------------------------

  constraint {
    attribute = "$${meta.role}"
    operator  = "="
    value     = "[[ var "ingress_node_constraint" . ]]"
  }

  # ---------------------------------------------------------------------------
  #  Traefik Group
  # ---------------------------------------------------------------------------

  group "traefik" {

    # -----------------------------------------------------------------------
    #  Network Configuration
    # -----------------------------------------------------------------------

    network {
      mode = "host"

      # --- Dashboard port (LAN-only) ---
      port "dashboard" {
        static = [[ var "dashboard_port" . ]]
        to     = [[ var "dashboard_port" . ]]
      }

      # --- HTTP port (redirects to HTTPS) ---
      port "http" {
        static = [[ var "http_port" . ]]
        to     = [[ var "http_port" . ]]
      }

      # --- HTTPS port ---
      port "https" {
        static = [[ var "https_port" . ]]
        to     = [[ var "https_port" . ]]
      }
    }

    # -----------------------------------------------------------------------
    #  Restart Policy
    # -----------------------------------------------------------------------

    restart {
      attempts = 3
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    # -----------------------------------------------------------------------
    #  Certificate Generation Task
    # -----------------------------------------------------------------------

    task "certgen" {
      driver = "docker"

      # --- Lifecycle configuration ---
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      # --- Task configuration ---
      config {
        image   = "alpine:latest"
        command = "sh"
        args    = ["-c", "apk add --no-cache openssl && /local/generate-certs.sh"]
      }

      # --- Certificate generation script ---
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

      # --- Resource allocation ---
      resources {
        cpu    = 300
        memory = 128
      }
    }

    # -----------------------------------------------------------------------
    #  Traefik Proxy Task
    # -----------------------------------------------------------------------

    task "traefik" {
      driver = "docker"

      [[- if var "vault_enabled" . ]]
      # --- Vault integration ---
      vault {
        role = "[[ var "vault_role" . ]]"
      }

      identity {
        env  = true
        file = true
        aud  = ["vault.io"]
      }
      [[- end ]]

      # --- Task configuration ---
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
# =========================================================================
# Traefik Static Configuration
# =========================================================================

# -------------------------------------------------------------------------
# Entry Points
# -------------------------------------------------------------------------

[entryPoints]
  [entryPoints.web]
    address = ":[[ var "http_port" . ]]"
    [entryPoints.web.forwardedHeaders]
      trustedIPs = ["127.0.0.1/32", "192.168.68.0/24"]

  [entryPoints.websecure]
    address = ":[[ var "https_port" . ]]"
    [entryPoints.websecure.forwardedHeaders]
      trustedIPs = ["127.0.0.1/32", "192.168.68.0/24"]

  [entryPoints.traefik]
    address = ":[[ var "dashboard_port" . ]]"

# -------------------------------------------------------------------------
# API Dashboard
# -------------------------------------------------------------------------

[api]
  dashboard = true
  insecure  = false

# -------------------------------------------------------------------------
# Health Check
# -------------------------------------------------------------------------

[ping]
  entryPoint = "traefik"

# -------------------------------------------------------------------------
# Metrics
# -------------------------------------------------------------------------

[metrics]
  [metrics.prometheus]
    entryPoint = "traefik"

# -------------------------------------------------------------------------
# Consul Catalog Provider with Connect Support
# -------------------------------------------------------------------------

[providers.consulCatalog]
  refreshInterval = "15s"
  prefix          = "traefik"
  
  # --- Consul Connect service mesh integration ---
  connectAware     = [[ var "connect_aware" . ]]
  connectByDefault = [[ var "connect_by_default" . ]]
  exposedByDefault = [[ var "exposed_by_default" . ]]
  
  [providers.consulCatalog.endpoint]
    address = "[[ var "consul_address" . ]]"
{{- with secret "[[ var "consul_token_path" . ]]" }}
    token = "{{ .Data.data.consul_token }}"
{{- end }}

# -------------------------------------------------------------------------
# File Provider for Static Routes
# -------------------------------------------------------------------------

[providers.file]
  filename = "/etc/traefik/traefik_dynamic.toml"

# -------------------------------------------------------------------------
# Logging
# -------------------------------------------------------------------------

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
# =========================================================================
# Traefik Dynamic Configuration
# =========================================================================

# -------------------------------------------------------------------------
# TLS Configuration
# -------------------------------------------------------------------------

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

# -------------------------------------------------------------------------
# Static Route: Consul UI
# -------------------------------------------------------------------------

[http.routers.consul]
  rule        = "Host(`consul.munchbox`)"
  entryPoints = ["websecure"]
  service     = "consul-ui"
  middlewares = ["dashboard-allowlan"]

# -------------------------------------------------------------------------
# Static Route: Traefik Dashboard
# -------------------------------------------------------------------------

[http.routers.traefik-fallback]
  rule        = "Host(`traefik.munchbox`) || PathPrefix(`/dashboard`) || PathPrefix(`/api`)"
  entryPoints = ["traefik"]
  service     = "api@internal"
  middlewares = ["dashboard-auth", "dashboard-allowlan", "dashboard-redirect"]
  priority    = 2

# -------------------------------------------------------------------------
# Static Route: Public Resume (HTTP)
# -------------------------------------------------------------------------

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

# -------------------------------------------------------------------------
# Static Route: K3s Status (HTTP)
# -------------------------------------------------------------------------

[http.routers.k3s-status-public]
  rule        = "Host(`k3s-status.alexfreidah.com`)"
  entryPoints = ["web"]
  service     = "health-checker-svc"
  middlewares = ["k3s-status-sec"]
  priority    = 102

# -------------------------------------------------------------------------
# Static Route: HTTP to HTTPS Redirect
# -------------------------------------------------------------------------

[http.routers.http-redirect]
  rule        = "HostRegexp(`{host:.+\\.munchbox}`)"
  entryPoints = ["web"]
  middlewares = ["redirect-https"]
  service     = "ping-svc"
  priority    = 1

# -------------------------------------------------------------------------
# Static Route: Ping
# -------------------------------------------------------------------------

[http.routers.ping]
  rule        = "Host(`traefik.munchbox`) && Path(`/ping`)"
  entryPoints = ["websecure"]
  service     = "ping-svc"

# -------------------------------------------------------------------------
# Middleware: Dashboard Authentication
# -------------------------------------------------------------------------

[http.middlewares.dashboard-auth.basicAuth]
  users = ["alex:$2y$05$2pwj9TDZZ29xWxv.eUAKLeKOhm/RrbbrbNewMkzjg1aGm4Bp81yKS"]

# -------------------------------------------------------------------------
# Middleware: Dashboard LAN Access
# -------------------------------------------------------------------------

[http.middlewares.dashboard-allowlan.ipAllowList]
  sourceRange = ["192.168.68.0/24", "127.0.0.1/32"]

# -------------------------------------------------------------------------
# Middleware: Dashboard Redirect
# -------------------------------------------------------------------------

[http.middlewares.dashboard-redirect.redirectRegex]
  regex       = "^https?://traefik\\.munchbox/?$"
  replacement = "https://traefik.munchbox/dashboard/"
  permanent   = true

# -------------------------------------------------------------------------
# Middleware: HTTPS Redirect
# -------------------------------------------------------------------------

[http.middlewares.redirect-https.redirectScheme]
  scheme = "https"

# -------------------------------------------------------------------------
# Middleware: Resume Rate Limiting
# -------------------------------------------------------------------------

[http.middlewares.resume-ratelimit.rateLimit]
  average = 20
  burst   = 40
  [http.middlewares.resume-ratelimit.rateLimit.sourceCriterion]
    requestHeaderName = "CF-Connecting-IP"

# -------------------------------------------------------------------------
# Middleware: Resume Security Headers
# -------------------------------------------------------------------------

[http.middlewares.resume-sec.headers.customResponseHeaders]
  Cross-Origin-Embedder-Policy = "unsafe-none"
  Cross-Origin-Opener-Policy   = "unsafe-none"
  Cross-Origin-Resource-Policy = "cross-origin"

# -------------------------------------------------------------------------
# Middleware: Resume In-Flight Limit
# -------------------------------------------------------------------------

[http.middlewares.resume-inflight.inFlightReq]
  amount = 100

# -------------------------------------------------------------------------
# Middleware: WWW Redirects
# -------------------------------------------------------------------------

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

# -------------------------------------------------------------------------
# Middleware: Security Headers (Resume)
# -------------------------------------------------------------------------

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

# -------------------------------------------------------------------------
# Middleware: Security Headers (K3s Status)
# -------------------------------------------------------------------------

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

# -------------------------------------------------------------------------
# Static Services
# -------------------------------------------------------------------------

[http.services.consul-ui.loadBalancer.servers.0]
  url = "http://127.0.0.1:8500/ui/"

[http.services.nginx-resume.loadBalancer.servers.0]
  url = "http://192.168.68.63:8080"

[http.services.ping-svc.loadBalancer.servers.0]
  url = "http://127.0.0.1:[[ var "dashboard_port" . ]]/ping"

[http.services.health-checker-svc.loadBalancer.servers.0]
  url = "http://health-checker.service.consul:18080"
        EOT
      }

      # --- Runtime environment ---
      env {
        TZ = "UTC"
      }

      # --- Service registration: HTTPS endpoint ---
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

      # --- Service registration: Dashboard ---
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

      # --- Resource allocation ---
      resources {
        cpu    = [[ var "cpu" . ]]
        memory = [[ var "memory" . ]]
      }
    }
  }
}
