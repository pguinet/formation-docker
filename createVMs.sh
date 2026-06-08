#! /usr/bin/bash

# Script de création en masse de VMs
# Usage ./createVMs.sh nb_user nb_vm
# nb_user = nombre de participants
# nb_vm = nb de VM par participant

# Avant de lancer le script, sourcer les variables
# . ./.env.atelier1

# Crée une VM. Arg : <nom_court_de_la_vm>
# Atterrit sur le subnet partagé ($vnetName/$subnetName) gouverné par le NSG ;
# on conserve --nsg '' (sécurité réseau portée par le subnet).
createVM() {
  local vmName="$1"
  echo "Create vmName $vmName"
  az vm create --resource-group $resourceGroupName --name "$vmName" --specialized false --image "/subscriptions/$subscription/resourceGroups/$resourceGroupName/providers/Microsoft.Compute/galleries/$gallery/images/$image" --license-type None --security-type $security --nic-delete-option Delete --os-disk-delete-option Delete --vnet-name "$vnetName" --subnet "$subnetName" --nsg '' --size $vmSize --priority Spot --eviction-policy Deallocate --authentication-type all --admin-password "$vmAdminPassword" --public-ip-address-dns-name "$vmName" --computer-name "$vmName"
}

# source conf / lib_vmnames.sh placés dans main() : le script reste sourçable en
# test (source-guard) sans écraser les variables fixées par le test.
main() {
  source conf
  source lib_vmnames.sh
  local NB_USER="$1" NB_VM="$2"
  case $# in
    0) echo "Aucun paramètre"; exit 1;;
    1) echo "Nombre de paramètres incorrect"; exit 1;;
    2) echo "Création des VMs"
       while read -r vmName; do
         createVM "$vmName"
       done < <(list_vm_names "$NB_USER" "$NB_VM")
       ./generate_packages.sh "$NB_USER" "$NB_VM"
       exit 0;;
    *) echo "Nombre de paramètres incorrect"; exit 1;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
