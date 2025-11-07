# -------------------------------------------------------------------------------
# Project: Nomad Job Template
# Author: Alex Freidah
# -------------------------------------------------------------------------------
# [[ var "job_description" . ]]
# -------------------------------------------------------------------------------

# -----------------------------------------------------------------------
# Load and Resolve Configuration
# -----------------------------------------------------------------------

# --- Resolve resource tier ---
[[- $tier := var "resource_tier" . ]]
[[- $resource_tiers := var "resource_tiers" . ]]
[[- $resources := index $resource_tiers $tier ]]

# --- Resolve deployment profile ---
[[- $deployment_profile := var "deployment_profile" . ]]
[[- $deployment_profiles := var "deployment_profiles" . ]]
[[- $update := index $deployment_profiles $deployment_profile ]]

# --- Resolve meta profile ---
[[- $meta_profile := var "meta_profile" . ]]
[[- $meta_profiles := var "meta_profiles" . ]]
[[- $meta := index $meta_profiles $meta_profile ]]

# --- Resolve category defaults ---
[[- $category := var "category" . ]]
[[- $category_defaults := var "category_defaults" . ]]
[[- $category_cfg := index $category_defaults $category ]]

# --- Resolve reschedule preset ---
[[- $reschedule_preset := var "reschedule_preset" . ]]
[[- $reschedule_presets := var "reschedule_presets" . ]]
[[- $reschedule := index $reschedule_presets $reschedule_preset ]]

# --- Resolve network preset ---
[[- $network_preset := var "network_preset" . ]]
[[- $network_presets := var "network_presets" . ]]
[[- $network := index $network_presets $network_preset ]]

# -----------------------------------------------------------------------
# Job Definition (includes helper templates)
# -----------------------------------------------------------------------

[[ template "job_header" . ]]
  # -----------------------------------------------------------------------
  # Task Group Configuration
  # -----------------------------------------------------------------------
  [[ template "group_config" . ]]
    # --- Tasks ---
    [[- if var "task" . ]]
    [[ template "single_task" . ]]
    [[- end ]]
    [[- if var "tasks" . ]]
    [[ template "multi_task" . ]]
    [[- end ]]
  }
}
