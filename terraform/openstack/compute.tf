# ──────────────────────────────────────
# Boot Volumes (image → volume)
# ──────────────────────────────────────
data "openstack_images_image_v2" "ubuntu" {
  name        = var.image_name
  most_recent = true
}

resource "openstack_blockstorage_volume_v3" "k3s_master" {
  name              = "k3s-master-volume"
  size              = 40
  image_id          = data.openstack_images_image_v2.ubuntu.id
  availability_zone = var.volume_availability_zone
}

resource "openstack_blockstorage_volume_v3" "k3s_worker_1" {
  name              = "k3s-worker-1-volume"
  size              = 40
  image_id          = data.openstack_images_image_v2.ubuntu.id
  availability_zone = var.volume_availability_zone
}

resource "openstack_blockstorage_volume_v3" "k3s_worker_2" {
  name              = "k3s-worker-2-volume"
  size              = 40
  image_id          = data.openstack_images_image_v2.ubuntu.id
  availability_zone = var.volume_availability_zone
}

resource "openstack_blockstorage_volume_v3" "harbor" {
  name              = "harbor-volume"
  size              = 40
  image_id          = data.openstack_images_image_v2.ubuntu.id
  availability_zone = var.volume_availability_zone
}

resource "openstack_blockstorage_volume_v3" "backup" {
  name              = "backup-volume"
  size              = 100
  image_id          = data.openstack_images_image_v2.ubuntu.id
  availability_zone = var.volume_availability_zone
}

# ──────────────────────────────────────
# Instances
# ──────────────────────────────────────
resource "openstack_compute_instance_v2" "k3s_master" {
  name              = "k3s-master"
  flavor_id         = openstack_compute_flavor_v2.k3s_master.id
  key_pair          = var.keypair_name
  availability_zone = var.availability_zone_main

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.k3s_master.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = false
  }

  network {
    port = openstack_networking_port_v2.k3s_master.id
  }

  lifecycle {
    ignore_changes = [block_device]
  }
}

resource "openstack_compute_instance_v2" "k3s_worker_1" {
  name              = "k3s-worker-1"
  flavor_id         = openstack_compute_flavor_v2.k3s_worker.id
  key_pair          = var.keypair_name
  availability_zone = var.availability_zone_main

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.k3s_worker_1.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = false
  }

  network {
    port = openstack_networking_port_v2.k3s_worker_1.id
  }

  lifecycle {
    ignore_changes = [block_device]
  }
}

resource "openstack_compute_instance_v2" "k3s_worker_2" {
  name              = "k3s-worker-2"
  flavor_id         = openstack_compute_flavor_v2.k3s_worker.id
  key_pair          = var.keypair_name
  availability_zone = var.availability_zone_main

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.k3s_worker_2.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = false
  }

  network {
    port = openstack_networking_port_v2.k3s_worker_2.id
  }

  lifecycle {
    ignore_changes = [block_device]
  }
}

resource "openstack_compute_instance_v2" "harbor" {
  name              = "harbor"
  flavor_id         = openstack_compute_flavor_v2.harbor.id
  key_pair          = var.keypair_name
  availability_zone = var.availability_zone_compute

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.harbor.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = false
  }

  network {
    port = openstack_networking_port_v2.harbor.id
  }

  lifecycle {
    ignore_changes = [block_device]
  }
}

resource "openstack_compute_instance_v2" "backup" {
  name              = "backup"
  flavor_id         = openstack_compute_flavor_v2.backup.id
  key_pair          = var.keypair_name
  availability_zone = var.availability_zone_compute

  block_device {
    uuid                  = openstack_blockstorage_volume_v3.backup.id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = false
  }

  network {
    port = openstack_networking_port_v2.backup.id
  }

  lifecycle {
    ignore_changes = [block_device]
  }
}
