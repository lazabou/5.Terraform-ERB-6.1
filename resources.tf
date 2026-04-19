## Create an IPv4 resource pools for loopbacks and links
resource "apstra_ipv4_pool" "terraform-lb"{
  name = "Terraform-Loopback"
  subnets = [
    { network = "10.0.0.0/24" },
  ]
}

resource "apstra_ipv4_pool" "terraform-link"{
  name = "Terraform-Link"
  subnets = [
    { network = "10.1.0.0/24" },
  ]
}

# Create an ASN resource pool according to the instructions in the lab guide.
resource "apstra_asn_pool" "terraform-asn"{
  name = "Terraform-ASN"
  ranges = [
    {
      first = 65100
      last  = 65199
    }
  ]
}

resource "apstra_vni_pool" "terraform-vni" {
  name = "Terraform-vni"
  ranges = [
  {
    first = 10000
    last  = 19999
  }
  ]
}
