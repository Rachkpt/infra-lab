# Phase 2 — k3s + ArgoCD (GitOps)

## Cluster k3s

Installation minimale, sans configuration particuliere (le defaut suffit
pour un lab a 2 noeuds).

**Control plane** (`k3s-master`, 10.10.10.10) :
```bash
curl -sfL https://get.k3s.io | sh -
sudo cat /var/lib/rancher/k3s/server/node-token   # pour le worker
```

**Worker** (`k3s-worker`, 10.10.10.11) :
```bash
curl -sfL https://get.k3s.io | K3S_URL=https://10.10.10.10:6443 K3S_TOKEN=<token> sh -
```

Verification :
```bash
sudo kubectl get nodes -o wide
```

k3s installe `kubectl` comme symlink vers son propre binaire — pas besoin
d'installer kubectl separement sur les VMs.

## ArgoCD

Installation via les manifests officiels (namespace dedie) :
```bash
sudo kubectl create namespace argocd
sudo kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Mot de passe admin initial :
```bash
sudo kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```
(Ce secret initial peut etre supprime une fois le mot de passe change
depuis l'UI — pas encore fait dans ce lab.)

### Acces au dashboard

Pas d'Ingress/Traefik interne configure devant ArgoCD pour l'instant,
acces via `kubectl port-forward` :
```bash
sudo kubectl -n argocd port-forward --address 0.0.0.0 svc/argocd-server 8080:443
```
Puis depuis une machine qui a une route vers `10.10.10.0/24` :
`https://10.10.10.10:8080` (certificat auto-signe, login `admin`).

## Premiere application (GitOps)

`k8s/apps/hello-world/` contient les manifests bruts (Deployment +
Service, image `nginxdemos/hello`). `k8s/argocd/hello-world-app.yaml`
est la ressource `Application` ArgoCD qui pointe vers ce dossier dans
**ce meme depot** (`repoURL` = ce repo GitHub, `path` =
`k8s/apps/hello-world`), avec sync automatique (`automated.prune` +
`selfHeal`).

Application du manifeste (une seule fois, ArgoCD gere ensuite tout
seul) :
```bash
sudo kubectl apply -f https://raw.githubusercontent.com/Rachkpt/infra-lab/main/k8s/argocd/hello-world-app.yaml
```

Verification :
```bash
sudo kubectl -n argocd get applications
sudo kubectl get pods -n default
```

**Workflow GitOps valide** : toute modification des fichiers sous
`k8s/apps/hello-world/` poussee sur `main` est automatiquement reprise
par ArgoCD (grace a `selfHeal`/`automated` sync) sans intervention
manuelle sur le cluster.

## Limites actuelles / a faire

- Pas encore de vraie exposition HTTP publique des apps k3s (seulement
  acces interne au reseau Proxmox ou via port-forward). A relier au
  Traefik de `wg-gateway` (cf. note dans
  [phase1-traefik-dns.md](phase1-traefik-dns.md)) ou au Traefik embarque
  de k3s.
- Pas d'IAM/RBAC ArgoCD affine, pas de SSO — acceptable pour un lab
  perso.
- Pas encore de `k8s/argocd/` structure "app of apps" — chaque nouvelle
  app demandera son propre fichier `Application` pour l'instant.
