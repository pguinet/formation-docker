#!/usr/bin/bash
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
source "$DIR/tests/helpers.sh"

# On masque `az` pour capturer la commande, puis on source deleteVMs.sh
# (le source-guard empêche l'exécution de main) et on appelle deleteVM.
AZ_CALLS=""
az() { AZ_CALLS+="az $*"$'\n'; return 0; }

resourceGroupName="rg-test"

source "$DIR/deleteVMs.sh"
deleteVM "prima-user1-1" >/dev/null

assert_contains "deleteVM supprime la VM"          "$AZ_CALLS" "vm delete --resource-group rg-test --name prima-user1-1 --yes"
assert_contains "deleteVM supprime l'IP publique"  "$AZ_CALLS" "network public-ip delete --resource-group rg-test --name prima-user1-1PublicIP"
exit $fail
