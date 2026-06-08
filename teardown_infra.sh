#!/usr/bin/bash
# Supprime TOUTE l'infra du lab : `az group delete` retire en cascade le RG,
# le réseau, le NSG, la gallery, l'image et toute VM résiduelle.
# Usage : ./teardown_infra.sh [-y]   (-y = ne pas demander de confirmation)
# (set -euo pipefail est posé dans main() pour rester sourçable en test.)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORCE=false

# Renvoie 0 si la suppression est confirmée. Sans FORCE, exige la saisie exacte
# du nom du resource group (garde-fou anti-erreur).
confirm_teardown() {
  $FORCE && return 0
  local ans
  read -r -p "Supprimer DEFINITIVEMENT le resource group '$resourceGroupName' ? Retape son nom pour confirmer : " ans
  [[ "$ans" == "$resourceGroupName" ]]
}

main() {
  set -euo pipefail
  while getopts "y" opt; do
    case "$opt" in
      y) FORCE=true ;;
      *) echo "Usage: $0 [-y]"; exit 1 ;;
    esac
  done
  # shellcheck source=conf
  source "$SCRIPT_DIR/conf"
  if confirm_teardown; then
    echo "Suppression du resource group $resourceGroupName..."
    az group delete -n "$resourceGroupName" --yes
    echo "Resource group $resourceGroupName supprimé."
  else
    echo "Abandon (le nom ne correspond pas)."
    exit 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
