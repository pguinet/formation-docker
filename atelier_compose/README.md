# Atelier Docker Compose — les bases

Atelier de **45 a 60 minutes** pour decouvrir Docker Compose a partir d'une stack
concrete (PostgreSQL + PGAdmin). On part de la douleur du `docker run` brut, puis on
construit pas a pas un `docker-compose.yml` : un service, un volume nomme, un reseau
prive, puis deux services qui dialoguent.

A la fin, vous savez **expliquer** (pas juste appliquer) :

- pourquoi `docker run` seul perd les donnees, et ce qu'apporte un **volume nomme** ;
- comment un `docker-compose.yml` declare un service, un volume, un reseau ;
- pourquoi un service n'a **pas besoin d'etre expose** a l'hote pour etre joignable par
  un autre conteneur (resolution par **nom de service** sur un reseau Docker) ;
- les commandes Compose de base.

## Prerequis

- Docker Engine (>= 20.10) et plugin `compose` (v2) installes.
- Droit d'executer `docker` sans `sudo`.
- **Port 80 libre** sur la VM et accessible depuis votre navigateur
  (`http://<IP_publique_VM>/`) — utilise par PGAdmin a l'etape 2.

## Parcours

| Etape | Sujet                                            | Etat livre   |
|-------|--------------------------------------------------|--------------|
| 0     | A la main : `docker run`, env, perte de donnees  | CLI, pas de compose |
| 1     | Premier `docker-compose.yml` : 1 service + volume| fonctionne   |
| 2     | Reseau prive + PGAdmin (multi-services)          | fonctionne   |

Chaque etape est un dossier autonome. On y entre, on lit son README, on suit les
instructions, on en sort. Aucune dependance d'ordre stricte : on peut revenir en arriere.

> Le volume nomme `pg_data` est partage entre les etapes (meme `name:`). C'est voulu :
> ca permet de constater la persistance des donnees d'une etape a l'autre.

## Demarrer

```bash
cd etape-0-a-la-main
cat README.md         # lire les instructions
```

Puis `etape-1-premier-compose/`, puis `etape-2-reseau-et-pgadmin/`.

## Commandes Compose de reference

| Commande                    | Effet                                                        |
|-----------------------------|--------------------------------------------------------------|
| `docker compose up`         | Demarre les services en avant-plan (logs a l'ecran).         |
| `docker compose up -d`      | Demarre en arriere-plan (detache).                           |
| `docker compose logs -f`    | Suit les logs de tous les services.                          |
| `docker compose ps`         | Liste les conteneurs **du projet** (vs `docker ps`, global). |
| `docker compose down`       | Arrete et supprime conteneurs + reseau. **Garde** les volumes.|
| `docker compose down -v`    | Comme `down`, mais supprime **aussi** les volumes nommes.    |

## Hors-scope

Durcissement securite (`user:`, `read_only:`, secrets) -> voir `atelier_securisation/`.
Orchestration multi-noeuds (Swarm / Kubernetes) -> ateliers dedies.
