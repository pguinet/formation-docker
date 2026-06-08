#!/usr/bin/bash
# Construit l'image golden (Debian 13 + Docker) et publie une version dans la
# Compute Gallery. Flux : VM temporaire -> cloud-init Docker -> smoke test ->
# generalize -> capture en version. Abort propre si le smoke test échoue.
# Usage : ./build_image.sh
# (set -euo pipefail est posé dans main() pour rester sourçable en test.)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_VM="img-builder"

# Vrai si la sortie du smoke test contient le marqueur de succès de `hello-world`.
smoke_succeeded() {
  case "$1" in
    *"Hello from Docker!"*) return 0 ;;
    *)                      return 1 ;;
  esac
}

# Remplace __ADMIN_USER__ dans un contenu cloud-init. Args : <contenu> <user>.
render_cloud_init() {
  printf '%s' "$1" | sed "s/__ADMIN_USER__/$2/g"
}

# Supprime la VM de build (disque OS + NIC supprimés via leurs delete-option).
cleanup_build_vm() {
  local vm="$1"
  az vm delete -g "$resourceGroupName" -n "$vm" --yes --force-deletion true >/dev/null 2>&1 || true
}

main() {
  set -euo pipefail
  # shellcheck source=conf
  source "$SCRIPT_DIR/conf"

  local cloudinit; cloudinit="$(mktemp)"
  render_cloud_init "$(cat "$SCRIPT_DIR/cloud-init-docker.yaml")" "$vmAdminUser" > "$cloudinit"

  echo "1/6 Création de la VM de build $BUILD_VM (Debian Gen2, Trusted Launch)..."
  az vm create -g "$resourceGroupName" -n "$BUILD_VM" \
    --image "$sourceImage" --security-type "$security" \
    --size "$vmSize" --vnet-name "$vnetName" --subnet "$subnetName" --nsg '' \
    --public-ip-address '' \
    --nic-delete-option Delete --os-disk-delete-option Delete \
    --admin-username "$vmAdminUser" --admin-password "$vmAdminPassword" \
    --custom-data "$cloudinit" >/dev/null
  rm -f "$cloudinit"

  echo "2/6 Attente de la fin du provisioning cloud-init..."
  az vm run-command invoke -g "$resourceGroupName" -n "$BUILD_VM" \
    --command-id RunShellScript --scripts "cloud-init status --wait" >/dev/null

  echo "3/6 Smoke test (docker hello-world + compose)..."
  local out
  out="$(az vm run-command invoke -g "$resourceGroupName" -n "$BUILD_VM" \
    --command-id RunShellScript \
    --scripts "docker run --rm hello-world; docker compose version" \
    --query 'value[0].message' -o tsv)"
  if ! smoke_succeeded "$out"; then
    echo "ERREUR : smoke test échoué. Sortie :" >&2
    echo "$out" >&2
    cleanup_build_vm "$BUILD_VM"
    exit 1
  fi

  echo "4/6 Deprovisionnement + generalisation..."
  # waagent -deprovision coupe l'agent invite qui poste le resultat du run-command.
  # On detache la commande (setsid + &) ET on la RETARDE (sleep 20) : le script de
  # run-command rend la main tout de suite -> l'agent acquitte l'invoke en quelques
  # secondes, AVANT que le deprovision (T+20s) ne le coupe. Sans ce delai, le
  # deprovision tue l'agent avant l'ack et l'invoke poll indefiniment.
  # On laisse ensuite cote hote (sleep 60) le deprovision s'achever avant l'arret.
  # deallocate/generalize sont control-plane : ils aboutissent meme agent coupe.
  az vm run-command invoke -g "$resourceGroupName" -n "$BUILD_VM" \
    --command-id RunShellScript \
    --scripts "setsid sh -c 'sleep 20; waagent -deprovision+user -force' >/dev/null 2>&1 </dev/null &" >/dev/null 2>&1 || true
  sleep 60
  az vm deallocate -g "$resourceGroupName" -n "$BUILD_VM" >/dev/null
  az vm generalize -g "$resourceGroupName" -n "$BUILD_VM" >/dev/null

  echo "5/6 Publication de la version $imageVersion dans la gallery..."
  local vmId; vmId="$(az vm show -g "$resourceGroupName" -n "$BUILD_VM" --query id -o tsv)"
  az sig image-version create -g "$resourceGroupName" --gallery-name "$gallery" \
    --gallery-image-definition "$image" --gallery-image-version "$imageVersion" \
    --virtual-machine "$vmId" --target-regions "$location" >/dev/null

  echo "6/6 Nettoyage de la VM de build..."
  cleanup_build_vm "$BUILD_VM"
  echo "Image golden $image:$imageVersion publiée."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
