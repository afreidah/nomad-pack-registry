# -------------------------------------------------------------------------------
# Project: Nomad Job Template
# Author: Alex Freidah
# -------------------------------------------------------------------------------
# Job Header Configuration
#
# Defines job-level metadata, Vault integration, and update strategy. This
# section applies to the entire job across all task groups.
# -------------------------------------------------------------------------------

[[- define "job_header" -]]

# -----------------------------------------------------------------------
# Load and Resolve Configuration (needed for helper template)
# -----------------------------------------------------------------------

[[- $deployment_profile := var "deployment_profile" . ]]
[[- $deployment_profiles := var "deployment_profiles" . ]]
[[- $update := index $deployment_profiles $deployment_profile ]]

[[- $meta_profile := var "meta_profile" . ]]
[[- $meta_profiles := var "meta_profiles" . ]]
[[- $meta := index $meta_profiles $meta_profile ]]

# -----------------------------------------------------------------------
# Job Definition
# -----------------------------------------------------------------------

job "[[ var "job_name" . ]]" {

  # -----------------------------------------------------------------------
  # Job Metadata
  # -----------------------------------------------------------------------

  type        = "[[ var "job_type" . ]]"
  datacenters = [[ var "datacenters" . | toJson ]]
  namespace   = "[[ var "namespace" . ]]"
  priority    = [[ var "priority" . ]]

  [[- if ne (var "region" .) "" ]]
  region      = "[[ var "region" . ]]"
  [[- end ]]

  [[- if ne (var "node_pool" .) "" ]]
  node_pool   = "[[ var "node_pool" . ]]"
  [[- end ]]

  # --- Standard Munchbox metadata ---
  meta {
    managed_by  = "nomad-pack"
    project     = "munchbox"
    tier        = "[[ $meta.tier ]]"
    [[- if var "category" . ]]
    category    = "[[ var "category" . ]]"
    [[- end ]]
  }

  # -----------------------------------------------------------------------
  # Vault Integration (if enabled)
  # -----------------------------------------------------------------------

  [[- if var "vault" . ]]
  [[- if index (var "vault" .) "enabled" ]]
  vault {
    [[- if index (var "vault" .) "role" ]]
    # --- Vault role for workload identity ---
    role          = "[[ index (var "vault" .) "role" ]]"
    [[- else if index (var "vault" .) "policy" ]]
    # --- Vault policy for legacy token auth ---
    policies      = ["[[ index (var "vault" .) "policy" ]]"]
    [[- end ]]
    change_mode   = "[[ index (var "vault" .) "change_mode" | default "restart" ]]"
    change_signal = "[[ index (var "vault" .) "change_signal" | default "SIGTERM" ]]"
    env           = [[ index (var "vault" .) "env" | default true ]]
    [[- if index (var "vault" .) "namespace" ]]
    namespace     = "[[ index (var "vault" .) "namespace" ]]"
    [[- end ]]
  }
  [[- end ]]
  [[- end ]]

  # -----------------------------------------------------------------------
  # Update Strategy (from deployment profile)
  # -----------------------------------------------------------------------

  update {
    max_parallel      = [[ $update.max_parallel ]]
    health_check      = "[[ $update.health_check ]]"
    min_healthy_time  = "[[ $update.min_healthy_time ]]"
    healthy_deadline  = "[[ $update.healthy_deadline ]]"
    progress_deadline = "[[ $update.progress_deadline ]]"
    auto_revert       = [[ $update.auto_revert ]]
    stagger           = "[[ var "stagger" . | default "30s" ]]"
  }

[[- end -]]
