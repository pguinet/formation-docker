#!/usr/bin/bash
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
source "$DIR/tests/helpers.sh"

# On masque `az` pour capturer la commande, puis on source createVMs.sh
# (le source-guard empêche l'exécution de main) et on appelle createVM.
AZ_CALLS=""
az() { AZ_CALLS+="az $*"$'\n'; return 0; }

# Variables de conf attendues par createVM.
resourceGroupName="rg-test"; subscription="sub"; gallery="gal"; image="img"
security="TrustedLaunch"; vmSize="Standard_D2s_v3"; vmAdminPassword="x"
vnetName="vnet-test"; subnetName="sn-test"

source "$DIR/createVMs.sh"
createVM "user1-1" >/dev/null

assert_contains "createVM passe --vnet-name" "$AZ_CALLS" "--vnet-name vnet-test"
assert_contains "createVM passe --subnet"    "$AZ_CALLS" "--subnet sn-test"
assert_contains "createVM garde --nsg vide"  "$AZ_CALLS" "--nsg "
exit $fail
