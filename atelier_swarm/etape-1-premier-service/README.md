# Etape 1 — Premier service (echauffement)

## Objectif

Decouvrir le **service**, les **replicas** et le **routing mesh** sur une image publique, avant
d'ajouter la complexite du registre. Etape jetable : on supprime le service a la fin.

## A faire

1. **[manager]** creer un service nginx a 3 replicas, publie sur le port 80 :
   ```bash
   docker service create --replicas 3 --publish 80:80 --name web nginx:alpine
   ```

2. **[manager]** observer l'etat et la repartition des taches :
   ```bash
   docker service ls
   docker service ps web
   ```

3. **[depuis n'importe ou]** appeler les **deux** IP de VM :
   ```bash
   curl http://<ip_vm1>/
   curl http://<ip_vm2>/
   ```

4. **[manager]** changer le nombre de replicas :
   ```bash
   docker service scale web=5
   docker service ps web
   docker service scale web=2
   ```

5. **[manager]** nettoyer avant l'etape suivante :
   ```bash
   docker service rm web
   ```

## Ce que vous devez observer

- `docker service ps web` : les 3 taches sont reparties sur **vm1 ET vm2**.
- `curl` sur les deux IP repond la page nginx (HTTP 200) **meme sur un noeud ou aucune tache web
  ne tourne**. C'est le **routing mesh** : le port publie est ouvert sur tous les noeuds et le
  trafic est route vers un replica disponible.
- `scale web=5` fait apparaitre deux nouvelles taches ; `scale web=2` en arrete trois.

## Ce qu'il faut retenir

Un **service** = un etat desire (N replicas d'une image). Swarm le maintient en permanence.
Le routing mesh rend le service joignable depuis n'importe quel noeud du cluster.

## Pour aller plus loin (optionnel)

Tuer une tache a la main sur un noeud (`docker rm -f <id_conteneur>`) puis `docker service ps web` :
Swarm recree aussitot une tache pour tenir l'etat desire (auto-reschedule).
