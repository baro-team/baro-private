# ──────────────────────────────────────
# int-net (external / flat)
# ──────────────────────────────────────
resource "openstack_networking_network_v2" "int_net" {
  name           = "int-net"
  admin_state_up = true
  external       = true
}

resource "openstack_networking_subnet_v2" "int_subnet" {
  name            = "int-subnet"
  network_id      = openstack_networking_network_v2.int_net.id
  cidr            = var.int_net_cidr
  gateway_ip      = var.int_net_gateway
  ip_version      = 4
  enable_dhcp     = true
  dns_nameservers = var.dns_nameservers

  allocation_pool {
    start = var.int_net_pool_start
    end   = var.int_net_pool_end
  }
}

resource "openstack_networking_subnet_route_v2" "vxlan_route" {
  subnet_id        = openstack_networking_subnet_v2.int_subnet.id
  destination_cidr = "10.10.20.0/24"
  next_hop         = "10.10.10.2"
}


# ──────────────────────────────────────
# vxlan-net (internal / vxlan)
# ──────────────────────────────────────
resource "openstack_networking_network_v2" "vxlan_net" {
  name           = "vxlan-net"
  admin_state_up = true
  external       = false
}

resource "openstack_networking_subnet_v2" "vxlan_subnet" {
  name            = "vxlan-subnet"
  network_id      = openstack_networking_network_v2.vxlan_net.id
  cidr            = var.vxlan_net_cidr
  gateway_ip      = var.vxlan_net_gateway
  ip_version      = 4
  enable_dhcp     = true
  dns_nameservers = var.dns_nameservers

  allocation_pool {
    start = "10.10.20.2"
    end   = "10.10.20.254"
  }
}

# ──────────────────────────────────────
# Router
# ──────────────────────────────────────
resource "openstack_networking_router_v2" "internal_router" {
  name                = "internal-router"
  admin_state_up      = true
  external_network_id = openstack_networking_network_v2.int_net.id
}

resource "openstack_networking_router_interface_v2" "vxlan_interface" {
  router_id = openstack_networking_router_v2.internal_router.id
  subnet_id = openstack_networking_subnet_v2.vxlan_subnet.id
}
