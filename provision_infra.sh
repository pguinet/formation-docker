#!/usr/bin/bash
# Crée depuis zéro l'infra du lab (idempotent) : resource group, VNet/subnet
# partagé, NSG (+ règle + association), Compute Gallery + définition d'image.
# L'image golden elle-même est construite séparément par build_image.sh.
# Usage : ./provision_infra.sh
# (set -euo pipefail est posé dans main() pour ne pas polluer un shell qui
#  sourcerait ce script en test.)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib_azure.sh
source "$SCRIPT_DIR/lib_azure.sh"

main() {
  set -euo pipefail
  # shellcheck source=conf
  source "$SCRIPT_DIR/conf"
  ensure_resource_group
  ensure_vnet
  ensure_nsg
  ensure_nsg_rule
  associate_nsg_subnet
  ensure_gallery
  ensure_image_definition
  echo "Infrastructure prête. Construire l'image : ./build_image.sh"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
