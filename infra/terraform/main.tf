terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.130"
    }
  }
  required_version = ">= 1.0"
}

provider "yandex" {
  folder_id = var.folder_id
}

variable "folder_id" {
  type        = string
  description = "folder id"
}

variable "subnet_id" {
  type        = string
  description = "subnet id"
  default     = "e2l8upt32adb7kjindkt"
}

variable "security_group_id" {
  type        = string
  description = "security group id"
  default     = "enp92iphnc0bquh1mg9f"
}

variable "instance_name" {
  type    = string
  default = "tripplanner-vm"
}

variable "ssh_public_key" {
  type        = string
  description = "public ssh key"
}

data "yandex_vpc_subnet" "main" {
  subnet_id = var.subnet_id
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2404-lts"
}

resource "yandex_compute_instance" "vm" {
  name        = var.instance_name
  platform_id = "standard-v3"
  zone        = data.yandex_vpc_subnet.main.zone

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = var.subnet_id
    nat                = true
    security_group_ids = [var.security_group_id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }

  allow_stopping_for_update = true
}

output "instance_id" {
  value = yandex_compute_instance.vm.id
}

output "instance_name" {
  value = yandex_compute_instance.vm.name
}

output "instance_ip" {
  description = "external ip"
  value       = yandex_compute_instance.vm.network_interface[0].nat_ip_address
}

output "instance_internal_ip" {
  value = yandex_compute_instance.vm.network_interface[0].ip_address
}
