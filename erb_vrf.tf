########################
#         VRFs         #
########################

variable "vrfs" {
  type = list(object({
    name                      = string
    default_route_next_hop    = string
    default_route_leaf        = list(string)
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

resource "apstra_datacenter_connectivity_template_system" "ct_default_route" {
  blueprint_id = apstra_datacenter_blueprint.terraform-pod1.id
  name         = "Default_route"
  description  = "Default routes for all VRFs"

  custom_static_routes = {
    for vrf in var.vrfs :
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
  # One data source per leaf label used in at least one VRF
  for_each     = toset(flatten([for vrf in var.vrfs : vrf.default_route_leaf]))
  blueprint_id = apstra_datacenter_blueprint.terraform-pod1.id

  filters = [{
    label = each.key
  }]

  # Must be read after device allocation so node labels are already set to friendly names
  depends_on = [apstra_datacenter_device_allocation.assign_devices]
}


########################
#  Assign default CT   #
########################

resource "apstra_datacenter_connectivity_template_assignments" "assign_default_route" {
  blueprint_id = apstra_datacenter_blueprint.terraform-pod1.id

  # All leaf switches used by at least one VRF
  application_point_ids = [
    for _, sys in data.apstra_datacenter_systems.default_route_leafs :
    one(sys.ids)
  ]

  connectivity_template_id = apstra_datacenter_connectivity_template_system.ct_default_route.id

  depends_on = [
    apstra_datacenter_connectivity_template_system.ct_default_route,
  ]
}
