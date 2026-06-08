#!/usr/bin/bash
# Génère VMs.txt et les packages KiTTY pré-configurés (un par participant + animateur).
# Usage : ./generate_packages.sh <nb_user> <nb_vm>
# Régénérable seul, sans recréer les VMs.
# La région peut être forcée via la variable d'env REGION (utile pour les tests).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/conf"
source "$SCRIPT_DIR/lib_vmnames.sh"

NB_USER="${1:?Usage: $0 <nb_user> <nb_vm>}"
NB_VM="${2:?Usage: $0 <nb_user> <nb_vm>}"

PORT=22
KITTY_URL="https://www.9bis.net/kitty/files/kitty_portable.exe"
KITTY_EXE="$SCRIPT_DIR/kitty_portable.exe"   # cache local (gitignoré)
PACKAGES_DIR="$SCRIPT_DIR/packages"
VMS_FILE="$SCRIPT_DIR/VMs.txt"

# Région réelle du resource group. conf.location est ignoré par az vm create :
# la VM hérite de la région du RG. On interroge donc az (sauf override REGION).
REGION="${REGION:-$(az group show -n "$resourceGroupName" --query location -o tsv)}"

# (Ré)écrit VMs.txt à partir de la convention de nommage et de la région.
ecrire_vms_txt() {
  : > "$VMS_FILE"
  local name
  while read -r name; do
    vm_fqdn "$name" "$REGION" >> "$VMS_FILE"
  done < <(list_vm_names "$NB_USER" "$NB_VM")
  echo "VMs.txt généré ($(wc -l < "$VMS_FILE") VMs, région $REGION)"
}

# Télécharge kitty_portable.exe si absent du cache.
telecharger_kitty() {
  if [[ -s "$KITTY_EXE" ]]; then
    echo "kitty_portable.exe déjà en cache"
    return
  fi
  echo "Téléchargement de kitty_portable.exe..."
  curl -fSL --retry 3 -o "$KITTY_EXE" "$KITTY_URL"
  # Vérification basique : exécutable Windows (signature MZ).
  if [[ "$(head -c2 "$KITTY_EXE")" != "MZ" ]]; then
    echo "ERREUR: le fichier téléchargé n'est pas un exécutable Windows" >&2
    rm -f "$KITTY_EXE"
    exit 1
  fi
}

# Construit et zippe un package KiTTY.
# Args : <nom_entité> <vm1> [vm2 ...]
construire_package() {
  local entite="$1"; shift
  local dir="$PACKAGES_DIR/kitty-$entite"
  rm -rf "$dir"
  mkdir -p "$dir/Sessions"
  cp "$KITTY_EXE" "$dir/kitty_portable.exe"
  printf '[KiTTY]\r\nsavemode=dir\r\n' > "$dir/kitty.ini"

  local name fqdn
  for name in "$@"; do
    fqdn="$(vm_fqdn "$name" "$REGION")"
    # Lanceur .bat : connexion robuste, indépendante du format de fichier session.
    # %~dp0 = dossier du .bat → l'exe est trouvé à côté (package relogeable).
    printf '@echo off\r\n"%%~dp0kitty_portable.exe" -ssh %s@%s -P %s -pass "%s" -auto-store-sshkey\r\n' \
      "$vmAdminUser" "$fqdn" "$PORT" "$vmAdminPassword" > "$dir/Connexion ${name}.bat"
    # Fichier session (bonus : peuple la liste GUI de KiTTY en mode savemode=dir).
    printf 'HostName\\%s\r\nPortNumber\\%s\r\nProtocol\\ssh\r\nUserName\\%s\r\n' \
      "$fqdn" "$PORT" "$vmAdminUser" > "$dir/Sessions/$name"
  done

  ( cd "$PACKAGES_DIR" && zip -qr "kitty-$entite.zip" "kitty-$entite" )
  echo "Package $entite : $# VM(s) → packages/kitty-$entite.zip"
}

main() {
  mkdir -p "$PACKAGES_DIR"
  ecrire_vms_txt
  telecharger_kitty
  # Animateur : ses VMs + toutes les VMs participants (vue d'ensemble).
  construire_package "animateur" $(list_vm_names "$NB_USER" "$NB_VM")
  # Un package par participant : uniquement ses propres VMs.
  local u
  for (( u=1; u<=NB_USER; u++ )); do
    construire_package "user${u}" $(list_vm_names "$NB_USER" "$NB_VM" | grep "^prima-user${u}-")
  done
  echo "Packages générés dans $PACKAGES_DIR"
}

main
