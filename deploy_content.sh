#!/bin/bash

# Déploiement récursif du contenu de formation sur plusieurs VMs via tar over SSH.
# Pousse une arborescence (plusieurs dossiers) en une seule connexion par machine,
# sans fichier temporaire (tar-pipe). Authentification par mot de passe via sshpass.
#
# Usage : ./deploy_content.sh [-l <liste>] [-m <motif>] [-d <dest>] [-p <port>] [-n] [-v] [chemin...]
# Par défaut : pousse les 3 ateliers vers les VMs *-1 de VMs.txt, en tant que prima.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/conf"   # vmAdminUser, vmAdminPassword

# Valeurs par défaut
VM_LIST_FILE="$SCRIPT_DIR/VMs.txt"
MOTIF="-1"                  # filtre sur le nom de VM : *-1 par défaut
DEST_DIR="~/"               # destination sur la VM (~ = home de prima)
PORT=22
VERBOSE=false
DRY_RUN=false
DEFAULT_CONTENTS=(atelier_compose atelier_securisation atelier_swarm)

show_help() {
    cat << EOF
Usage: $0 [OPTIONS] [chemin...]

Déploie récursivement du contenu de formation sur les VMs (tar over SSH).
Sans chemin précisé, déploie : ${DEFAULT_CONTENTS[*]}

OPTIONS:
    -l, --list      Fichier liste des VMs (défaut: VMs.txt)
    -m, --motif     Filtre sur le nom de VM (défaut: -1, soit les machines *-1)
    -d, --dest      Répertoire de destination sur la VM (défaut: ~/)
    -p, --port      Port SSH (défaut: 22)
    -n, --dry-run   Affiche ce qui serait fait sans se connecter
    -v, --verbose   Mode verbeux
    -h, --help      Afficher cette aide

EXEMPLES:
    $0                                   # 3 ateliers -> VMs *-1
    $0 -m -2 atelier_swarm               # atelier_swarm -> VMs *-2
    $0 -d '~/formation' -n               # simulation vers ~/formation
EOF
}

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
verbose_log() { [[ "$VERBOSE" == "true" ]] && log "VERBOSE: $*" || true; }

# Parsing des arguments
CONTENTS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -l|--list)    VM_LIST_FILE="$2"; shift 2 ;;
        -m|--motif)   MOTIF="$2"; shift 2 ;;
        -d|--dest)    DEST_DIR="$2"; shift 2 ;;
        -p|--port)    PORT="$2"; shift 2 ;;
        -n|--dry-run) DRY_RUN=true; shift ;;
        -v|--verbose) VERBOSE=true; shift ;;
        -h|--help)    show_help; exit 0 ;;
        -*)           log "ERREUR: option inconnue '$1'"; show_help; exit 1 ;;
        *)            CONTENTS+=("$1"); shift ;;
    esac
done
[[ ${#CONTENTS[@]} -eq 0 ]] && CONTENTS=("${DEFAULT_CONTENTS[@]}")

# Pré-requis : sshpass (sauf en simulation)
if [[ "$DRY_RUN" != "true" ]] && ! command -v sshpass >/dev/null 2>&1; then
    log "ERREUR: sshpass est requis et absent."
    log "Installe-le puis relance :  sudo apt-get install -y sshpass"
    exit 1
fi

# Validation de la liste et du contenu
[[ -r "$VM_LIST_FILE" ]] || { log "ERREUR: liste des VMs introuvable: $VM_LIST_FILE"; exit 1; }
for c in "${CONTENTS[@]}"; do
    [[ -e "$SCRIPT_DIR/$c" ]] || { log "ERREUR: contenu introuvable: $c"; exit 1; }
done

# Filtrer les hôtes selon le motif (-- pour ne pas confondre '-1' avec une option grep)
mapfile -t HOSTS < <(grep -E -- "${MOTIF}\." "$VM_LIST_FILE" || true)
[[ ${#HOSTS[@]} -gt 0 ]] || { log "ERREUR: aucune VM ne correspond au motif '${MOTIF}' dans $VM_LIST_FILE"; exit 1; }

SSH_OPTS=(-o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)

log "Contenu  : ${CONTENTS[*]}"
log "Cibles   : ${#HOSTS[@]} VM(s) (motif '$MOTIF', user $vmAdminUser, dest '$DEST_DIR')"

# Copie vers une VM via tar-pipe, avec 3 tentatives.
copy_to_host() {
    local host="$1" attempt=1 max=3
    while [[ $attempt -le $max ]]; do
        if tar czf - -C "$SCRIPT_DIR" "${CONTENTS[@]}" \
            | sshpass -e ssh "${SSH_OPTS[@]}" -p "$PORT" "$vmAdminUser@$host" \
                "mkdir -p $DEST_DIR && tar xzf - -C $DEST_DIR"; then
            log "✓ Succès: $vmAdminUser@$host"
            return 0
        fi
        verbose_log "Échec tentative $attempt/$max pour $host"
        attempt=$((attempt + 1))
        if [[ $attempt -le $max ]]; then sleep 2; fi
    done
    log "✗ Échec: $vmAdminUser@$host (après $max tentatives)"
    return 1
}

# Mode simulation : on valide le filtrage et que le contenu est archivable, sans connexion.
if [[ "$DRY_RUN" == "true" ]]; then
    log "=== DRY-RUN (aucune connexion) ==="
    log "Vérification que le contenu est archivable..."
    tar czf /dev/null -C "$SCRIPT_DIR" "${CONTENTS[@]}" && log "  → archive OK"
    for host in "${HOSTS[@]}"; do
        host="$(echo "$host" | tr -d '[:space:]')"
        [[ -z "$host" ]] && continue
        log "  tar ... | ssh $vmAdminUser@$host 'mkdir -p $DEST_DIR && tar xzf - -C $DEST_DIR'"
    done
    exit 0
fi

export SSHPASS="$vmAdminPassword"

declare -i total=0 ok=0 ko=0
for host in "${HOSTS[@]}"; do
    host="$(echo "$host" | tr -d '[:space:]')"
    [[ -z "$host" ]] && continue
    total=$((total + 1))
    log "VM #$total : $host"
    if copy_to_host "$host"; then ok=$((ok + 1)); else ko=$((ko + 1)); fi
done

log "=== RÉSUMÉ ==="
log "Total: $total | Succès: $ok | Échecs: $ko"
[[ $ko -gt 0 ]] && exit 1 || exit 0
