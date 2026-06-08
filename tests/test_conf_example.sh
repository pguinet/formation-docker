#!/usr/bin/bash
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0

# conf.example contient des placeholders <...> (non sourçables tels quels) ; on
# vérifie donc par grep que chaque variable attendue y est bien DÉCLARÉE
# (export var=), sans exécuter le template.
for v in subscription resourceGroupName location vmSize gallery image security \
         vmAdminUser vmAdminPassword \
         vnetName vnetAddressPrefix subnetName subnetPrefix nsgName inboundSource inboundPorts \
         imagePublisher imageOffer imageSku imageVersion sourceImage; do
  if grep -qE "^export ${v}=" "$DIR/conf.example"; then
    echo "PASS: var $v présente"
  else
    echo "FAIL: var $v absente"; fail=1
  fi
done
exit $fail
