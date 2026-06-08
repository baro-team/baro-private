# ──────────────────────────────────────
# OpenStack Provider
# ──────────────────────────────────────
variable "auth_url" {
  description = "OpenStack Keystone auth URL"
  type        = string
  default     = "http://192.168.203.187:5000/v3"
}

variable "user_name" {
  description = "OpenStack username"
  type        = string
  default     = "admin"
}

variable "password" {
  description = "OpenStack password"
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "OpenStack project name"
  type        = string
  default     = "admin"
}

variable "domain_name" {
  description = "OpenStack domain name"
  type        = string
  default     = "Default"
}

variable "region" {
  description = "OpenStack region"
  type        = string
  default     = "RegionOne"
}

# ──────────────────────────────────────
# Network
# ──────────────────────────────────────
variable "int_net_cidr" {
  description = "int-net subnet CIDR"
  type        = string
  default     = "10.10.10.0/24"
}

variable "int_net_gateway" {
  description = "int-net gateway IP"
  type        = string
  default     = "10.10.10.1"
}

variable "int_net_pool_start" {
  description = "int-net DHCP pool start"
  type        = string
  default     = "10.10.10.100"
}

variable "int_net_pool_end" {
  description = "int-net DHCP pool end"
  type        = string
  default     = "10.10.10.200"
}

variable "vxlan_net_cidr" {
  description = "vxlan-net subnet CIDR"
  type        = string
  default     = "10.10.20.0/24"
}

variable "vxlan_net_gateway" {
  description = "vxlan-net gateway IP"
  type        = string
  default     = "10.10.20.1"
}

variable "dns_nameservers" {
  description = "DNS nameservers for subnets"
  type        = list(string)
  default     = ["8.8.8.8"]
}

# ──────────────────────────────────────
# Compute
# ──────────────────────────────────────
variable "image_name" {
  description = "Base OS image name"
  type        = string
  default     = "ubuntu-22.04"
}

variable "keypair_name" {
  description = "SSH keypair name"
  type        = string
  default     = "mykey"
}

variable "availability_zone_main" {
  description = "AZ:host for main compute node"
  type        = string
  default     = "nova:openstack-aio"
}

variable "availability_zone_compute" {
  description = "AZ:host for secondary compute node"
  type        = string
  default     = "nova:openstack-compute"
}

variable "volume_availability_zone" {
  description = "Cinder volume availability zone"
  type        = string
  default     = "nova"
}
