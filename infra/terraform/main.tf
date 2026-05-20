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

# Получаем id нужной сети (по имени)
data "openstack_networking_network_v2" "network" {
  name = var.network_name
}

# Получаем id нужного публичного образа
data "openstack_images_image_v2" "image" {
  name = var.image_name
}

# Добавлен: создание отдельного порта для VM
resource "openstack_networking_port_v2" "port" {
  name       = "${var.instance_name}-port"
  network_id = data.openstack_networking_network_v2.network.id
  security_group_ids = [var.security_group] # если у тебя security_group — id, если name — см. ниже коммент
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

  # Теперь привязка не через uuid (network), а через порт
  network {
    port = openstack_networking_port_v2.port.id
  }
}

# --- Блок назначения публичного IP ---
resource "openstack_networking_floatingip_v2" "fip" {
  pool = "public-ext" # Имя пула публичных адресов (замени если требуется)
}

resource "openstack_networking_floatingip_associate_v2" "fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.fip.address
  port_id     = openstack_networking_port_v2.port.id
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
