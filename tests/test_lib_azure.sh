#!/usr/bin/bash
# Tests de lib_azure.sh : on masque `az` par une fonction qui enregistre les
# appels (AZ_CALLS) et dont les `... show` renvoient un code contrôlable
# (RC_*_SHOW : 0 = ressource présente, 1 = absente).
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
source "$DIR/tests/helpers.sh"
source "$DIR/lib_azure.sh"

# Variables de conf nécessaires aux fonctions.
resourceGroupName="rg-test"; location="northeurope"
vnetName="vnet-test"; vnetAddressPrefix="10.0.0.0/16"; subnetName="sn-test"; subnetPrefix="10.0.0.0/24"
nsgName="nsg-test"; inboundSource='*'; inboundPorts='22 80 8080'
gallery="gal_test"; image="imgdef"; imagePublisher="pub"; imageOffer="off"; imageSku="sku"; security="TrustedLaunch"

AZ_CALLS=""
az() {
  AZ_CALLS+="az $*"$'\n'
  case "$*" in
    "group show"*)                  return "${RC_GROUP_SHOW:-0}";;
    "network vnet show"*)           return "${RC_VNET_SHOW:-0}";;
    "network nsg show"*)            return "${RC_NSG_SHOW:-0}";;
    "network nsg rule show"*)       return "${RC_RULE_SHOW:-0}";;
    "sig show"*)                    return "${RC_SIG_SHOW:-0}";;
    "sig image-definition show"*)   return "${RC_IMGDEF_SHOW:-0}";;
    *)                              return 0;;
  esac
}

# --- ensure_resource_group ---
AZ_CALLS=""; RC_GROUP_SHOW=1; ensure_resource_group >/dev/null
assert_contains "RG absent -> create" "$AZ_CALLS" "group create -n rg-test -l northeurope"
AZ_CALLS=""; RC_GROUP_SHOW=0; ensure_resource_group >/dev/null
assert_not_contains "RG présent -> pas de create" "$AZ_CALLS" "group create"

# --- ensure_vnet ---
AZ_CALLS=""; RC_VNET_SHOW=1; ensure_vnet >/dev/null
assert_contains "VNet absent -> create vnet" "$AZ_CALLS" "network vnet create -g rg-test -n vnet-test"
assert_contains "VNet absent -> subnet inline" "$AZ_CALLS" "--subnet-name sn-test --subnet-prefix 10.0.0.0/24"
AZ_CALLS=""; RC_VNET_SHOW=0; ensure_vnet >/dev/null
assert_not_contains "VNet présent -> pas de create" "$AZ_CALLS" "network vnet create"

# --- ensure_nsg ---
AZ_CALLS=""; RC_NSG_SHOW=1; ensure_nsg >/dev/null
assert_contains "NSG absent -> create" "$AZ_CALLS" "network nsg create -g rg-test -n nsg-test"
AZ_CALLS=""; RC_NSG_SHOW=0; ensure_nsg >/dev/null
assert_not_contains "NSG présent -> pas de create" "$AZ_CALLS" "network nsg create"

# --- ensure_nsg_rule (22/80/8080 depuis partout) ---
AZ_CALLS=""; RC_RULE_SHOW=1; ensure_nsg_rule >/dev/null
assert_contains "Règle absente -> create" "$AZ_CALLS" "network nsg rule create -g rg-test --nsg-name nsg-test -n allow-inbound"
assert_contains "Règle : ports"  "$AZ_CALLS" "--destination-port-ranges 22 80 8080"
assert_contains "Règle : source" "$AZ_CALLS" "--source-address-prefixes *"
AZ_CALLS=""; RC_RULE_SHOW=0; ensure_nsg_rule >/dev/null
assert_not_contains "Règle présente -> pas de create" "$AZ_CALLS" "network nsg rule create"

# --- associate_nsg_subnet (toujours appliqué, idempotent par nature) ---
AZ_CALLS=""; associate_nsg_subnet >/dev/null
assert_contains "Assoc NSG<->subnet" "$AZ_CALLS" "network vnet subnet update -g rg-test --vnet-name vnet-test -n sn-test --network-security-group nsg-test"

# --- ensure_gallery ---
AZ_CALLS=""; RC_SIG_SHOW=1; ensure_gallery >/dev/null
assert_contains "Gallery absente -> create" "$AZ_CALLS" "sig create -g rg-test --gallery-name gal_test"
AZ_CALLS=""; RC_SIG_SHOW=0; ensure_gallery >/dev/null
assert_not_contains "Gallery présente -> pas de create" "$AZ_CALLS" "sig create"

# --- ensure_image_definition (Gen2 + TrustedLaunch) ---
AZ_CALLS=""; RC_IMGDEF_SHOW=1; ensure_image_definition >/dev/null
assert_contains "ImgDef absente -> create" "$AZ_CALLS" "sig image-definition create -g rg-test --gallery-name gal_test --gallery-image-definition imgdef"
assert_contains "ImgDef : Gen2"          "$AZ_CALLS" "--hyper-v-generation V2"
assert_contains "ImgDef : TrustedLaunch" "$AZ_CALLS" "--features SecurityType=TrustedLaunch"
AZ_CALLS=""; RC_IMGDEF_SHOW=0; ensure_image_definition >/dev/null
assert_not_contains "ImgDef présente -> pas de create" "$AZ_CALLS" "sig image-definition create"

exit $fail
