# Etape 2 — Registre prive

## Objectif

Monter un registre local, deploye comme service Swarm, pour pouvoir partager une image custom
entre les noeuds.

## A faire

1. **[manager]** deployer le registre :
   ```bash
   docker service create --name registry --publish published=5000,target=5000 registry:2
   ```

2. **[manager]** verifier qu'il tourne :
   ```bash
   docker service ls
   ```

3. **[manager] ET [worker]** interroger l'API du registre sur **chaque** noeud :
   ```bash
   curl http://localhost:5000/v2/
   ```

## Ce que vous devez observer

- `docker service ls` : le service `registry` est `1/1`.
- `curl http://localhost:5000/v2/` repond `{}` sur **les deux** noeuds, alors que le conteneur
  registry ne tourne que sur un seul. C'est encore le routing mesh.

## Ce qu'il faut retenir

**Pourquoi un registre ?** Sur un cluster multi-noeuds, chaque noeud doit pouvoir **pull** l'image
d'un service. Une image buildee localement sur vm1 n'existe pas sur vm2 : il faut un point de
distribution commun.

**Pourquoi `localhost:5000` ?** Le routing mesh rend le port 5000 joignable via `localhost` sur
chaque noeud. Et Docker considere `localhost` comme un registre **insecure par defaut** : on peut
donc pull/push en HTTP **sans modifier `daemon.json`** sur aucun noeud. C'est ce qui rend cet
atelier simple.

## Pour aller plus loin (optionnel)

Pour un registre joignable par un **nom d'hote externe** (cas reel, pas `localhost`), il faudrait
soit du TLS (certificat), soit declarer le registre dans `insecure-registries` de `daemon.json`
sur chaque noeud, puis redemarrer le daemon. Hors-scope de cet atelier.
