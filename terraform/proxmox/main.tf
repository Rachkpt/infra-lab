resource "proxmox_virtual_environment_vm" "k3s_master" {
  name      = "k3s-master"
  node_name = var.proxmox_node
  vm_id     = 101

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = 20
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  stop_on_destroy = true

  agent {
    enabled = true
  }
}

resource "proxmox_virtual_environment_vm" "k3s_worker" {
  name      = "k3s-worker"
  node_name = var.proxmox_node
  vm_id     = 102

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 3072
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = 25
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  stop_on_destroy = true

  agent {
    enabled = true
  }
}

resource "proxmox_virtual_environment_vm" "infra" {
  name      = "infra"
  node_name = var.proxmox_node
  vm_id     = 103

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  cpu {
    cores = 1
  }

  memory {
    dedicated = 1536
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = 15
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  stop_on_destroy = true

  agent {
    enabled = true
  }
}
