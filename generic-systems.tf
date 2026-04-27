############################
#  Generic Systems variable #
############################

variable "generic_systems" {
  type = list(object({
    name       = string
    hostname   = string
    link_tags  = list(string)

    links = list(object({
      leaf_label                    = string
      target_switch_if_name         = string
      target_switch_if_transform_id = number
      group_label                   = string
      lag_mode                      = string
    }))

    # VN names this generic system should be connected to
    vns = list(string)
  }))
}

############################
#          Locals          #
############################

locals {
  # Name-keyed map for easy GS lookup
  gs_by_name = {
    for gs in var.generic_systems :
    gs.name => gs
  }

  # All leaf labels referenced by generic systems
  gs_leaf_labels = toset(flatten([
    for gs in var.generic_systems : [
      for l in gs.links : l.leaf_label
    ]
  ]))
}

############################
#  Target leaf switches    #
############################

data "apstra_datacenter_systems" "gs_leaves" {
  for_each     = local.gs_leaf_labels
  blueprint_id = apstra_datacenter_blueprint.terraform-pod1.id

  filters = [{
    label = each.key
  }]

  # Must be read after device allocation so node labels are already set to friendly names
  depends_on = [apstra_datacenter_device_allocation.assign_devices]
}

############################
#     Generic Systems      #
############################

resource "apstra_datacenter_generic_system" "systems" {
  for_each = local.gs_by_name

  blueprint_id = apstra_datacenter_blueprint.terraform-pod1.id
  name         = each.value.name
  hostname     = each.value.hostname

  depends_on = [
    apstra_logical_device.ld,
    apstra_interface_map.im,
    apstra_datacenter_device_allocation.assign_devices,
  ]

  links = [
    for l in each.value.links : {
      tags                          = each.value.link_tags
      lag_mode                      = l.lag_mode
      target_switch_id              = one(data.apstra_datacenter_systems.gs_leaves[l.leaf_label].ids)
      target_switch_if_name         = l.target_switch_if_name
      target_switch_if_transform_id = l.target_switch_if_transform_id
      group_label                   = l.group_label
    }
  ]
}

############################
#  GS interfaces (APs)     #
############################

data "apstra_datacenter_interfaces_by_link_tag" "gs" {
  # Reuse the same map as for GS resources to keep consistent keys
  for_each     = local.gs_by_name
  blueprint_id = apstra_datacenter_blueprint.terraform-pod1.id

  tags = each.value.link_tags

  depends_on = [
    apstra_datacenter_generic_system.systems,
  ]
}

############################
#  Assign VN CTs to GS     #
############################

resource "apstra_datacenter_connectivity_templates_assignment" "gs_assign" {
  for_each     = local.gs_by_name
  blueprint_id = apstra_datacenter_blueprint.terraform-pod1.id

  # Application point: GS interface(s) found by link tags
  application_point_id = one(
    data.apstra_datacenter_interfaces_by_link_tag.gs[each.key].ids
  )

  # All CTs (one per VN) for this generic system
  connectivity_template_ids = [
    for vn_name in each.value.vns :
    apstra_datacenter_connectivity_template_interface.vn_ct[vn_name].id
  ]

  depends_on = [
    data.apstra_datacenter_interfaces_by_link_tag.gs,
    apstra_datacenter_connectivity_template_interface.vn_ct,
  ]
}
