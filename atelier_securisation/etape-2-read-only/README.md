# Etape 2 — Read-only comme filet de securite

## Objectif

Verrouiller le rootfs du conteneur pour qu'aucune ecriture imprevue ne soit possible — meme si une compromission survient. Comprendre **pourquoi read_only n'apporte rien sur le demarrage** quand on a deja correctement identifie les emplacements writable a l'etape 1, mais **augmente la robustesse**.

## Ce qu'on a deja change par rapport a l'etape 1

- Ajout de `read_only: true` sur le service.

**Aucune autre modification.** Le bloc `tmpfs:` (cache et run) reste necessaire — il l'etait deja en etape 1 pour que nginx puisse demarrer en non-root.

## A faire

1. Lancer la compose :
   ```bash
   docker compose up -d
   ```
2. Constater que **ca tourne** (contrairement a l'etape 1) :
   ```bash
   docker compose ps
   curl -I http://localhost:8080/
   ```

## Ce que vous devez observer

Le conteneur tourne normalement, la page repond `200`. Pas de log d'erreur.

**Pourquoi ?** Parce qu'en etape 1, vous avez deja fait le travail d'identifier les emplacements ou nginx ecrit (`/var/cache/nginx`, `/var/run`) et de les rebasculer sur des tmpfs. `read_only` ne casse rien : il verrouille uniquement le **reste** du rootfs, qui n'etait pas en ecriture de toute facon.

## Ce qui a vraiment change

Faites les memes commandes qu'a l'etape 1 et observez la difference :

| Commande                                                       | Etape 1 (non-root, no read_only) | Etape 2 (+ read_only)   |
|----------------------------------------------------------------|----------------------------------|-------------------------|
| `docker compose exec web touch /etc/foo`                       | Permission denied (uid 101)      | Read-only file system   |
| `docker compose exec web touch /var/run/foo`                   | OK (tmpfs)                       | OK (tmpfs)              |
| `docker compose exec web touch /tmp/foo`                       | OK (mode 1777)                   | Read-only file system   |
| `docker compose exec web sh -c 'echo > /usr/share/nginx/html/x'` | denied (`:ro`)                 | denied (`:ro`)          |

**Notez la difference de raison pour `touch /etc/foo`** : en etape 1 c'etait la non-appartenance a root (mecanisme POSIX classique). En etape 2 c'est le systeme de fichiers entier qui est verrouille — meme un process root du conteneur ne pourrait plus y ecrire.

**Notion centrale :** `read_only` agit uniquement sur le rootfs. Les volumes (`volumes:`) et les tmpfs (`tmpfs:`) declares restent ecrivables. Le `read_only` est le filet final qui catch tout ce que vous avez **oublie** de couvrir.

## Le scenario d'attaque a comparer

Imaginez qu'un attaquant compromet nginx (RCE via une vulnerabilite, peu importe). En etape 1, il pourrait :
- ecrire dans `/usr/local/bin/` un binaire malicieux (rootfs writable),
- modifier `/etc/nginx/nginx.conf` pour ajouter un endpoint backdoor,
- planter un script dans `/etc/cron.d/`.

En etape 2 : impossible — le rootfs est immuable. Il peut au mieux ecrire dans `/var/cache/nginx` et `/var/run` (tmpfs ephemeres) — ca se perd au redemarrage et c'est isole du reste du systeme.

## Verifications

Toutes les actions ci-dessous doivent matcher la colonne "Etape 2" du tableau plus haut. Si une seule case ne matche pas, comparez votre `docker-compose.yml` avec celui livre dans ce dossier.

## Pour aller plus loin

- Pourquoi ne pas avoir ajoute `/tmp` au bloc tmpfs ? Reponse : nginx n'en a pas besoin pour la configuration de l'atelier. Si vous configuriez `client_body_temp_path` ou des modules qui ecrivent dans `/tmp`, il faudrait l'ajouter. Principe : **declarer en tmpfs ce qui est legitime, rien de plus**.
- Que se passe-t-il en redemarrant le conteneur ? Les tmpfs sont vides. C'est le but : aucune persistance involontaire.
- Pour des donnees a conserver entre redemarrages, il faudrait un volume nomme (pas un tmpfs).

## Nettoyer

```bash
docker compose down
```
