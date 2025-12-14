# -------------------------------------------------------------------------------
# Nomad Service Pack - Metadata
#
# Project: Munchbox / Author: Alex Freidah
#
# Universal service deployment pack supporting bridge/host networking, Consul
# Connect service mesh, Traefik HTTP ingress, and external file templating.
# Handles both internal mesh services and externally-exposed HTTP services.
# -------------------------------------------------------------------------------

app {
  url    = "https://github.com/alexfreidah/munchbox"
  author = "Alex Freidah"
}

pack {
  name        = "nomad-service"
  description = "Opinionated service deployment for Munchbox cluster with Connect mesh and Traefik ingress support"
  version     = "0.3.0"
}
