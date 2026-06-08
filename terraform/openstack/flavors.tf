resource "openstack_compute_flavor_v2" "k3s_master" {
  name      = "k3s-master"
  ram       = 8192
  vcpus     = 4
  disk      = 40
  is_public = true
}

resource "openstack_compute_flavor_v2" "k3s_worker" {
  name      = "k3s-worker"
  ram       = 12288
  vcpus     = 4
  disk      = 40
  is_public = true
}

resource "openstack_compute_flavor_v2" "harbor" {
  name      = "harbor"
  ram       = 8192
  vcpus     = 4
  disk      = 40
  is_public = true
}

resource "openstack_compute_flavor_v2" "backup" {
  name      = "backup"
  ram       = 4096
  vcpus     = 4
  disk      = 100
  is_public = true
}

resource "openstack_compute_flavor_v2" "lightweight" {
  name      = "lightweight"
  ram       = 2048
  vcpus     = 2
  disk      = 20
  is_public = true
}
