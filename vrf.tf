########################
#         VRFs         #
########################

variable "vrfs" {
  type = list(object({
    name                   = string
    default_route_next_hop = optional(string)
    default_route_leaf     = optional(list(string), [])
  }))
}

resource "apstra_datacenter_resource_pool_allocation" "vrf-vni" {
  blueprint_id = apstra_datacenter_blueprint.terraform-pod1.id
  role         = "evpn_l3_vnis"
  pool_ids     = [apstra_vni_pool.terraform-vni.id]
}

resource "apstra_datacenter_routing_zone" "vrfs" {
  for_each     = { for v in var.vrfs : v.name => v }
  blueprint_id = apstra_datacenter_blueprint.terraform-pod1.id
  name         = each.value.name
}

resource "apstra_datacenter_resource_pool_allocation" "vrf_loopbacks" {
  for_each = apstra_datacenter_routing_zone.vrfs

  blueprint_id    = apstra_datacenter_blueprint.terraform-pod1.id
  role            = "leaf_loopback_ips"
  pool_ids        = [apstra_ipv4_pool.terraform-lb.id]
  routing_zone_id = each.value.id
}

locals {
  vrfs_with_default_route = [for vrf in var.vrfs : vrf if vrf.default_route_next_hop != null]
}

resource "apstra_datacenter_connectivity_template_system" "ct_default_route" {
  count        = length(local.vrfs_with_default_route) > 0 ? 1 : 0
  blueprint_id = apstra_datacenter_blueprint.terraform-pod1.id
  name         = "Default_route"
  description  = "Default routes for all VRFs"

  custom_static_routes = {
    for vrf in local.vrfs_with_default_route :
    vrf.name => {
      routing_zone_id = apstra_datacenter_routing_zone.vrfs[vrf.name].id
      network         = "0.0.0.0/0"
      next_hop        = vrf.default_route_next_hop
    }
  }
}

########################
#  Default route leafs #
########################

data "apstra_datacenter_systems" "default_route_leafs" {
  for_each     = toset(flatten([for vrf in local.vrfs_with_default_route : vrf.default_route_leaf]))
  blueprint_id = apstra_datacenter_blueprint.terraform-pod1.id

  filters = [{
    label = each.key
  }]

  depends_on = [apstra_datacenter_device_allocation.assign_devices]
}


########################
#  Assign default CT   #
########################

resource "apstra_datacenter_connectivity_template_assignments" "assign_default_route" {
  count        = length(local.vrfs_with_default_route) > 0 ? 1 : 0
  blueprint_id = apstra_datacenter_blueprint.terraform-pod1.id

  application_point_ids = [
    for _, sys in data.apstra_datacenter_systems.default_route_leafs :
    one(sys.ids)
  ]

  connectivity_template_id = apstra_datacenter_connectivity_template_system.ct_default_route[0].id

  depends_on = [
    apstra_datacenter_connectivity_template_system.ct_default_route,
  ]
}
