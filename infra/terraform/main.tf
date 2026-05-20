terraform {
required_providers {
    openstack = {
      source  = "hashicorp/openstack"
      version = "3.4.0"
    }
  }
  required_version = ">= 1.0"
}

provider "openstack" {
  auth_url    = var.auth_url
  tenant_name = var.project_name
  user_name   = var.user_name
  password    = var.password
  domain_name = var.domain_name
  region      = var.region
}

variable "auth_url" {
  type        = string
  description = "OpenStack Identity API endpoint"
}

variable "user_name" {
  type        = string
  description = "OpenStack Username"
}

variable "password" {
  type        = string
  description = "OpenStack Password"
  sensitive   = true
}

variable "project_name" {
  type        = string
  description = "OpenStack Project (Tenant)"
}

variable "domain_name" {
  type        = string
  default     = "Default"
  description = "OpenStack domain name"
}

variable "region" {
  type        = string
  default     = "RegionOne"
  description = "OpenStack region"
}

variable "network_name" {
  type        = string
  description = "Name of the network"
}

variable "security_group" {
  type        = string
  default     = "default"
  description = "OpenStack security group name"
}

variable "image_name" {
  type        = string
  default     = "Ubuntu 22.04"
  description = "Name of the OS image"
}

variable "flavor_name" {
  type        = string
  default     = "m1.small"
  description = "OpenStack VM flavor"
}

variable "ssh_public_key" {
  type        = string
  description = "public ssh key"
}

variable "instance_name" {
  type        = string
  default     = "tripplanner-vm"
}

# Получаем id нужной сети
data "openstack_networking_network_v2" "network" {
  name = var.network_name
}

# Получаем id нужного публичного образа
data "openstack_images_image_v2" "image" {
  name = var.image_name
}

resource "openstack_compute_keypair_v2" "keypair" {
  name       = "${var.instance_name}-key"
  public_key = var.ssh_public_key
}

resource "openstack_compute_instance_v2" "vm" {
  name            = var.instance_name
  image_id        = data.openstack_images_image_v2.image.id
  flavor_name     = var.flavor_name
  key_pair        = openstack_compute_keypair_v2.keypair.name
  security_groups = [var.security_group]

  network {
    uuid = data.openstack_networking_network_v2.network.id
  }

  # Автоматически назначит floating ip (опция, смотри ниже)
}

# --- Блок назначения публичного IP ---
resource "openstack_networking_floatingip_v2" "fip" {
  pool = "public-ext" # Имя пула публичных адресов (может отличаться, often 'ext-net'/'public')
}

resource "openstack_networking_floatingip_associate_v2" "fip_assoc" {
  floatingip_id = openstack_networking_floatingip_v2.fip.id
  port_id       = openstack_compute_instance_v2.vm.network.0.port
}

output "instance_id" {
  value = openstack_compute_instance_v2.vm.id
}

output "instance_name" {
  value = openstack_compute_instance_v2.vm.name
}

output "instance_ip" {
  description = "external ip"
  value       = openstack_networking_floatingip_v2.fip.address
}

output "instance_internal_ip" {
  value = openstack_compute_instance_v2.vm.network[0].fixed_ip_v4
}
