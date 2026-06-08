# Etape 0 — Constituer le cluster Swarm

## Objectif

Transformer deux VMs isolees en un cluster Swarm a deux noeuds : un manager (vm1) et un worker (vm2).

## A faire

1. **[vm1 — futur manager]** initialiser le swarm :
   ```bash
   docker swarm init
   ```
   La sortie affiche une commande `docker swarm join --token SWMTKN-... <ip_vm1>:2377` : la copier.

   > Si la commande se plaint de **plusieurs interfaces reseau** (et seulement dans ce cas),
   > relancer avec l'IP privee de vm1 : `docker swarm init --advertise-addr <ip_privee_vm1>`.

2. **[vm2 — worker]** coller la commande de join fournie par vm1 :
   ```bash
   docker swarm join --token SWMTKN-... <ip_vm1>:2377
   ```
   -> `This node joined a swarm as a worker.`

3. **[vm1 — manager]** verifier le cluster :
   ```bash
   docker node ls
   ```

## Ce que vous devez observer

`docker node ls` (sur le manager) liste **deux noeuds** : vm1 avec `MANAGER STATUS = Leader`,
vm2 avec une colonne `MANAGER STATUS` vide (c'est un worker). Les deux sont `Ready` / `Active`.

Pour explorer : `docker node inspect self --pretty` et `docker info | grep -i swarm`.

## Ce qu'il faut retenir

Un **manager** pilote le cluster et maintient l'etat desire ; un **worker** execute les taches.
Le token de join porte l'adresse du manager : c'est ainsi que le worker sait qui contacter.

## Pour aller plus loin (optionnel)

- Promouvoir le worker en manager : `docker node promote vm2`, puis `docker node ls`.
- Discussion quorum : avec 2 noeuds on n'a pas de vraie tolerance de panne. Il faut un nombre
  **impair** de managers (>= 3) pour qu'un manager puisse tomber sans perdre le cluster.
- Re-demonter ensuite : `docker node demote vm2`.
