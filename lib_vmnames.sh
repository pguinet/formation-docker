#!/usr/bin/bash
# Bibliothèque sourcée : convention de nommage des VMs d'atelier.
# Source unique partagée par createVMs.sh et generate_packages.sh.

# Préfixe Prima des noms de VM. Il devient le label DNS public (global par
# région) : le préfixer réduit le risque de collision avec un tiers Azure.
VM_PREFIX="prima-"

# Émet les noms courts des VMs, un par ligne.
# Ordre : les VMs animateur d'abord, puis les VMs des participants.
#   animateur   : prima-animateur-<M>
#   participant : prima-user<N>-<M>
# Args : <nb_user> <nb_vm_par_user>
list_vm_names() {
  local nb_user="$1" nb_vm="$2" u m
  for (( m=1; m<=nb_vm; m++ )); do
    echo "${VM_PREFIX}animateur-${m}"
  done
  for (( u=1; u<=nb_user; u++ )); do
    for (( m=1; m<=nb_vm; m++ )); do
      echo "${VM_PREFIX}user${u}-${m}"
    done
  done
}

# Construit le FQDN public Azure d'une VM (calqué sur le nom de la VM).
# Args : <nom_court> <region>
vm_fqdn() {
  echo "${1}.${2}.cloudapp.azure.com"
}
