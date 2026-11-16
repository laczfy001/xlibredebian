#!/usr/bin/env bash
# Egyszeri lépés: jelszó nélküli GPG kulcs a tároló aláírásához.
# Használat: ./scripts/generate-signing-key.sh "Saját Név" email@cim.hu
# Ezután:   gh secret set APT_SIGNING_KEY < apt-signing-private.asc
#           és töröld biztonságosan a privát kulcsfájlt.
set -euo pipefail
umask 077   # a privát kulcsfájlt csak a tulajdonos olvashassa
NAME=${1:?Név kell}
EMAIL=${2:?E-mail cím kell}
GNUPGHOME=$(mktemp -d)
export GNUPGHOME
gpg --batch --quiet --passphrase '' --quick-gen-key "$NAME (XLibre APT) <$EMAIL>" ed25519 sign 5y
FPR=$(gpg --list-secret-keys --with-colons | awk -F: '/^fpr/{print $10; exit}')
gpg --armor --export-secret-keys "$FPR" > apt-signing-private.asc
gpg --armor --export "$FPR" > apt-signing-public.asc
rm -rf "$GNUPGHOME"
echo "Ujjlenyomat: $FPR"
echo "Privát kulcs: apt-signing-private.asc  (-> GitHub secret: APT_SIGNING_KEY)"
echo "Publikus kulcs: apt-signing-public.asc (a workflow automatikusan publikálja key.asc néven)"
