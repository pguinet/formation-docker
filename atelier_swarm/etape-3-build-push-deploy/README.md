# Etape 3 — Build, push et deploiement de l'appli custom

## Objectif

Construire l'image hello-hostname, la pousser au registre, la deployer en service et observer le
load-balancing entre replicas.

L'appli (`../app/`) est un mini serveur HTTP Python qui renvoie a chaque requete le **hostname du
conteneur** qui repond et un **numero de version**.

## A faire

1. **[manager]** se placer dans le dossier de l'appli :
   ```bash
   cd ../app
   ```

2. **[manager]** construire l'image en la taguant pour le registre local :
   ```bash
   docker build -t localhost:5000/hello:v1 .
   ```

3. **[manager]** pousser l'image au registre :
   ```bash
   docker push localhost:5000/hello:v1
   ```

4. **[manager]** deployer le service (3 replicas, publie sur 8080) :
   ```bash
   docker service create --name hello --replicas 3 --publish 8080:8080 localhost:5000/hello:v1
   ```

5. **[manager]** verifier la repartition :
   ```bash
   docker service ps hello
   ```

6. **[depuis n'importe ou]** appeler l'appli plusieurs fois de suite :
   ```bash
   for i in $(seq 6); do curl -s http://<ip_vm1>:8080/; done
   ```

## Ce que vous devez observer

- `docker service ps hello` : les 3 taches sont `Running`, **y compris sur le worker** — preuve
  que vm2 a su **pull l'image depuis `localhost:5000`** via le routing mesh.
- Le `curl` en boucle affiche **des hostnames differents** d'une requete a l'autre : le trafic est
  load-balance entre les replicas, sur les deux noeuds.

## Ce qu'il faut retenir

Le cycle complet **build -> push -> deploy** d'une image maison sur un cluster. Le registre rend
l'image disponible a tous les noeuds ; le routing mesh repartit les requetes.

## Pour aller plus loin (variante declarative)

Au lieu de `docker service create`, on peut decrire l'etat desire dans un fichier et le deployer :
```bash
docker stack deploy -c ../app/stack.yml demo
docker stack services demo
```
`docker stack deploy` est l'equivalent declaratif de `docker compose up`, mais pour Swarm : l'etat
est **versionne dans un fichier** (`stack.yml`) plutot que passe en arguments. On reutilisera cette
approche a l'etape 4.
