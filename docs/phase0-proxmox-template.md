# Phase 0 — Proxmox : installation, template cloud-init, token API

## 1. VM VMware hebergeant Proxmox

- VM VMware : 3 vCPU, 10 Go RAM, 80 Go disque, reseau NAT
- Obligatoire : cocher **"Virtualize Intel VT-x/EPT or AMD-V/RVI"**
  (Processors settings) — sans ca, les VMs internes a Proxmox ne demarrent
  pas (`KVM virtualisation configured, but not available`).
- Si la case reste grisee alors que la VM est bien eteinte : conflit avec
  KVM sur l'hote Linux. Verifier et decharger les modules avant de rouvrir
  VMware :
  ```bash
  lsmod | grep kvm
  sudo modprobe -r kvm_intel   # ou kvm_amd
  sudo modprobe -r kvm
  ```

## 2. Template cloud-init Ubuntu (VM ID 9000)

Dans le Shell Proxmox :

```bash
cd /var/lib/vz/template/iso
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

qm create 9000 --name ubuntu-cloud-template --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 9000 noble-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1

qm template 9000
```

Verification : `qm list` doit montrer la VM `9000` avec le statut `stopped`.

Note : le bridge `vmbr0` est utilise ici car c'est le reseau par defaut au
moment de la creation du template ; les VMs clonees depuis ce template
(k3s-master, k3s-worker, infra) sont ensuite basculees sur `vmbr1` par
Terraform — voir [phase0-proxmox-internal-network.md](phase0-proxmox-internal-network.md).

## 3. Utilisateur + token API Proxmox (pour Terraform)

Dans l'interface web Proxmox (`https://<IP-proxmox>:8006`) :

1. **Datacenter → Permissions → Roles → Create**
   - Nom : `TerraformProv`
   - Privileges : `VM.Allocate`, `VM.Clone`, `VM.Config.*`, `VM.PowerMgmt`,
     `VM.Audit`, `Datastore.AllocateSpace`, `Datastore.Audit`,
     `Pool.Allocate`, `SDN.Use`
   - (`VM.PowerMgmt` est facile a oublier — sans elle, Terraform clone les
     VMs mais ne peut pas les demarrer, erreur `403 Permission check
     failed .../VM.PowerMgmt`)

2. **Datacenter → Permissions → Users → Add**
   - User name : juste `terraform-prov` (sans `@realm` — le realm se
     choisit dans le menu deroulant a cote, sinon on obtient un username
     du type `terraform-prov@pve@pve`, ce qui casse l'authentification du
     token avec une erreur `401`)
   - Realm : `Proxmox VE authentication server` (pve)

3. **Datacenter → Permissions → Add → User Permission**
   - Path : `/`, User : `terraform-prov@pve`, Role : `TerraformProv`,
     Propagate : coche

4. **Datacenter → Permissions → API Tokens → Add**
   - User : `terraform-prov@pve`, Token ID : `terraform`
   - **Decoche "Privilege Separation"** (sinon le token n'a aucun droit
     meme si l'utilisateur en a)
   - Copier le Token ID complet (`terraform-prov@pve!terraform`) et le
     secret affiche une seule fois

Ces valeurs vont dans `terraform/proxmox/terraform.tfvars` (jamais commite,
voir `terraform.tfvars.example`).

## Pieges rencontres (resume)

| Symptome | Cause | Fix |
|---|---|---|
| `401 Authentication failed` | Username mal forme (`user@realm@realm`) | Recreer l'utilisateur avec juste le nom, realm a part |
| `403 .../VM.PowerMgmt` | Role incomplet | Ajouter `VM.PowerMgmt` au role |
| `KVM virtualisation configured, but not available` | Virtualisation imbriquee desactivee | Cocher VT-x/EPT dans VMware + decharger KVM sur l'hote |
| `terraform destroy` bloque 10+ min | Image cloud-init sans ACPI shutdown propre | `stop_on_destroy = true` dans la ressource VM |
| VMs sans IP (DHCP request sans reponse, verifie au `tcpdump`) | NAT VMware ne repond pas aux MAC des VMs imbriquees | Reseau interne `vmbr1` + `dnsmasq` sur Proxmox (voir doc reseau) |
| Terraform bloque en attente de l'agent QEMU | `qemu-guest-agent` absent de l'image cloud-init | IP fixes + `agent.enabled = false` |
