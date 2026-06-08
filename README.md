# DEV LAB Formation Docker #

Outillage **bash + Azure CLI** pour déployer depuis zéro l'infrastructure d'ateliers Docker sur Azure : réseau, image golden **Debian 13 + Docker**, VMs de session, puis déploiement du contenu pédagogique. Le dépôt contient aussi le contenu des 3 ateliers (`atelier_compose/`, `atelier_securisation/`, `atelier_swarm/`).

Tout est piloté par un seul fichier de configuration (`conf`) : changer de cible Azure (abonnement, région, taille de VM) ne touche que ce fichier, pas les scripts.

## Prérequis ##

- **Azure CLI** (`az`) et un abonnement Azure.
- **`sshpass`** (déploiement du contenu via SSH) et **`zip`** (génération des packages KiTTY).

## Configuration ##

Copier le template puis renseigner vos valeurs Azure :

```
cp conf.example conf
```

`conf` est ignoré par Git (il contient le mot de passe admin et l'identifiant d'abonnement). Tous les scripts le sourcent automatiquement.

## Workflow « from scratch » ##

Sur un abonnement Azure vierge, dans l'ordre :

### 1. Connexion ###

```
az login --use-device-code
az account set --subscription "$subscription"
```

### 2. Provisionner l'infrastructure ###

Idempotent (rejouable sans casse) : resource group, VNet + subnet partagé, NSG (entrant TCP 22/80/8080), Compute Gallery + définition d'image.

```
./provision_infra.sh
```

### 3. Construire l'image golden (Debian 13 + Docker) ###

VM temporaire → installation Docker via cloud-init → smoke test → généralisation → publication d'une version d'image dans la gallery. Compter ~15-20 min. Abort propre si le smoke test échoue (aucune image douteuse publiée).

```
./build_image.sh
```

### 4. Créer les VMs de session ###

```
./createVMs.sh <nb_participants> <nb_vm_par_participant>
```

- Crée les VMs participants **et** un jeu identique de VMs animateur, depuis l'image golden, sur le subnet partagé.
- Génère en fin de course `VMs.txt` et les packages KiTTY (voir plus bas).
- **Pas d'ajout incrémental** : pour changer le nombre de VMs, supprimer puis tout recréer.

### 5. Déployer le contenu des ateliers ###

Pousse les 3 ateliers vers les VMs (tar over SSH, authentification par mot de passe depuis `conf`) :

```
./deploy_content.sh
```

Par défaut : les 3 ateliers vers les VMs `*-1`, dans `~/` de l'utilisateur admin. Options : `-m <motif>` (filtre de VMs), `-d <dest>`, `-n` (simulation). Voir `./deploy_content.sh -h`.

### 6. Supprimer ###

```
./deleteVMs.sh <nb_participants> <nb_vm_par_participant>   # VMs d'une session (le réseau/l'image persistent)
./teardown_infra.sh                                        # TOUT le resource group (confirmation ; -y pour forcer)
```

## Packages KiTTY (VMs.txt + connexions pré-configurées) ##

`createVMs.sh` appelle `generate_packages.sh` en fin de provisionnement. Ce dernier :

- réécrit `VMs.txt` (FQDN déterministes, région réelle du resource group) — **ne plus l'éditer à la main** ;
- produit dans `packages/` un ZIP KiTTY portable par participant (`kitty-userN.zip`) + un pour l'animateur (`kitty-animateur.zip`), avec `kitty_portable.exe` bundlé et un lanceur `.bat` par VM (connexion SSH pré-remplie avec l'utilisateur admin défini dans `conf`).

Pour (re)générer les packages sans recréer les VMs :

```
./generate_packages.sh <nb_participants> <nb_vm_par_participant>
```

Le binaire `kitty_portable.exe` et le dossier `packages/` sont ignorés par Git.

## Tests ##

Les scripts de logique pure sont couverts par des tests bash (l'appel `az` est stubbé, aucun accès Azure requis) :

```
for t in tests/test_*.sh; do bash "$t"; done
```
