# ──────────────────────────────────────
# int-net 포트 (K3s VMs) - default SG 사용
# ──────────────────────────────────────
resource "openstack_networking_port_v2" "k3s_master" {
  name           = "k3s-master-port"
  network_id     = openstack_networking_network_v2.int_net.id
  admin_state_up = true

  security_group_ids = [openstack_networking_secgroup_v2.default.id]

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.int_subnet.id
    ip_address = "10.10.10.170"
  }
}

resource "openstack_networking_port_v2" "k3s_worker_1" {
  name           = "k3s-worker-1-port"
  network_id     = openstack_networking_network_v2.int_net.id
  admin_state_up = true

  security_group_ids = [openstack_networking_secgroup_v2.default.id]

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.int_subnet.id
    ip_address = "10.10.10.165"
  }
}

resource "openstack_networking_port_v2" "k3s_worker_2" {
  name           = "k3s-worker-2-port"
  network_id     = openstack_networking_network_v2.int_net.id
  admin_state_up = true

  security_group_ids = [openstack_networking_secgroup_v2.default.id]

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.int_subnet.id
    ip_address = "10.10.10.195"
  }
}

# ──────────────────────────────────────
# vxlan-net 포트 (Harbor, Backup) - port_security 비활성화
# ──────────────────────────────────────
resource "openstack_networking_port_v2" "harbor" {
  name               = "harbor-vxlan-port"
  network_id         = openstack_networking_network_v2.vxlan_net.id
  admin_state_up     = true
  port_security_enabled = false

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.vxlan_subnet.id
    ip_address = "10.10.20.4"
  }
}

resource "openstack_networking_port_v2" "backup" {
  name               = "backup-port"
  network_id         = openstack_networking_network_v2.vxlan_net.id
  admin_state_up     = true
  port_security_enabled = false

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.vxlan_subnet.id
    ip_address = "10.10.20.5"
  }
}
