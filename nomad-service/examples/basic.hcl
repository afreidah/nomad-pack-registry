# -------------------------------------------------------------------------------
# Cloudflare Tunnel — Nomad Pack Example
#
# Project: Munchbox
# Author: Alex Freidah
#
# Deploys cloudflared as a system job on the ingress node with host networking,
# Consul KV template integration for credentials and dynamic YAML config.
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Job Configuration
# -----------------------------------------------------------------------

job_name  = "cloudflared-tunnel"
job_type  = "system"
region    = "global"
datacenters = ["pi-dc"]
node_pool = "core"
namespace = "default"
priority  = 50
job_description = "Cloudflare Tunnel — Ingress Gateway with Dynamic YAML Configuration. Runs cloudflared as a system job on the ingress node (mccoy) with host networking. Renders tunnel credentials and YAML configuration via Nomad templates from Consul KV, routing multiple hostnames to traefik.munchbox:80."

# -----------------------------------------------------------------------
# Deployment Profile
# -----------------------------------------------------------------------

deployment_profile = "canary"
meta_profile       = "standard"

# -----------------------------------------------------------------------
# Resource Tier
# -----------------------------------------------------------------------

resource_tier = "minimal"

# -----------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------

network_preset = "host"

# -----------------------------------------------------------------------
# Placement Constraints
# -----------------------------------------------------------------------

constraints = [
  {
    attribute = "$${node.unique.name}"
    operator  = "="
    value     = "mccoy"
  }
]

# -----------------------------------------------------------------------
# Restart & Reschedule
# -----------------------------------------------------------------------

restart_attempts = 5
restart_interval = "5m"
restart_delay    = "10s"
restart_mode     = "delay"

reschedule_preset = "standard"

# -----------------------------------------------------------------------
# Task Configuration
# -----------------------------------------------------------------------

task = {
  name   = "cloudflared"
  driver = "docker"

  config = {
    image = "cloudflare/cloudflared:latest"
    args = [
      "tunnel",
      "--config", "/etc/cloudflared/config.yml",
      "run"
    ]
    volumes = [
      "local/config.yml:/etc/cloudflared/config.yml:ro",
      "local/credentials.json:/etc/cloudflared/credentials.json:ro"
    ]
  }

  templates = [
    {
      destination = "local/config.yml"
      change_mode = "restart"
      data        = <<-EOF
tunnel: my-tunnel-uuid
credentials-file: /etc/cloudflared/credentials.json

ingress:
  - hostname: "alexfreidah.com"
    service: http://traefik.munchbox:80
    originRequest: { httpHostHeader: alexfreidah.com }

  - hostname: "www.alexfreidah.com"
    service: http://traefik.munchbox:80
    originRequest: { httpHostHeader: www.alexfreidah.com }

  - hostname: "resume.alexfreidah.com"
    service: http://traefik.munchbox:80
    originRequest: { httpHostHeader: resume.alexfreidah.com }

  - hostname: "k3s-status.alexfreidah.com"
    service: http://traefik.munchbox:80
    originRequest: { httpHostHeader: k3s-status.alexfreidah.com }

  - service: http_status:404

warp-routing:
  enabled: false
EOF
    }
  ]

  resources = {
    tier = "minimal"
  }
}

# -----------------------------------------------------------------------
# Resource Tier Definitions
# -----------------------------------------------------------------------

resource_tiers = {
  minimal = {
    cpu    = 50
    memory = 64
  }
  small = {
    cpu    = 250
    memory = 512
  }
  standard = {
    cpu    = 500
    memory = 1024
  }
  large = {
    cpu    = 1000
    memory = 2048
  }
}

# -----------------------------------------------------------------------
# Network Presets
# -----------------------------------------------------------------------

network_presets = {
  bridge = {
    mode = "bridge"
  }
  host = {
    mode = "host"
  }
  cni = {
    mode = "cni"
  }
}

# -----------------------------------------------------------------------
# Deployment Profiles
# -----------------------------------------------------------------------

deployment_profiles = {
  canary = {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "10s"
    healthy_deadline  = "3m"
    progress_deadline = "10m"
    auto_revert       = true
    auto_promote      = true
  }
  rolling = {
    max_parallel      = 2
    health_check      = "checks"
    min_healthy_time  = "30s"
    healthy_deadline  = "5m"
    progress_deadline = "15m"
    auto_revert       = false
    auto_promote      = false
  }
}

# -----------------------------------------------------------------------
# Meta Profiles
# -----------------------------------------------------------------------

meta_profiles = {
  standard = {
    tier = "standard"
  }
  premium = {
    tier = "premium"
  }
}

# -----------------------------------------------------------------------
# Reschedule Presets
# -----------------------------------------------------------------------

reschedule_presets = {
  standard = {
    max_reschedules = 5
    delay           = "5s"
    delay_function  = "exponential"
    unlimited       = false
  }
  aggressive = {
    max_reschedules = 10
    delay           = "1s"
    delay_function  = "exponential"
    unlimited       = false
  }
}
