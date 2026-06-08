#! /usr/bin/bash

# Script de suppression en masse de VMs
# Usage ./deleteVMs.sh nb_user nb_vm
# nb_user = nombre de participants
# nb_vm = nb de VM par participant

# Avant de lancer le script, sourcer les variables
# . ./.env.atelier1

# Supprime une VM et son IP publique. Arg : <nom_de_la_vm>
deleteVM() {
  local vmName="$1"
  echo "Delete vmName $vmName"
  az vm delete --resource-group $resourceGroupName --name $vmName --yes --force-deletion true
  az network public-ip delete --resource-group $resourceGroupName --name ${vmName}PublicIP
}

# source conf / lib_vmnames.sh placés dans main() : le script reste sourçable en
# test (source-guard) sans écraser les variables fixées par le test. Les noms de
# VM viennent de list_vm_names (source unique partagée avec createVMs.sh).
main() {
  source conf
  source lib_vmnames.sh
  local NB_USER="$1" NB_VM="$2"
  case $# in
    0) echo "Aucun paramètre"; exit 1;;
    1) echo "Nombre de paramètres incorrect"; exit 1;;
    2) echo "Suppression des VMs"
       while read -r vmName; do
         deleteVM "$vmName"
       done < <(list_vm_names "$NB_USER" "$NB_VM")
       exit 0;;
    *) echo "Nombre de paramètres incorrect"; exit 1;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
