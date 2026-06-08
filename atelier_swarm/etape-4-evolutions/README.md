# Etape 4 — Faire evoluer le service

## Objectif

Les deux gestes d'exploitation courants : changer le nombre de replicas (**scale**) et deployer
une nouvelle version d'image sans coupure (**rolling update**).

## 4a — Scale

1. **[manager]** augmenter puis reduire le nombre de replicas :
   ```bash
   docker service scale hello=6
   docker service ps hello
   docker service scale hello=2
   ```

**Observer :** `scale hello=6` cree 3 nouvelles taches reparties sur les 2 noeuds ; `scale hello=2`
en arrete 4 pour revenir a l'etat desire.

## 4b — Rolling update (nouvelle version d'image)

1. **[manager]** editer `../app/app.py` et changer la version :
   ```python
   VERSION = "2"
   ```

2. **[manager]** rebuilder et pousser la nouvelle version :
   ```bash
   cd ../app
   docker build -t localhost:5000/hello:v2 .
   docker push localhost:5000/hello:v2
   ```

3. **[manager]** lancer la mise a jour du service :
   ```bash
   docker service update --image localhost:5000/hello:v2 hello
   ```

4. **[manager]** pendant la mise a jour, observer le remplacement progressif :
   ```bash
   docker service ps hello
   ```

5. **[depuis n'importe ou]** appeler l'appli en boucle pendant la mise a jour :
   ```bash
   for i in $(seq 10); do curl -s http://<ip_vm1>:8080/; sleep 1; done
   ```

## Ce que vous devez observer

- `docker service ps hello` montre les taches `version 1` passant en `Shutdown` et des taches
  `version 2` en `Running`, **par lots** (pas toutes d'un coup).
- Le `curl` en boucle bascule de `version 1` a `version 2` **sans aucune erreur** : la mise a jour
  se fait sans coupure de service.

## Ce qu'il faut retenir

Swarm applique l'etat desire de maniere **controlee**. Le rolling update remplace les replicas par
lots, ce qui garantit la continuite de service pendant le deploiement.

## Pour aller plus loin (optionnel)

- Regler la cadence : `--update-parallelism 2 --update-delay 10s` sur `service update`.
- Revenir a la version precedente : `docker service rollback hello`.
