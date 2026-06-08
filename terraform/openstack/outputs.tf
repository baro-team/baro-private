output "k3s_master_ip" {
  description = "K3s master fixed IP"
  value       = openstack_networking_port_v2.k3s_master.all_fixed_ips[0]
}

output "k3s_worker_1_ip" {
  description = "K3s worker-1 fixed IP"
  value       = openstack_networking_port_v2.k3s_worker_1.all_fixed_ips[0]
}

output "k3s_worker_2_ip" {
  description = "K3s worker-2 fixed IP"
  value       = openstack_networking_port_v2.k3s_worker_2.all_fixed_ips[0]
}

output "harbor_ip" {
  description = "Harbor VM fixed IP"
  value       = openstack_networking_port_v2.harbor.all_fixed_ips[0]
}

output "harbor_url" {
  description = "Harbor registry URL"
  value       = "http://${openstack_networking_port_v2.harbor.all_fixed_ips[0]}"
}


output "backup_ip" {
  description = "Backup VM fixed IP"
  value       = openstack_networking_port_v2.backup.all_fixed_ips[0]
}

output "minio_api_url" {
  description = "MinIO API endpoint"
  value       = "http://${openstack_networking_port_v2.backup.all_fixed_ips[0]}:9000"
}

output "minio_console_url" {
  description = "MinIO Console endpoint"
  value       = "http://${openstack_networking_port_v2.backup.all_fixed_ips[0]}:9001"
}
