# Etape 2 — Reseau prive + PGAdmin

## Objectif

Ajouter une IHM (PGAdmin) qui dialogue avec Postgres **sans exposer la base a l'hote**.
On decouvre les reseaux Docker, la resolution par nom de service, le `healthcheck` et
`depends_on: condition: service_healthy`.

## Lire le fichier

Points cles par rapport a l'etape 1 :

- `postgres` n'a **pas** de `ports:` -> la base n'est **pas** accessible depuis l'hote.
- Les deux services partagent le reseau `database` -> ils se voient l'un l'autre.
- `healthcheck` teste que Postgres accepte les connexions (`pg_isready`).
- `pgadmin` attend que Postgres soit **healthy** avant de demarrer (`depends_on`).
- `pgadmin` est expose sur le port **80** de la VM.
- `PGADMIN_LISTEN_ADDRESS: "0.0.0.0"` force PGAdmin a ecouter en **IPv4**. Sans cette
  variable, gunicorn tente de binder `[::]:80` (IPv6) et **crashe** sur un hote ou IPv6
  est desactive (`Can't connect to ('::', 80)`). Cas concret de portabilite a connaitre.

## A faire

1. Demarrer et observer l'ordre de demarrage :
   ```bash
   docker compose up -d
   docker compose logs -f      # PGAdmin demarre APRES que Postgres soit 'healthy'
   ```
   (Quitter les logs avec `Ctrl+C`.)
2. Ouvrir PGAdmin dans le navigateur : `http://<IP_publique_VM>/`
   Login : `admin@example.com` / `Atelier2026!`.
3. *Register server* (clic droit sur *Servers* > *Register* > *Server...*) :
   - Onglet *General* : Name = `atelier` (peu importe).
   - Onglet *Connection* :
     - **Host name/address = `postgres`** (le **nom du service**, PAS une IP !)
     - Port = `5432`
     - Username = `postgres`
     - Password = `Atelier2026!`
   - *Save*.
4. Parcourir : *Servers > atelier > Databases > postgres > Schemas > public > Tables*.
   La table `accounts` (creee aux etapes precedentes, via le volume `pg_data`) est la.

## Verifier l'isolation reseau

Depuis l'hote, tentez de joindre la base directement :

```bash
psql -h localhost -p 5432 -U postgres    # ou: nc -zv localhost 5432
```

-> echec / connexion refusee : **aucun port 5432 n'est publie**. La base n'est joignable
que depuis le reseau `database`, donc par PGAdmin.

**A retenir (lecon cle) :** sur un reseau Docker partage, les conteneurs se resolvent par
**nom de service**. Inutile d'exposer la base a l'hote/Internet pour qu'un autre conteneur
l'utilise. Exposer = surface d'attaque en plus.

## Ce qu'il faut retenir

- Un `networks:` prive isole les services du reste de l'hote.
- `depends_on: condition: service_healthy` fiabilise l'ordre de demarrage.
- On n'expose (`ports:`) que ce qui doit etre joignable de l'exterieur (ici : l'IHM).

## Nettoyer

```bash
docker compose down -v      # supprime conteneurs + volumes de l'atelier (pg_data, pgadmin)
```
