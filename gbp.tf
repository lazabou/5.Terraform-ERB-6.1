########################
#  GBP — Variables     #
########################

variable "gbp_policy_set" {
  description = "GBP inter-tag policy matrix. Set to null to skip GBP deployment."
  type        = any
  default     = null
}

variable "gbp_classification_set" {
  description = "GBP IP classification: quarantine IPs and per-subnet tag terms."
  type        = any
  default     = null
}

########################
#  GBP Property Sets   #
########################

resource "apstra_property_set" "gbp_policy" {
  count = var.gbp_policy_set != null ? 1 : 0
  name  = "GBP-Policy"
  data  = jsonencode(var.gbp_policy_set)
}

resource "apstra_datacenter_property_set" "gbp_policy" {
  count             = var.gbp_policy_set != null ? 1 : 0
  blueprint_id      = apstra_datacenter_blueprint.terraform-pod1.id
  id                = apstra_property_set.gbp_policy[0].id
  sync_with_catalog = true

  depends_on = [apstra_property_set.gbp_policy]
}

resource "apstra_property_set" "gbp_classification" {
  count = var.gbp_classification_set != null ? 1 : 0
  name  = "GBP-Classification"
  data  = jsonencode(var.gbp_classification_set)
}

resource "apstra_datacenter_property_set" "gbp_classification" {
  count             = var.gbp_classification_set != null ? 1 : 0
  blueprint_id      = apstra_datacenter_blueprint.terraform-pod1.id
  id                = apstra_property_set.gbp_classification[0].id
  sync_with_catalog = true

  depends_on = [apstra_property_set.gbp_classification]
}

########################
#  GBP Configlet       #
########################

resource "apstra_configlet" "gbp" {
  count = (var.gbp_policy_set != null && var.gbp_classification_set != null) ? 1 : 0
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
        chassis {
            forwarding-options {
                vxlan-gbp-profile;
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
                        }
                    }
                    {% endfor %}
                {% endfor %}
            {% endfor %}
        {% endfor %}
                }
            }
        }

        {# ─── GBP-TAG-IP: assign GBP tag based on source IP ───
           - QUARANTINE term: tag 6666 for quarantined IPs
           - One term per gbp_ip_term entry: tag based on subnet membership
        ─────────────────────────────────────────────────────────────────── #}
        firewall {
            family any {
                filter GBP-TAG-IP {
                    micro-segmentation;
        {% if quarantine_ips %}
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
                        then gbp-tag {{quarantine_tag}};
                    }
        {% endif %}
        {% for term in gbp_ip_terms %}
                    term {{term.tag}} {
                        from {
                            ip-version {
                                ipv4 {
                                    address {
                                        {{term.subnet}};
                                    }
                                }
                            }
                        }
                        then gbp-tag {{term.tag}};
                    }
        {% endfor %}
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
  count                = (var.gbp_policy_set != null && var.gbp_classification_set != null) ? 1 : 0
  blueprint_id         = apstra_datacenter_blueprint.terraform-pod1.id
  catalog_configlet_id = apstra_configlet.gbp[0].id
  condition            = "label in ['Leaf1', 'Leaf2']"
  name                 = "GBP"

  depends_on = [
    apstra_configlet.gbp,
    apstra_datacenter_property_set.gbp_policy,
    apstra_datacenter_property_set.gbp_classification,
  ]
}
