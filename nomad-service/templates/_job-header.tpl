# packs/registry/nomad-service/templates/_job-header.tpl
# -------------------------------------------------------------------------------
# Project: Munchbox
# Author: Alex Freidah
# -------------------------------------------------------------------------------
# Job Header Configuration
#
# Defines job-level metadata, Vault integration, and update strategy.
# Supports component-specific job_type (e.g., promtail = system).
#
# -------------------------------------------------------------------------------

[[- define "job_header" -]]

# -----------------------------------------------------------------------
# Load and Resolve Configuration
# -----------------------------------------------------------------------

[[- $deployment_profile := var "deployment_profile" . ]]
[[- $deployment_profiles := var "deployment_profiles" . ]]
[[- $update := index $deployment_profiles $deployment_profile ]]

[[- $meta_profile := var "meta_profile" . ]]
[[- $meta_profiles := var "meta_profiles" . ]]
[[- $meta := index $meta_profiles $meta_profile ]]

[[- $c := index (var "component_registry" .) (var "component" .) ]]

# Compute effective job_type: prefer explicit var, else component override, else "service"
[[- $job_type := (var "job_type" . | default (and $c $c.job_type) | default "service") ]]

# Compute effective job_name: prefer explicit var, else component, else "service"
[[- $job_name := (var "job_name" . | default (var "component" .) | default "service") ]]

# -----------------------------------------------------------------------
# Job Definition
# -----------------------------------------------------------------------

job "[[ $job_name ]]" {

  # -----------------------------------------------------------------------
  # Job Metadata
  # -----------------------------------------------------------------------

  type        = "[[ $job_type ]]"
  datacenters = [[ var "datacenters" . | toJson ]]
  namespace   = "[[ var "namespace" . ]]"
  priority    = [[ var "priority" . ]]
  [[- if ne (var "region" .) "" ]]
  region      = "[[ var "region" . ]]"
  [[- end ]]
  [[- if ne (var "node_pool" .) "" ]]
  node_pool   = "[[ var "node_pool" . ]]"
  [[- end ]]

  meta {
    managed_by = "nomad-pack"
    project    = "munchbox"
    tier       = "[[ $meta.tier ]]"
    [[- if var "category" . ]]
    category   = "[[ var "category" . ]]"
    [[- end ]]
  }

  # -----------------------------------------------------------------------
  # Vault Integration (if enabled)
  # -----------------------------------------------------------------------

  [[- if var "vault" . ]]
  [[- if index (var "vault" .) "enabled" ]]
  vault {
    [[- if index (var "vault" .) "role" ]]
    role          = "[[ index (var "vault" .) "role" ]]"
    [[- else if index (var "vault" .) "policy" ]]
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
  # Update Strategy
  # -----------------------------------------------------------------------
  [[- if eq $job_type "service" ]]
  update {
    max_parallel      = [[ $update.max_parallel ]]
    health_check      = "[[ $update.health_check ]]"
    min_healthy_time  = "[[ $update.min_healthy_time ]]"
    healthy_deadline  = "[[ $update.healthy_deadline ]]"
    progress_deadline = "[[ $update.progress_deadline ]]"
    auto_revert       = [[ $update.auto_revert ]]

    [[- if gt $update.canary 0 ]]
    canary            = [[ $update.canary ]]
    auto_promote      = [[ $update.auto_promote ]]
    [[- else ]]
    auto_promote      = false
    [[- end ]]

    stagger           = "[[ var "stagger" . | default "30s" ]]"
  }
  [[- end ]]

[[- end -]]
