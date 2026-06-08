# Atelier Docker Swarm

Atelier de **60 a 75 minutes** pour vivre le cycle complet d'une application sur un cluster Swarm a
deux noeuds : **constituer le cluster, monter un registre prive, construire une image custom, la
pousser, la deployer, puis la faire evoluer** (scale + rolling update sans coupure).

A chaque etape, vous tapez les commandes et **vous observez** ce qui se passe (`docker service ls`,
`docker service ps`, `curl`) : l'observation est le coeur de l'apprentissage.

## Prerequis

- **2 VMs Linux** par participant : `vm1` (futur manager) et `vm2` (futur worker).
- Docker Engine (>= 20.10) et plugin `compose` (v2) installes, `docker` executable sans `sudo`.
- Connectivite reseau entre les 2 VMs sur les ports Swarm :
  - **2377/tcp** (management du cluster)
  - **7946/tcp + 7946/udp** (communication entre noeuds)
  - **4789/udp** (reseau overlay)
  - ainsi que les ports applicatifs publies : **80**, **5000**, **8080**.

## Convention

Chaque bloc de commandes precise sur quel noeud l'executer : **[manager]** (vm1), **[worker]**
(vm2), ou **[depuis n'importe ou]**. Les commandes d'administration Swarm ne fonctionnent que sur
un manager.

## Parcours

| Etape | Sujet                                   | Noeud principal |
|-------|-----------------------------------------|-----------------|
| 0     | Constituer le cluster (init + join)     | manager + worker|
| 1     | Premier service (echauffement nginx)    | manager         |
| 2     | Registre prive                          | manager + worker|
| 3     | Build, push et deploiement de l'appli   | manager         |
| 4     | Faire evoluer (scale + rolling update)  | manager         |
| 5     | Nettoyage et demantelement              | manager + worker|

Contrairement a d'autres ateliers, les etapes **s'enchainent** : le cluster monte a l'etape 0
persiste jusqu'a l'etape 5.

## Demarrer

```bash
cd etape-0-cluster
cat README.md
```

Puis suivre les etapes dans l'ordre.

## L'application de demo

Le dossier `app/` contient l'image custom deployee a partir de l'etape 3 : un mini serveur HTTP
Python (bibliotheque standard, aucune dependance) qui renvoie a chaque requete le **hostname du
conteneur** qui repond et un **numero de version**. Le hostname rend visible le load-balancing du
routing mesh ; le numero de version rend visible le rolling update.

## Matrice de verification finale

| Verification                                                        | Resultat attendu                          |
|---------------------------------------------------------------------|-------------------------------------------|
| `docker node ls` (manager, apres etape 0)                           | 2 noeuds, vm1 Leader, vm2 worker          |
| `docker service ps web` (etape 1)                                   | taches reparties sur vm1 ET vm2           |
| `curl http://<ip_vm2>/` sans tache web sur vm2                      | page nginx (200) via routing mesh         |
| `curl http://localhost:5000/v2/` sur le **worker** (etape 2)        | `{}` (registre joignable partout)         |
| `docker service ps hello` (etape 3)                                 | taches `Running` y compris sur le worker  |
| `curl ...:8080` en boucle (etape 3)                                 | hostnames differents (load-balancing)     |
| `docker service scale hello=6` puis `ps` (etape 4a)                 | 6 taches reparties sur les 2 noeuds       |
| `curl ...:8080` pendant le `service update` (etape 4b)              | bascule v1 -> v2 sans erreur              |
| `docker swarm leave` sur les 2 noeuds (etape 5)                     | cluster demantele, `node ls` en erreur    |

Si toutes les lignes matchent, l'atelier est reussi.

## Hors-scope (autres ateliers)

Overlay networks applicatifs avances, secrets/configs Swarm, contraintes de placement
(`--constraint`, labels), healthchecks et rollback fins, multi-manager avec quorum reel, TLS sur le
registre.
