# Cle SSH generee par Terraform, injectee via cloud-init dans les 3 VMs.
# La cle privee est ecrite en local (infra-lab-proxmox-key.pem, ignore par .gitignore via *.pem).
resource "tls_private_key" "infra_lab" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "infra_lab_private_key" {
  content         = tls_private_key.infra_lab.private_key_pem
  filename        = "${path.module}/infra-lab-proxmox-key.pem"
  file_permission = "0600"
}
