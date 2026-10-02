# Phase 4 — Monitoring (Prometheus, Grafana, Loki, Alertmanager + Telegram)

## Stack (VM `monitoring`, AWS)

Docker Compose, fichiers dans [`monitoring/`](../monitoring/) :

```bash
sudo apt install -y docker.io docker-compose-v2
sudo systemctl enable --now docker
sudo usermod -aG docker ubuntu   # puis se reconnecter

git clone https://github.com/Rachkpt/infra-lab.git
cd infra-lab/monitoring
cp alertmanager/alertmanager.yml.example alertmanager/alertmanager.yml
# editer alertmanager.yml : bot_token + chat_id Telegram (jamais commite)
docker compose up -d
```

4 conteneurs : `prometheus` (9090), `grafana` (3000), `loki` (3100),
`alertmanager` (9093). Grafana a ses datasources (Prometheus + Loki)
pre-provisionnees automatiquement via
`monitoring/grafana/provisioning/datasources/`.

## node_exporter (metriques systeme, sur les 5 autres VMs)

Meme procedure sur `wg-gateway`, `runner-ci`, `k3s-master`, `k3s-worker`,
`infra` :

```bash
curl -sSL https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz -o /tmp/node_exporter.tar.gz
tar xzf /tmp/node_exporter.tar.gz -C /tmp
sudo mv /tmp/node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/
sudo useradd --no-create-home --shell /usr/sbin/nologin node_exporter
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<'EOF'
[Unit]
Description=Node Exporter
After=network.target
[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
```

Prometheus scrape ces 5 cibles (`monitoring/prometheus/prometheus.yml`),
via IP privees AWS (meme VPC) et IP Proxmox (a travers le tunnel
WireGuard deja en place depuis la Phase 1).

Dashboard Grafana : **Import → ID `1860`** ("Node Exporter Full"),
datasource Prometheus — selecteur "Nodename"/"Instance" en haut pour
basculer entre les 5 VMs.

## Loki + Promtail (logs)

Promtail installe sur les 5 VMs (+ `monitoring` elle-meme), lit le
journal systemd et l'envoie a Loki :

```bash
curl -sSL https://github.com/grafana/loki/releases/download/v3.1.1/promtail-linux-amd64.zip -o /tmp/promtail.zip
sudo apt-get install -y unzip
unzip -o /tmp/promtail.zip -d /tmp
sudo mv /tmp/promtail-linux-amd64 /usr/local/bin/promtail
sudo mkdir -p /etc/promtail /var/lib/promtail
# config dans /etc/promtail/config.yml : scrape_configs.journal,
# clients -> http://10.0.1.45:3100/loki/api/v1/push (IP privee de monitoring)
sudo systemctl enable --now promtail
```

Verification : `curl http://localhost:3100/loki/api/v1/label/host/values`
sur `monitoring` doit lister toutes les VMs.

## Alertmanager + Telegram

Regles d'alerte dans `monitoring/prometheus/alert-rules.yml` :
`InstanceDown` (2 min), `HighCPUUsage` / `HighMemoryUsage` (>90%, 5 min).

`monitoring/alertmanager/alertmanager.yml` (non commite, cree depuis le
`.example`) route tout vers un bot Telegram. Test manuel sans attendre
qu'une vraie alerte se declenche :

```bash
curl -XPOST http://localhost:9093/api/v2/alerts -H "Content-Type: application/json" \
  -d '[{"labels":{"alertname":"TestAlert","severity":"critical"},"annotations":{"summary":"Test","description":"..."}}]'
```

## Incident : remplacement des 3 VMs AWS en pleine Phase 4

En lancant un `terraform apply` (juste pour une regle de security group),
les 3 instances AWS (`wg-gateway`, `monitoring`, `runner-ci`) ont ete
**recreees** d'un coup — nouvel ID, nouvelle IP privee, nouvelle IP
publique dynamique (l'Elastic IP de `wg-gateway` est restee la seule
chose stable).

Cause reelle : un correctif de securite plus ancien
(`root_block_device.encrypted = true`, voir
[phase3-devsecops-pipeline.md](phase3-devsecops-pipeline.md)) n'avait
jamais ete reellement applique avant cet `apply`. Or chiffrer le disque
racine d'une instance existante est impossible en place — AWS/Terraform
doit detruire puis recreer l'instance. Comme ce changement concernait
les 3 instances, les 3 sont parties en meme temps.

Consequence : tout ce qui avait ete installe a la main sur ces VMs
(WireGuard + Traefik sur `wg-gateway`, le runner GitHub Actions + les 3
scanners sur `runner-ci`, Docker + toute la stack monitoring) a ete
perdu et reconstruit entierement — cles WireGuard regenerees, nouveau
token de registration du runner, nouveau `docker compose up`.

**Lecon** : un attribut qui force le remplacement (`ForceNew` dans le
provider Terraform — `ami`, `root_block_device.encrypted`,
`availability_zone`, etc.) doit etre traite comme une operation
destructive et appliquee volontairement, pas merge en passant avec
d'autres changements anodins (ici une regle de security group). A
l'avenir : `terraform plan` et verifier explicitement l'absence de
`-/+ destroy and then create replacement` avant tout `apply`, surtout
quand plusieurs commits se sont accumules sans etre appliques.

**Fragilite additionnelle identifiee** : les IP privees AWS sont codees
en dur a plusieurs endroits (`prometheus.yml`, moniteurs Uptime Kuma).
Un futur remplacement d'instance cassera a nouveau ces references. A
corriger plus tard avec soit des IP privees fixes (`private_ip` explicite
dans `aws_instance`), soit une zone DNS privee (Route 53 private hosted
zone) resolvant des noms stables vers les instances.
