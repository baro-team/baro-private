# ──────────────────────────────────────
# Default Security Group (managed)
# ──────────────────────────────────────
# OpenStack 기본 default SG는 자동 생성되므로 import하여 관리
# 기존 default SG의 규칙을 선언적으로 관리

resource "openstack_networking_secgroup_v2" "default" {
  name        = "default"
  description = "Default security group"
}

resource "openstack_networking_secgroup_rule_v2" "ingress_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.default.id
}

resource "openstack_networking_secgroup_rule_v2" "ingress_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.default.id
}

resource "openstack_networking_secgroup_rule_v2" "ingress_https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.default.id
}

resource "openstack_networking_secgroup_rule_v2" "ingress_k3s_api" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 6443
  port_range_max    = 6443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.default.id
}

resource "openstack_networking_secgroup_rule_v2" "ingress_kubelet" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 10250
  port_range_max    = 10250
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.default.id
}

resource "openstack_networking_secgroup_rule_v2" "ingress_nodeport" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 30000
  port_range_max    = 32767
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.default.id
}

resource "openstack_networking_secgroup_rule_v2" "ingress_wireguard" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 51820
  port_range_max    = 51820
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.default.id
}

resource "openstack_networking_secgroup_rule_v2" "ingress_icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.default.id
}

resource "openstack_networking_secgroup_rule_v2" "ingress_self_ipv4" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = openstack_networking_secgroup_v2.default.id
  security_group_id = openstack_networking_secgroup_v2.default.id
}

resource "openstack_networking_secgroup_rule_v2" "ingress_self_ipv6" {
  direction         = "ingress"
  ethertype         = "IPv6"
  remote_group_id   = openstack_networking_secgroup_v2.default.id
  security_group_id = openstack_networking_secgroup_v2.default.id
}

resource "openstack_networking_secgroup_rule_v2" "egress_ipv4" {
  direction         = "egress"
  ethertype         = "IPv4"
  security_group_id = openstack_networking_secgroup_v2.default.id
}

resource "openstack_networking_secgroup_rule_v2" "egress_ipv6" {
  direction         = "egress"
  ethertype         = "IPv6"
  security_group_id = openstack_networking_secgroup_v2.default.id
}
