#!/usr/bin/bash
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
source "$DIR/tests/helpers.sh"
source "$DIR/teardown_infra.sh"   # source-guard -> définitions seules

resourceGroupName="rg-test"

# Sans -y : confirmation exigée == saisie exacte du nom du RG.
FORCE=false
echo "rg-test" | confirm_teardown && r=0 || r=1
assert_eq "confirme si nom exact" 0 "$r"
echo "mauvais" | confirm_teardown && r=0 || r=1
assert_eq "refuse si nom faux" 1 "$r"

# Avec -y : confirmation automatique, pas de prompt.
FORCE=true
confirm_teardown </dev/null && r=0 || r=1
assert_eq "force=true confirme sans saisie" 0 "$r"

exit $fail
