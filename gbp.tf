########################
#  GBP — Variables     #
########################

variable "gbp_property_set" {
  description = "GBP policy matrix (gbp_policy) and quarantine IPs (quarantine_ips). Set to null to skip GBP deployment."
  type        = any
  default     = null
}

########################
#  GBP Property Set    #
########################

resource "apstra_property_set" "gbp" {
  count = var.gbp_property_set != null ? 1 : 0
  name  = "GBP"
  data  = jsonencode(var.gbp_property_set)
}

resource "apstra_datacenter_property_set" "gbp" {
  count             = var.gbp_property_set != null ? 1 : 0
  blueprint_id      = apstra_datacenter_blueprint.terraform-pod1.id
  id                = apstra_property_set.gbp[0].id
  sync_with_catalog = true

  depends_on = [apstra_property_set.gbp]
}

########################
#  GBP Configlet       #
########################

resource "apstra_configlet" "gbp" {
  count = var.gbp_property_set != null ? 1 : 0
  name  = "GBP"

  generators = [
    {
      config_style  = "junos"
      section       = "top_level_hierarchical"
      template_text = <<-EOT
        {# ═════════════════════════════════════════════════════════════════
           GBP CONFIGLET
           Interface tag format : gbp_<id>  ->  vlan-id <id>, gbp-tag <id>
           Tag 6666 is reserved for quarantine (above VLAN range)
           ═════════════════════════════════════════════════════════════════ #}

        {# ─── Enable GBP mac-ip-inter-tagging globally ─── #}
        forwarding-options {
            evpn-vxlan {
                gbp {
                    mac-ip-inter-tagging;
                }
            }
        }

        {# ─── MSEG: inter-tag traffic policy (src/dst tag enforcement) ───
           gbp_policy is a list of dicts, not a dict directly.
           Iteration pattern:
             - outer loop: iterate over list entries
             - mid loop:   unpack {src_tag: dst_list} from each entry
             - inner loop: iterate over dst_list (also a list of dicts)
             - innermost:  unpack {dst_tag: action} from each dst entry
           Actions: accept or discard. Counter created per term.
        ─────────────────────────────────────────────────────────────────── #}
        firewall {
            family any {
                filter MSEG {
        {% for entry in gbp_policy %}
            {% for src_tag, dst_list in entry.items() %}
                {% for dst_entry in dst_list %}
                    {% for dst_tag, action in dst_entry.items() %}
                    term From{{src_tag}}-To{{dst_tag}} {
                        from {
                            gbp-src-tag {{src_tag}};
                            gbp-dst-tag {{dst_tag}};
                        }
                        then {
                            {{action}};
                            count {{src_tag}}-To{{dst_tag}};
                        }
                    }
                    {% endfor %}
                {% endfor %}
            {% endfor %}
        {% endfor %}
                }
            }
        }

        {# ─── GBP-TAG-VLAN: assign GBP tag based on ingress interface + vlan ───
           Two cases:
             - LAG member (is_port_channel_member=true)  -> use part_of (ae)
             - Standalone (is_port_channel_member=false) -> use intfName
           Deduplication via data.seen prevents duplicate terms when
           multiple physical members belong to the same ae.
           All local variables use namespace() to avoid Apstra intercepting
           standalone {% set %} as missing property set values.
        ─────────────────────────────────────────────────────────────────── #}
        {% set data = namespace(seen=[], current_key='') %}
        firewall {
            family any {
                filter GBP-TAG-VLAN {
                    micro-segmentation;
        {% for if_name, if_param in interface.items() %}
            {% for tag in if_param['tags'] %}
                {% if tag.startswith('gbp_') %}
                    {% if if_param['is_port_channel_member'] %}
                        {# LAG member: use ae interface name from part_of #}
                        {% set data.current_key = if_param['part_of'] ~ '-' ~ tag %}
                        {% if data.current_key not in data.seen %}
                            {% set data.seen = data.seen + [data.current_key] %}
                    term TAG{{ tag | replace('gbp_', '') }}-{{if_param['part_of']}} {
                        from {
                            interface {{if_param['part_of']}}.0;
                            vlan-id {{ tag | replace('gbp_', '') }};
                        }
                        then gbp-tag {{ tag | replace('gbp_', '') }};
                    }
                        {% endif %}
                    {% else %}
                        {# Standalone interface: use intfName directly #}
                        {% set data.current_key = if_param['intfName'] ~ '-' ~ tag %}
                        {% if data.current_key not in data.seen %}
                            {% set data.seen = data.seen + [data.current_key] %}
                    term TAG{{ tag | replace('gbp_', '') }}-{{if_param['intfName']}} {
                        from {
                            interface {{if_param['intfName']}}.0;
                            vlan-id {{ tag | replace('gbp_', '') }};
                        }
                        then gbp-tag {{ tag | replace('gbp_', '') }};
                    }
                        {% endif %}
                    {% endif %}
                {% endif %}
            {% endfor %}
        {% endfor %}
                }
            }
        }

        {# ─── GBP-TAG-IP: assign tag 6666 to quarantined IPs ───
           Separate filter required by Junos: IP-based and VLAN-based
           GBP tag assignment cannot coexist in the same filter.
        ─────────────────────────────────────────────────────────────────── #}
        firewall {
            family any {
                filter GBP-TAG-IP {
                    micro-segmentation;
                    term QUARANTINE {
                        from {
                            ip-version {
                                ipv4 {
                                    address {
        {% for ip in quarantine_ips %}
                                        {{ip}}/32;
        {% endfor %}
                                    }
                                }
                            }
                        }
                        then gbp-tag 6666;
                    }
                }
            }
        }
      EOT
    }
  ]
}

########################
#  Assign to Blueprint #
########################

resource "apstra_datacenter_configlet" "gbp" {
  count                = var.gbp_property_set != null ? 1 : 0
  blueprint_id         = apstra_datacenter_blueprint.terraform-pod1.id
  catalog_configlet_id = apstra_configlet.gbp[0].id
  condition            = "role in ['leaf', 'border_leaf']"
  name                 = "GBP"

  depends_on = [
    apstra_configlet.gbp,
    apstra_datacenter_property_set.gbp,
  ]
}
