# -------------------------------------------------------------------------------
# Munchbox Service Pack — Metadata
#
# Project: Munchbox / Author: Alex Freidah
#
# Minimal-config service deployment for the Munchbox homelab cluster.
# Handles Docker services, host volumes, Traefik routing, and Vault secrets.
# -------------------------------------------------------------------------------

app {
  url    = "https://github.com/alexfreidah/munchbox"
  author = "Alex Freidah"
}

pack {
  name        = "munchbox-service"
  description = "DRY service deployment for Munchbox - minimal config, smart defaults"
  version     = "2.0.0"
}
