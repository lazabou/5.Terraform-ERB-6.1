vrfs = [
  {
    name = "BO"
  },
]

vns = [
  {
    name     = "Vlan-100"
    vlan_id  = 100
    vrf_name = "BO"
    bindings = ["Leaf1", "Border1"]
  },
  {
    name     = "Vlan-200"
    vlan_id  = 200
    vrf_name = "BO"
    bindings = ["Leaf1", "Border1"]
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
    vns = ["Vlan-100", "Vlan-200"]
  },
]
