# Atelier securisation Docker Compose

Atelier de **45 a 60 minutes** pour decouvrir, sur une application reelle (Nginx + contenu statique), ce que change l'application de deux directives de securisation cles :

- `user:` -> faire tourner le conteneur en non-root.
- `read_only: true` -> rendre le rootfs du conteneur immuable.

A chaque etape, vous appliquez la directive, **vous observez ce qui change** (et parfois ce qui casse), vous diagnostiquez avec les logs si necessaire, puis vous appliquez le minimum pour debloquer ou pour verrouiller.

## Prerequis

- Docker Engine (>= 20.10) et plugin `compose` (v2) installes.
- Droit d'executer `docker` sans `sudo`.
- Port `8080` libre sur la machine.
- `sudo` disponible (pour nettoyer le fichier root-owned cree a l'etape 0).

## Parcours

| Etape | Sujet                                       | Etat livre               |
|-------|---------------------------------------------|--------------------------|
| 0     | Baseline + demo du danger root              | fonctionne               |
| 1     | Conteneur non-root (user + tmpfs + cap_add) | casse intentionnellement |
| 2     | Rootfs read-only (filet de securite)        | fonctionne deja          |

Chaque etape est un dossier autonome. On y entre, on lit son README, on suit les instructions, on en sort.

## Demarrer

```bash
cd etape-0-baseline
cat README.md         # lire les instructions
docker compose up -d
```

Quand l'etape 0 est OK, passer a `etape-1-non-root/`, puis `etape-2-read-only/`.

## Matrice de verification finale

A executer sur **la compose corrigee** (etat cible) de chaque etape, depuis l'interieur du conteneur (`docker compose exec web sh -c '...'`) :

| Action                                          | Etape 0          | Etape 1               | Etape 2               |
|-------------------------------------------------|------------------|-----------------------|-----------------------|
| `echo X > /usr/share/nginx/html/y`              | OK (fichier root sur host) | denied (`:ro`)      | denied (`:ro`)        |
| `touch /etc/foo`                                | OK               | denied (non-root)     | denied (rootfs ro)    |
| `touch /tmp/foo`                                | OK               | OK (mode 1777)        | denied (rootfs ro)    |
| `touch /var/run/foo`                            | OK               | OK (tmpfs)            | OK (tmpfs)            |
| `id`                                            | uid=0            | uid=101               | uid=101               |
| `curl -I http://localhost:8080/` depuis le host                | 200              | 200                   | 200                   |

Notez deux observations interessantes :
- **`touch /etc/foo`** : refus en etape 1 ET 2 mais pour des raisons differentes. Etape 1 : `Permission denied` (uid 101 ne possede pas `/etc`). Etape 2 : `Read-only file system` (le rootfs entier est verrouille). Meme effet visible, deux mecanismes distincts.
- **`touch /tmp/foo`** : passe de OK a refuse entre etape 1 et 2. En etape 1, `/tmp` est en mode 1777 (writable par tous). En etape 2, il est sur le rootfs verrouille. Si on en avait besoin, il faudrait l'ajouter explicitement aux tmpfs.

Si les 18 cases matchent, vous avez compris l'essentiel.

## Hors-scope (autres ateliers)

`cap_drop ALL`, `no-new-privileges`, `security_opt`, scan d'image (`docker scout`, `trivy`), durcissement Dockerfile (USER, COPY --chown), secrets. Ces sujets pourront faire l'objet d'ateliers ulterieurs.
