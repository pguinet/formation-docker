#!/usr/bin/bash
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
source "$DIR/tests/helpers.sh"
# Source build_image.sh : grâce au source-guard, seules les fonctions sont définies.
source "$DIR/build_image.sh"

# --- smoke_succeeded : vrai uniquement si la sortie contient le marqueur Docker ---
smoke_succeeded "$(printf 'Hello from Docker!\nDocker Compose version v2.29')" && r=0 || r=1
assert_eq "smoke OK si marqueur présent" 0 "$r"
smoke_succeeded "Unable to find image / docker: command not found" && r=0 || r=1
assert_eq "smoke KO si marqueur absent" 1 "$r"

# --- render_cloud_init : remplace __ADMIN_USER__ par l'utilisateur fourni ---
tmpl="$(printf 'runcmd:\n  - usermod -aG docker __ADMIN_USER__\n')"
out="$(render_cloud_init "$tmpl" "prima")"
assert_contains "render : user injecté"      "$out" "usermod -aG docker prima"
assert_not_contains "render : placeholder parti" "$out" "__ADMIN_USER__"

# --- cleanup_build_vm : supprime la VM (disque/NIC en delete-option) ---
resourceGroupName="rg-test"
AZ_CALLS=""
az() { AZ_CALLS+="az $*"$'\n'; return 0; }
cleanup_build_vm "img-builder" >/dev/null
assert_contains "cleanup : vm delete" "$AZ_CALLS" "vm delete -g rg-test -n img-builder --yes"

# --- cloud-init-docker.yaml doit rester en ASCII pur ---
# Le parseur YAML de cloud-init rejette le non-ASCII apres le round-trip base64
# de la custom-data Azure -> config vide -> packages/runcmd sautes (Docker absent).
non_ascii="$(grep -nP '[^\x00-\x7F]' "$DIR/cloud-init-docker.yaml" || true)"
assert_eq "cloud-init ASCII pur (pas d'accent)" "" "$non_ascii"

exit $fail
