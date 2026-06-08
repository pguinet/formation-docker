# Etape 5 — Nettoyage et demantelement

## Objectif

Demonter proprement les services puis le cluster.

## A faire

1. **[manager]** supprimer les services applicatifs et le registre :
   ```bash
   docker service rm hello registry
   ```
   (Si vous avez utilise la variante stack a l'etape 3/4 : `docker stack rm demo`.)

2. **[worker]** quitter le swarm :
   ```bash
   docker swarm leave
   ```

3. **[manager]** quitter le swarm (un manager doit forcer) :
   ```bash
   docker swarm leave --force
   ```

4. **[manager]** verifier :
   ```bash
   docker node ls
   ```

## Ce que vous devez observer

- `docker node ls` apres le `leave --force` renvoie une erreur du type
  `this node is not a swarm manager` : le cluster n'existe plus.

## Ce qu'il faut retenir

Arreter un conteneur d'un service ne suffit pas : Swarm le recree pour tenir l'etat desire. Pour
supprimer reellement, il faut supprimer le **service** (ou la **stack**). Quitter le swarm se fait
noeud par noeud ; le dernier manager doit utiliser `--force`.
