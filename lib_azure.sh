#!/usr/bin/bash
# Bibliothèque sourcée : création idempotente des ressources Azure du lab.
# Chaque fonction lit les variables de `conf` (globales) et n'agit que si la
# ressource est absente. Appelle `az` comme commande (donc stubbable en test).

# Réessaie une commande `az` (cohérence éventuelle d'Azure : une ressource juste
# créée n'est parfois pas encore visible pour l'opération suivante -> ResourceNotFound
# transitoire). Permet au provisioning d'aboutir en une seule passe, sans intervention.
az_retry() {
  local attempt=1 max=5
  until "$@"; do
    if (( attempt >= max )); then return 1; fi
    echo "  (cohérence Azure : réessai $attempt/$max...)" >&2
    sleep 5
    attempt=$((attempt + 1))
  done
}

# Resource group.
ensure_resource_group() {
  if az group show -n "$resourceGroupName" >/dev/null 2>&1; then
    echo "RG $resourceGroupName : déjà présent"
    return 0
  fi
  echo "RG $resourceGroupName : création"
  az_retry az group create -n "$resourceGroupName" -l "$location" >/dev/null
}

# VNet + subnet partagé (créés en une seule commande).
ensure_vnet() {
  if az network vnet show -g "$resourceGroupName" -n "$vnetName" >/dev/null 2>&1; then
    echo "VNet $vnetName : déjà présent"
    return 0
  fi
  echo "VNet $vnetName : création (+ subnet $subnetName)"
  az_retry az network vnet create -g "$resourceGroupName" -n "$vnetName" \
    --address-prefix "$vnetAddressPrefix" \
    --subnet-name "$subnetName" --subnet-prefix "$subnetPrefix" >/dev/null
}

# NSG (porté par le subnet).
ensure_nsg() {
  if az network nsg show -g "$resourceGroupName" -n "$nsgName" >/dev/null 2>&1; then
    echo "NSG $nsgName : déjà présent"
    return 0
  fi
  echo "NSG $nsgName : création"
  az_retry az network nsg create -g "$resourceGroupName" -n "$nsgName" >/dev/null
}

# Règle entrante : TCP $inboundPorts depuis $inboundSource. $inboundPorts reste non
# quoté (word-splitting voulu pour passer chaque port en argument distinct ; les ports
# ne contiennent pas de métacaractère de glob). $inboundSource est quoté : sa valeur par
# défaut '*' subirait sinon l'expansion de chemin (liste des fichiers du répertoire).
ensure_nsg_rule() {
  if az network nsg rule show -g "$resourceGroupName" --nsg-name "$nsgName" -n allow-inbound >/dev/null 2>&1; then
    echo "Règle allow-inbound : déjà présente"
    return 0
  fi
  echo "Règle allow-inbound : création ($inboundPorts depuis $inboundSource)"
  az_retry az network nsg rule create -g "$resourceGroupName" --nsg-name "$nsgName" -n allow-inbound \
    --priority 1000 --direction Inbound --access Allow --protocol Tcp \
    --source-address-prefixes "$inboundSource" --source-port-ranges '*' \
    --destination-address-prefixes '*' --destination-port-ranges $inboundPorts >/dev/null
}

# Associe le NSG au subnet (opération idempotente : on la (ré)applique sans garde).
associate_nsg_subnet() {
  echo "Association NSG $nsgName <-> subnet $subnetName"
  az_retry az network vnet subnet update -g "$resourceGroupName" --vnet-name "$vnetName" \
    -n "$subnetName" --network-security-group "$nsgName" >/dev/null
}

# Azure Compute Gallery.
ensure_gallery() {
  if az sig show -g "$resourceGroupName" --gallery-name "$gallery" >/dev/null 2>&1; then
    echo "Gallery $gallery : déjà présente"
    return 0
  fi
  echo "Gallery $gallery : création"
  az_retry az sig create -g "$resourceGroupName" --gallery-name "$gallery" >/dev/null
}

# Définition d'image (Gen2 + Trusted Launch, cohérent avec security=TrustedLaunch).
ensure_image_definition() {
  if az sig image-definition show -g "$resourceGroupName" --gallery-name "$gallery" \
        --gallery-image-definition "$image" >/dev/null 2>&1; then
    echo "Définition d'image $image : déjà présente"
    return 0
  fi
  echo "Définition d'image $image : création"
  az_retry az sig image-definition create -g "$resourceGroupName" --gallery-name "$gallery" \
    --gallery-image-definition "$image" \
    --publisher "$imagePublisher" --offer "$imageOffer" --sku "$imageSku" \
    --os-type Linux --hyper-v-generation V2 --features SecurityType=TrustedLaunch >/dev/null
}
