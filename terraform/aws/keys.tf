# Cle SSH generee par Terraform, partagee par les 3 VMs du lab.
# La cle publique est enregistree comme Key Pair AWS, la cle privee
# est ecrite en local (infra-lab-key.pem, ignore par .gitignore via *.pem).
resource "tls_private_key" "infra_lab" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "infra_lab" {
  key_name   = "infra-lab-key"
  public_key = tls_private_key.infra_lab.public_key_openssh
}

resource "local_sensitive_file" "infra_lab_private_key" {
  content         = tls_private_key.infra_lab.private_key_pem
  filename        = "${path.module}/infra-lab-key.pem"
  file_permission = "0600"
}
