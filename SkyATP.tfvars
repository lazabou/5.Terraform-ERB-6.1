vrfs = [
  {
    name                   = "Internal_VRF"
    default_route_next_hop = "10.0.10.253"
    default_route_leaf     = ["Leaf1", "Leaf2"]
  },
]

vns = [
  {
    name                 = "Vlan-100"
    vlan_id              = 100
    vrf_name             = "Internal_VRF"
    ipv4_virtual_gateway = "10.0.100.1"
    ipv4_subnet          = "10.0.100.0/24"
    bindings             = ["Leaf1"]
  },
  {
    name                 = "Vlan-200"
    vlan_id              = 200
    vrf_name             = "Internal_VRF"
    ipv4_virtual_gateway = "10.0.200.1"
    ipv4_subnet          = "10.0.200.0/24"
    bindings             = ["Leaf1"]
  },
  {
    name                 = "Vlan-10"
    vlan_id              = 10
    vrf_name             = "Internal_VRF"
    ipv4_virtual_gateway = "10.0.10.1"
    ipv4_subnet          = "10.0.10.0/24"
    bindings             = ["Border1", "Leaf1"]
  },
  {
    name                 = "Vlan-30"
    vlan_id              = 30
    vrf_name             = "Internal_VRF"
    bindings             = ["Border1", "Leaf1" ]
  },
]

generic_systems = [
  {
    name      = "Server14"
    hostname  = "Server14"
    link_tags = ["server14"]
    tags      = ["gbp_100", "gbp_200"]
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
    vns = ["Vlan-100", "Vlan-200", "Vlan-30", "Vlan-10"]
  },
  {
    name      = "Server10"
    hostname  = "Server10"
    link_tags = ["server10"]
    tags      = ["gbp_100", "gbp_200"]
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
    vns = ["Vlan-100", "Vlan-200", "Vlan-30", "Vlan-10"]
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
    vns = ["Vlan-30"]
  },
]

gbp_property_set = {
  gbp_policy = [
    {
      "6666" = [
        { "100"  = "discard" },
        { "200"  = "discard" },
        { "6666" = "discard" },
      ]
    },
    {
      "100" = [
        { "100"  = "accept"  },
        { "200"  = "accept"  },
        { "6666" = "discard" },
      ]
    },
    {
      "200" = [
        { "200"  = "accept"  },
        { "100"  = "accept"  },
        { "6666" = "discard" },
      ]
    },
  ]
  quarantine_ips = ["10.0.200.101"]
}
