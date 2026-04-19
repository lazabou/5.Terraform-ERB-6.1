############################
#  Variable d'entrée GS   #
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

    # Noms des VN sur lesquels ce GS doit être branché
    vns = list(string)
  }))
}

############################
#        Locals           #
############################

locals {
  # Map pratique: nom -> objet GS (clé = "FW", etc.)
  gs_by_name = {
    for gs in var.generic_systems :
    gs.name => gs
  }

  # Tous les labels de leaf utilisés par les GS
  gs_leaf_labels = toset(flatten([
    for gs in var.generic_systems : [
      for l in gs.links : l.leaf_label
    ]
  ]))
}

############################
#   Leafs cibles des GS    #
############################

data "apstra_datacenter_systems" "gs_leaves" {
  for_each     = local.gs_leaf_labels
  blueprint_id = apstra_datacenter_blueprint.terraform-pod1.id

  filters = [{
    label = each.key   # ex: "terraform_border_001_leaf1"
  }]
}

############################
#   Generic Systems        #
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
#  Interfaces des GS (AP)  #
############################

data "apstra_datacenter_interfaces_by_link_tag" "gs" {
  # On réutilise la même map que pour les GS, pour garder les mêmes clés
  for_each     = local.gs_by_name
  blueprint_id = apstra_datacenter_blueprint.terraform-pod1.id

  tags = each.value.link_tags

  depends_on = [
    apstra_datacenter_generic_system.systems,
  ]
}

############################
#  Assignation des CT VN   #
############################

resource "apstra_datacenter_connectivity_templates_assignment" "gs_assign" {
  for_each     = local.gs_by_name
  blueprint_id = apstra_datacenter_blueprint.terraform-pod1.id

  # Application point = interface(s) du GS trouvées via les tags
  application_point_id = one(
    data.apstra_datacenter_interfaces_by_link_tag.gs[each.key].ids
  )

  # Tous les CT (un par VN) pour ce GS
  connectivity_template_ids = [
    for vn_name in each.value.vns :
    apstra_datacenter_connectivity_template_interface.vn_ct[vn_name].id
  ]

  depends_on = [
    data.apstra_datacenter_interfaces_by_link_tag.gs,
    apstra_datacenter_connectivity_template_interface.vn_ct,
  ]
}