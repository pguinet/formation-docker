# Etape 0 — A la main (la douleur)

## Objectif

Lancer PostgreSQL **sans Compose**, a coups de `docker run`, pour ressentir trois
problemes : la variable d'environnement obligatoire, la difference avant-plan / detache,
et surtout la **perte des donnees** quand on supprime le conteneur. On corrige le dernier
point avec un **volume nomme**.

## A faire

### 1. Demarrer (et echouer)

```bash
docker run -d postgres:17-alpine
docker ps
```

-> `docker ps` ne montre **rien**. Pourquoi ? Relancez en avant-plan pour voir :

```bash
docker run postgres:17-alpine
```

-> message d'erreur : la variable `POSTGRES_PASSWORD` (ou equivalent) est **obligatoire**.
Le conteneur s'arrete aussitot. `Ctrl+C` si besoin.

**A retenir :** `-d` detache (arriere-plan) ; sans `-d` on voit les logs en direct. Et une
image peut exiger des variables d'environnement pour demarrer.

### 2. Demarrer correctement et creer des donnees

```bash
docker run -d --name pg \
  -e POSTGRES_DB=postgres -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=Atelier2026! \
  postgres:17-alpine

docker exec -it pg psql -U postgres
```

Dans `psql` :

```sql
CREATE TABLE accounts (
  user_id    SERIAL PRIMARY KEY,
  username   VARCHAR(50)  UNIQUE NOT NULL,
  password   VARCHAR(50)  NOT NULL,
  email      VARCHAR(255) UNIQUE NOT NULL,
  created_at TIMESTAMP    NOT NULL,
  last_login TIMESTAMP
);
\d accounts
\q
```

### 3. Constater la perte de donnees

```bash
docker stop pg && docker start pg
docker exec -it pg psql -U postgres -c '\d accounts'   # la table est toujours la
```

Maintenant **supprimez** le conteneur et recreez-le comme au point 2 :

```bash
docker rm -f pg
docker run -d --name pg \
  -e POSTGRES_DB=postgres -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=Atelier2026! \
  postgres:17-alpine
docker exec -it pg psql -U postgres -c '\d accounts'
```

-> `Did not find any relation named "accounts"`. **La table a disparu.**

**A retenir :** les donnees vivent dans la couche inscriptible **du conteneur**. Supprimer
le conteneur = perdre les donnees.

### 4. Corriger avec un volume nomme

```bash
docker rm -f pg
docker run -d --name pg \
  -e POSTGRES_DB=postgres -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=Atelier2026! \
  -v pg_data:/var/lib/postgresql/data \
  postgres:17-alpine

docker exec -it pg psql -U postgres -c "CREATE TABLE accounts (user_id SERIAL PRIMARY KEY, username VARCHAR(50) UNIQUE NOT NULL);"
docker volume ls    # -> pg_data apparait
```

Supprimez le conteneur, recreez-le avec **le meme** `-v`, et verifiez :

```bash
docker rm -f pg
docker run -d --name pg \
  -e POSTGRES_DB=postgres -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=Atelier2026! \
  -v pg_data:/var/lib/postgresql/data \
  postgres:17-alpine
docker exec -it pg psql -U postgres -c '\d accounts'   # -> la table SURVIT
```

**A retenir :** un **volume nomme** decouple la persistance du cycle de vie du conteneur.

## Nettoyer avant de passer a la suite

```bash
docker rm -f pg
# On GARDE le volume pg_data : l'etape 1 va le reutiliser.
```

## Pour aller plus loin (optionnel, selon le temps)

- `docker inspect pg` : reperez `Env`, `Image`, `Mounts`, `Entrypoint`, `Cmd`,
  `NetworkSettings`.
- OverlayFS / layers : `lower` (origine), `upper` (la diff), `merged` (la somme),
  `work` (interne a overlayfs).
- Exposer la base avec `-p 5432:5432` et s'y connecter depuis l'hote. Question qui amene
  l'etape 2 : **faut-il vraiment exposer la base au monde exterieur ?**
