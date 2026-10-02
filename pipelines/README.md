<p>
  <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/github.svg" width="32" title="GitHub Actions" alt="GitHub Actions"/>
  <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/trivy.png" width="32" title="Trivy" alt="Trivy"/>
</p>

# 🔐 Pipelines

Le pipeline DevSecOps réel vit dans
[`.github/workflows/devsecops.yml`](../.github/workflows/devsecops.yml)
— GitHub Actions n'exécute que les workflows placés à cet endroit précis,
impossible de les faire fonctionner depuis `pipelines/`.

Ce dossier sert de référence/documentation pour le pipeline (voir aussi
[docs/phase3-devsecops-pipeline.md](../docs/phase3-devsecops-pipeline.md)).

**3 étapes, dans l'ordre** :
1. 🕵️ Gitleaks — scan de secrets sur tout l'historique Git
2. 🔎 Semgrep — analyse statique du code
3. 🛡️ Trivy — secrets + mauvaises configurations IaC
