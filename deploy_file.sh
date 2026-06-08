#!/bin/bash

# Script de déploiement de fichier sur plusieurs VMs via SCP
# Usage: ./deploy_file.sh -f <fichier_source> -l <liste_vms> [-d <destination>] [-p <port>]

set -euo pipefail

# Valeurs par défaut
DEFAULT_DEST_DIR="~/"
DEFAULT_PORT=22
VERBOSE=false

# Fonction d'aide
show_help() {
    cat << EOF
Usage: $0 -f <fichier_source> -l <liste_vms> [OPTIONS]

OBLIGATOIRE:
    -f, --file          Fichier à copier
    -l, --list          Fichier contenant la liste des VMs (une par ligne)

OPTIONS:
    -d, --dest          Répertoire de destination (défaut: ~/)
    -p, --port          Port SSH (défaut: 22)
    -v, --verbose       Mode verbeux
    -h, --help          Afficher cette aide

EXEMPLES:
    $0 -f config.conf -l vms.txt
    $0 -f script.sh -l servers.txt -d /tmp -p 2222
    $0 --file app.jar --list production.txt --dest /opt/app --verbose

FORMAT du fichier de liste des VMs:
    server1.example.com
    192.168.1.100
    user@server2.example.com
    server3.example.com:2222
EOF
}

# Fonction de log avec timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Fonction de log verbeux
verbose_log() {
    if [[ "$VERBOSE" == "true" ]]; then
        log "VERBOSE: $*"
    fi
}

# Fonction de validation des fichiers
validate_files() {
    if [[ ! -f "$SOURCE_FILE" ]]; then
        log "ERREUR: Le fichier source '$SOURCE_FILE' n'existe pas"
        exit 1
    fi

    if [[ ! -f "$VM_LIST_FILE" ]]; then
        log "ERREUR: Le fichier de liste des VMs '$VM_LIST_FILE' n'existe pas"
        exit 1
    fi

    if [[ ! -r "$VM_LIST_FILE" ]]; then
        log "ERREUR: Impossible de lire le fichier '$VM_LIST_FILE'"
        exit 1
    fi
}

# Fonction pour parser l'adresse de la VM
parse_vm_address() {
    local vm_line="$1"
    local vm_user=""
    local vm_host=""
    local vm_port="$DEFAULT_PORT"
    
    # Supprimer les espaces en début/fin
    vm_line=$(echo "$vm_line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Ignorer les lignes vides et les commentaires
    if [[ -z "$vm_line" || "$vm_line" =~ ^# ]]; then
        return 1
    fi
    
    # Vérifier si un utilisateur est spécifié (user@host)
    if [[ "$vm_line" =~ @ ]]; then
        vm_user="${vm_line%%@*}"
        vm_host="${vm_line##*@}"
    else
        vm_user="$USER"
        vm_host="$vm_line"
    fi
    
    # Vérifier si un port est spécifié (host:port)
    if [[ "$vm_host" =~ : ]]; then
        vm_port="${vm_host##*:}"
        vm_host="${vm_host%%:*}"
    fi
    
    verbose_log "VM parsée: user=$vm_user, host=$vm_host, port=$vm_port"
    echo "$vm_user $vm_host $vm_port"
    return 0
}

# Fonction de copie vers une VM
copy_to_vm() {
    local vm_user="$1"
    local vm_host="$2"
    local vm_port="$3"
    local attempt=1
    local max_attempts=3
    
    verbose_log "Tentative de copie vers $vm_user@$vm_host:$vm_port"
    verbose_log "Commande SCP: scp -P $vm_port '$SOURCE_FILE' '$vm_user@$vm_host:$DEST_DIR'"
    
    while [[ $attempt -le $max_attempts ]]; do
        if $VERBOSE; then
            # Mode verbeux: afficher les erreurs SCP
            if scp -o ConnectTimeout=10 \
                   -o StrictHostKeyChecking=no \
                   -o UserKnownHostsFile=/dev/null \
                   -P "$vm_port" \
                   "$SOURCE_FILE" \
                   "$vm_user@$vm_host:$DEST_DIR"; then
                log "✓ Succès: $vm_user@$vm_host:$vm_port"
                return 0
            fi
        else
            # Mode normal: supprimer les erreurs
            if scp -o ConnectTimeout=10 \
                   -o StrictHostKeyChecking=no \
                   -o UserKnownHostsFile=/dev/null \
                   -o LogLevel=ERROR \
                   -P "$vm_port" \
                   "$SOURCE_FILE" \
                   "$vm_user@$vm_host:$DEST_DIR" 2>/dev/null; then
                log "✓ Succès: $vm_user@$vm_host:$vm_port"
                return 0
            fi
        fi
        
        verbose_log "Échec tentative $attempt/$max_attempts pour $vm_user@$vm_host:$vm_port"
        ((attempt++))
        if [[ $attempt -le $max_attempts ]]; then
            sleep 2
        fi
    done
    
    log "✗ Échec: $vm_user@$vm_host:$vm_port (après $max_attempts tentatives)"
    return 1
}

# Parse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            SOURCE_FILE="$2"
            shift 2
            ;;
        -l|--list)
            VM_LIST_FILE="$2"
            shift 2
            ;;
        -d|--dest)
            DEST_DIR="$2"
            shift 2
            ;;
        -p|--port)
            DEFAULT_PORT="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log "ERREUR: Option inconnue '$1'"
            show_help
            exit 1
            ;;
    esac
