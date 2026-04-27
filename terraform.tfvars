blueprint_name = "Terraform-pod1"

nodes = {
  Spine1  = { label = "Spine1",  hostname = "Spine1"  }
  Spine2  = { label = "Spine2",  hostname = "Spine2"  }
  Border1 = { label = "Border1", hostname = "Border1" }
  Border2 = { label = "Border2", hostname = "Border2" }
  Leaf1   = { label = "Leaf1",   hostname = "Leaf1"   }
  Leaf2   = { label = "Leaf2",   hostname = "Leaf2"   }
}

device_keys = {
  Spine1  = "WH0216290096"
  Spine2  = "WH0217430051"
  Border1 = "DA722"
  Border2 = "DL440"
  Leaf1   = "XH3722180714"
  Leaf2   = "XH3722180698"
}

loopback_pool = { name = "Terraform-Loopback", network = "10.0.0.0/24" }

link_pool = { name = "Terraform-Link", network = "10.1.0.0/24" }

asn_pool = { name = "Terraform-ASN", first = 65100, last = 65199 }

vni_pool = { name = "Terraform-vni", first = 10000, last = 19999 }

vrfs = [
  {
    name                   = "Blue_VRF"
    default_route_next_hop = "10.0.10.254"
    default_route_leaf     = ["Border1", "Border2"]
  },
  {
    name                   = "Red_VRF"
    default_route_next_hop = "10.0.20.254"
    default_route_leaf     = ["Border1", "Border2"]
  },
]

vns = [
  {
    name                 = "Vlan-100"
    vlan_id              = 100
    vrf_name             = "Blue_VRF"
    ipv4_virtual_gateway = "10.0.100.1"
    ipv4_subnet          = "10.0.100.0/24"
    bindings             = ["Leaf1"]
  },
  {
    name                 = "Vlan-200"
    vlan_id              = 200
    vrf_name             = "Red_VRF"
    ipv4_virtual_gateway = "10.0.200.1"
    ipv4_subnet          = "10.0.200.0/24"
    bindings             = ["Leaf1"]
  },
  {
    name                 = "Vlan-10"
    vlan_id              = 10
    vrf_name             = "Blue_VRF"
    ipv4_virtual_gateway = "10.0.10.1"
    ipv4_subnet          = "10.0.10.0/24"
    bindings             = ["Border1"]
  },
  {
    name                 = "Vlan-20"
    vlan_id              = 20
    vrf_name             = "Red_VRF"
    ipv4_virtual_gateway = "10.0.20.1"
    ipv4_subnet          = "10.0.20.0/24"
    bindings             = ["Border1"]
  },
  {
    name                 = "Vlan-150"
    vlan_id              = 150
    vrf_name             = "Blue_VRF"
    ipv4_virtual_gateway = "10.0.150.1"
    ipv4_subnet          = "10.0.150.0/24"
    bindings             = ["Leaf1", "Leaf2"]
  },
]

generic_systems = [
  {
    name      = "Server14"
    hostname  = "Server14"
    link_tags = ["server14"]
    links = [
      {
        leaf_label                    = "Leaf1"
        target_switch_if_name         = "xe-0/0/1"
        target_switch_if_transform_id = 2
        group_label                   = "bond0"
        lag_mode                      = "lacp_active"
      },
      {
        leaf_label                    = "Leaf2"
        target_switch_if_name         = "xe-0/0/1"
        target_switch_if_transform_id = 2
        group_label                   = "bond0"
        lag_mode                      = "lacp_active"
      },
    ]
    vns = ["Vlan-100", "Vlan-200"]
  },
  {
    name      = "Server10"
    hostname  = "Server10"
    link_tags = ["server10"]
    links = [
      {
        leaf_label                    = "Leaf1"
        target_switch_if_name         = "xe-0/0/2"
        target_switch_if_transform_id = 2
        group_label                   = "bond0"
        lag_mode                      = "lacp_active"
      },
      {
        leaf_label                    = "Leaf2"
        target_switch_if_name         = "xe-0/0/2"
        target_switch_if_transform_id = 2
        group_label                   = "bond0"
        lag_mode                      = "lacp_active"
      },
    ]
    vns = ["Vlan-100", "Vlan-200"]
  },
  {
    name      = "Server_Git"
    hostname  = "Server-Git"
    link_tags = ["server_git"]
    links = [
      {
        leaf_label                    = "Leaf1"
        target_switch_if_name         = "xe-0/0/20"
        target_switch_if_transform_id = 2
        group_label                   = "bond0"
        lag_mode                      = "lacp_active"
      },
      {
        leaf_label                    = "Leaf2"
        target_switch_if_name         = "xe-0/0/20"
        target_switch_if_transform_id = 2
        group_label                   = "bond0"
        lag_mode                      = "lacp_active"
      },
    ]
    vns = ["Vlan-150"]
  },
  {
    name      = "FW"
    hostname  = "FW"
    link_tags = ["FW"]
    links = [
      {
        leaf_label                    = "Border1"
        target_switch_if_name         = "et-0/0/24"
        target_switch_if_transform_id = 1
        group_label                   = "bond0"
        lag_mode                      = "lacp_active"
      },
      {
        leaf_label                    = "Border2"
        target_switch_if_name         = "et-0/0/24"
        target_switch_if_transform_id = 1
        group_label                   = "bond0"
        lag_mode                      = "lacp_active"
      },
    ]
    vns = ["Vlan-10", "Vlan-20"]
  },
]
