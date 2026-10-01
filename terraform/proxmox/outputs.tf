output "k3s_master_ip" {
  value = proxmox_virtual_environment_vm.k3s_master.ipv4_addresses
}

output "k3s_worker_ip" {
  value = proxmox_virtual_environment_vm.k3s_worker.ipv4_addresses
}

output "infra_ip" {
  value = proxmox_virtual_environment_vm.infra.ipv4_addresses
}