done

# Vérification des paramètres obligatoires
if [[ -z "${SOURCE_FILE:-}" ]]; then
    log "ERREUR: Le fichier source est obligatoire (-f)"
    show_help
    exit 1
fi

if [[ -z "${VM_LIST_FILE:-}" ]]; then
    log "ERREUR: Le fichier de liste des VMs est obligatoire (-l)"
    show_help
    exit 1
fi

# Valeurs par défaut
DEST_DIR="${DEST_DIR:-$DEFAULT_DEST_DIR}"

# Validation des fichiers
validate_files

# Compteurs
declare -i total_vms=0
declare -i success_count=0
declare -i failed_count=0

log "Début du déploiement de '$SOURCE_FILE' vers le répertoire '$DEST_DIR'"
log "Liste des VMs: $VM_LIST_FILE"

# Lecture du fichier et traitement de chaque VM
while IFS= read -r vm_line || [[ -n "$vm_line" ]]; do
    verbose_log "Ligne lue: '$vm_line'"
    
    # Supprimer les espaces en début/fin
    vm_line=$(echo "$vm_line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Ignorer les lignes vides et les commentaires
    if [[ -z "$vm_line" || "$vm_line" =~ ^# ]]; then
        verbose_log "Ligne ignorée (vide ou commentaire): '$vm_line'"
        continue
    fi
    
    # Parser l'adresse de la VM directement
    vm_user="$USER"
    vm_host="$vm_line"
    vm_port="$DEFAULT_PORT"
    
    # Vérifier si un utilisateur est spécifié (user@host)
    if [[ "$vm_line" =~ @ ]]; then
        vm_user="${vm_line%%@*}"
        vm_host="${vm_line##*@}"
    fi
    
    # Vérifier si un port est spécifié (host:port)
    if [[ "$vm_host" =~ : ]]; then
        vm_port="${vm_host##*:}"
        vm_host="${vm_host%%:*}"
    fi
    
    total_vms=$((total_vms + 1))
    log "Traitement VM #$total_vms: $vm_user@$vm_host:$vm_port"
    
    if copy_to_vm "$vm_user" "$vm_host" "$vm_port"; then
        success_count=$((success_count + 1))
    else
        failed_count=$((failed_count + 1))
    fi
done < "$VM_LIST_FILE"

# Résumé final
log "=== RÉSUMÉ ==="
log "Total VMs traitées: $total_vms"
log "Succès: $success_count"
log "Échecs: $failed_count"

if [[ $failed_count -gt 0 ]]; then
    log "ATTENTION: Des échecs ont été détectés"
    exit 1
else
    log "Déploiement terminé avec succès !"
    exit 0
fi
