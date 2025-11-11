# -------------------------------------------------------------------------------
# Project: Munchbox
# Author: Alex Freidah
# -------------------------------------------------------------------------------
# Traefik Ingress Controller Pack
#
# System job for HTTPS-first reverse proxy with Consul service discovery.
# Auto-generates self-signed certificates for *.munchbox domains.
# -------------------------------------------------------------------------------

app {
  url = "https://doc.traefik.io"
}

pack {
  name        = "traefik-ingress"
  description = "Traefik reverse proxy with Consul service discovery and certificate generation"
  version     = "1.0.0"
}
