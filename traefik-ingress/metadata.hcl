# -------------------------------------------------------------------------------
# Project: Munchbox
# Author: Alex Freidah
# -------------------------------------------------------------------------------
# Traefik Ingress Controller Pack
#
# System job for HTTPS-first reverse proxy with Consul service discovery and
# native Consul Connect protocol support for service mesh integration.
# -------------------------------------------------------------------------------

app {
  url = "https://doc.traefik.io"
}

pack {
  name        = "traefik-ingress"
  description = "Traefik reverse proxy with Consul Connect service mesh integration"
  version     = "2.0.0"
}
