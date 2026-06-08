#!/usr/bin/bash
# Helpers partagés pour les tests bash. À sourcer après avoir défini `fail=0`
# (ou laisser ce fichier l'initialiser).
: "${fail:=0}"

assert_eq() { # <description> <attendu> <obtenu>
  if [[ "$2" == "$3" ]]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1"; echo "  attendu: [$2]"; echo "  obtenu : [$3]"; fail=1
  fi
}

assert_contains() { # <description> <chaine> <sous-chaine attendue>
  if [[ "$2" == *"$3"* ]]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1"; echo "  [$2] ne contient pas [$3]"; fail=1
  fi
}

assert_not_contains() { # <description> <chaine> <sous-chaine interdite>
  if [[ "$2" != *"$3"* ]]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1"; echo "  [$2] contient [$3] (non attendu)"; fail=1
  fi
}
