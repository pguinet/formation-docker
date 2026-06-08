# Etape 1 — Premier docker-compose.yml

## Objectif

Remplacer la commande `docker run` de l'etape 0 par un fichier declaratif
`docker-compose.yml`. Un seul service (Postgres) et un volume nomme.

## Lire le fichier

```yaml
services:
  postgres:                       # nom du service (et hostname sur le reseau)
    image: postgres:17-alpine
    environment:                  # remplace les -e de docker run
      POSTGRES_DB: postgres
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: Atelier2026!
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
    name: pg_data                 # nom stable du volume (voir plus bas)
```

## A faire

1. Demarrer :
   ```bash
   docker compose up -d
   docker compose ps      # liste les conteneurs DU projet
   docker ps              # vue globale : comparez les deux
   ```
2. Creer / verifier des donnees :
   ```bash
   docker compose exec postgres psql -U postgres -c '\d accounts'
   ```
   Si vous avez fait l'etape 0 avec le volume `pg_data`, la table `accounts` est **deja
   la**. Sinon, creez-la :
   ```bash
   docker compose exec postgres psql -U postgres -c "CREATE TABLE accounts (user_id SERIAL PRIMARY KEY, username VARCHAR(50) UNIQUE NOT NULL);"
   ```
3. Detruire les conteneurs, garder le volume :
   ```bash
   docker compose down       # supprime le conteneur, PAS le volume nomme
   docker compose up -d
   docker compose exec postgres psql -U postgres -c '\d accounts'   # la table persiste
   ```

## Le piege du nommage des volumes

Sans la cle `name:`, Compose **prefixe** le volume par le nom du projet (le dossier) :
vous obtiendriez `atelier_compose_pgdata` ou `etape-1-premier-compose_pgdata`. En ajoutant
`name: pg_data`, on force un nom **stable et previsible**, reutilisable d'une etape a
l'autre.

```bash
docker volume ls    # -> on voit bien 'pg_data', pas 'xxx_pgdata'
```

## Ce qu'il faut retenir

- `docker compose up -d` lit le fichier et cree service + volume + reseau par defaut.
- `docker compose down` ne supprime **pas** les volumes nommes (il faudrait `down -v`).
- `name:` sur un volume evite le prefixe projet.

## Nettoyer avant de passer a la suite

```bash
docker compose down       # on GARDE le volume pg_data pour l'etape 2
```
