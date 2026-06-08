# Etape 1 — Faire tourner Nginx en non-root

## Objectif

Empecher le conteneur de tourner en `root` pour neutraliser le danger demontre a l'etape 0.

## Ce qu'on a deja change par rapport a l'etape 0

- Ajout de `user: "101:101"` (uid/gid de l'utilisateur `nginx` dans l'image).
- Bind mount passe en `:ro` (lecture seule) : meme si quelqu'un arrive a executer du code dans le conteneur, il ne pourra plus modifier le HTML.

## A faire

1. Lancer la compose telle quelle :
   ```bash
   docker compose up -d
   ```
2. Constater que ca ne tourne pas :
   ```bash
   docker compose ps
   docker compose logs web | tail -10
   ```

## Ce que vous devez observer

Le conteneur redemarre en boucle (ou est deja sorti). Les logs contiennent :

```
nginx: [emerg] mkdir() "/var/cache/nginx/client_temp" failed (13: Permission denied)
```

## Diagnostic

Le master nginx essaie de creer des sous-repertoires dans `/var/cache/nginx/` (temporaires pour les requetes) et d'ecrire son PID dans `/var/run/nginx.pid`. Dans l'image officielle, ces deux emplacements appartiennent a `root:root`. Quand on force le process en `uid=101`, il **n'a plus le droit d'y ecrire**.

Verifier vous-meme depuis une copie non-securisee :
```bash
docker run --rm nginx:1.27-alpine sh -c 'ls -ld /var/cache/nginx /var/run'
```
-> ces dossiers sont en mode `755 root:root`.

**Notion centrale :** passer en non-root impose de **rendre ecrivables aux bonnes coordonnees uid/gid** les rares emplacements ou l'application a besoin d'ecrire. La solution propre : leur dedier des `tmpfs` en RAM, possedes par notre uid.

## Solution

Ajouter sous `user: "101:101"` :

```yaml
    cap_add:
      - NET_BIND_SERVICE
    tmpfs:
      - /var/cache/nginx:uid=101,gid=101
      - /var/run:uid=101,gid=101
```

Le bloc `tmpfs:` dedie `/var/cache/nginx` et `/var/run` a des systemes de fichiers en RAM, possedes par notre uid. Les options `uid=101,gid=101` sont indispensables.

Le `cap_add: [NET_BIND_SERVICE]` est ajoute par **portabilite** : sur la machine de cet atelier (Docker recent), il n'est pas strictement necessaire grace au reglage `ip_unprivileged_port_start=0` que Docker applique automatiquement dans le namespace reseau du conteneur. Mais sur une version plus ancienne de Docker ou avec un autre runtime, binder un port < 1024 en non-root demanderait explicitement la capability `CAP_NET_BIND_SERVICE`.

Compose complete :

```yaml
services:
  web:
    image: nginx:1.27-alpine
    user: "101:101"
    cap_add:
      - NET_BIND_SERVICE
    tmpfs:
      - /var/cache/nginx:uid=101,gid=101
      - /var/run:uid=101,gid=101
    ports:
      - "8080:80"
    volumes:
      - ../html:/usr/share/nginx/html:ro
```

> **Astuce** : cette version corrigee est aussi fournie telle quelle dans `docker-compose-fixed.yml`. Pour comparer le cassé et le corrigé sans editer le fichier :
> ```bash
> diff docker-compose.yml docker-compose-fixed.yml
> docker compose -f docker-compose-fixed.yml up -d
> ```

Puis :
```bash
docker compose down
docker compose up -d
curl -I http://localhost:8080/
```

## Verifications

- `docker compose exec web id` -> `uid=101(nginx)`.
- Re-tenter l'attaque de l'etape 0 :
  ```bash
  docker compose exec web sh -c 'echo PWNED2 > /usr/share/nginx/html/pwned2.html'
  ```
  -> echoue (bind mount `:ro`). Le danger de l'etape 0 est neutralise.

## Pour aller plus loin

- `docker compose exec web cat /proc/self/status | grep Cap` : afficher les capabilities effectives du process.
- Tester avec ou sans `cap_add` sur votre machine : sur Docker recent, sans cap_add le bind du port 80 fonctionne quand meme grace a `ip_unprivileged_port_start`. Pourquoi le garder ? Pour qu'on ne soit pas dependant de cette configuration noyau implicite.
- Alternative au `cap_add` : `sysctls: ["net.ipv4.ip_unprivileged_port_start=80"]` dans le service — autorise n'importe quel uid a binder a partir du port 80.

## Nettoyer avant de passer a la suite

```bash
docker compose down
```
