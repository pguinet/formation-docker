#!/usr/bin/bash
# Test unitaire de lib_vmnames.sh (déterministe, sans dépendance externe).
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/lib_vmnames.sh"

fail=0
assert_eq() { # <description> <attendu> <obtenu>
  if [[ "$2" == "$3" ]]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1"
    echo "  attendu: [$2]"
    echo "  obtenu : [$3]"
    fail=1
  fi
}

exp="prima-animateur-1
prima-animateur-2
prima-user1-1
prima-user1-2
prima-user2-1
prima-user2-2"
assert_eq "list_vm_names 2 2" "$exp" "$(list_vm_names 2 2)"

exp="prima-animateur-1
prima-user1-1
prima-user2-1
prima-user3-1
prima-user4-1
prima-user5-1"
assert_eq "list_vm_names 5 1 (session courante)" "$exp" "$(list_vm_names 5 1)"

assert_eq "vm_fqdn" \
  "prima-user1-1.francecentral.cloudapp.azure.com" \
  "$(vm_fqdn prima-user1-1 francecentral)"

exit $fail
