# Etape 0 — Baseline et danger du root

## Objectif

Faire tourner Nginx avec une compose minimale, puis observer **concretement** ce qu'un conteneur root peut faire sur le host via un bind mount.

## A faire

1. Demarrer le conteneur :
   ```bash
   docker compose up -d
   ```
2. Verifier que la page s'affiche : ouvrir <http://localhost:8080> ou
   ```bash
   curl -I http://localhost:8080/
   ```
3. Verifier qui execute Nginx :
   ```bash
   docker compose exec web ps -o user,pid,args
   ```
   -> le master tourne en `root`.
4. Demonstration du danger :
   ```bash
   docker compose exec web sh -c 'echo PWNED > /usr/share/nginx/html/pwned.html'
   ls -la ../html/pwned.html
   ```
   -> le fichier sur **votre host** appartient a `root:root`. Vous ne pouvez pas le supprimer sans `sudo`.

## Ce qu'il faut retenir

Un conteneur qui tourne en root + un bind mount = un canal d'ecriture privilegiee dans votre systeme de fichiers hote. C'est ce qu'on va corriger a l'etape 1.

## Nettoyer avant de passer a la suite

```bash
sudo rm ../html/pwned.html
docker compose down
```
