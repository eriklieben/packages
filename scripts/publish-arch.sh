#!/usr/bin/env bash
# Adds Arch packages to the pacman repository kept on this GitHub repo's "arch" release.
#
#   scripts/publish-arch.sh PACKAGE.pkg.tar.zst [MORE...]
#
# Needs repo-add (pacman) and a logged-in gh. PUBLISH_DRY_RUN=DIR builds the database in DIR and uploads nothing.
#
# GPGKEY=<fingerprint> signs, with that secret key of your gpg keyring: every package without a PACKAGE.sig next to it
# gets one, the existing database's signature is checked (repo-add --verify, against the public keys in your keyring)
# and the new database is signed (repo-add --sign). The .sig files are uploaded next to the packages and the database.
# Without GPGKEY nothing is signed, and a database that is signed already is refused: replacing it with an unsigned
# one would break every pacman.conf with SigLevel = Required.
set -euo pipefail

repo=eriklieben/packages
tag=arch
db=eriklieben
key=${GPGKEY:-}

[ $# -gt 0 ] || { echo "usage: $0 PACKAGE.pkg.tar.zst [MORE...]" >&2; exit 2; }
for pkg in "$@"; do
    case "$pkg" in
        *.pkg.tar.zst) [ -f "$pkg" ] || { echo "not found: $pkg" >&2; exit 1; } ;;
        *) echo "not a package: $pkg" >&2; exit 2 ;;
    esac
done
if [ -n "$key" ]; then
    gpg --batch --list-secret-keys -- "$key" >/dev/null 2>&1 || { echo "no secret key $key in the gpg keyring" >&2; exit 1; }
fi

dry_run=${PUBLISH_DRY_RUN:-}
if [ -n "$dry_run" ]; then
    work=$dry_run
    mkdir -p "$work"
else
    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT
    if ! gh release view "$tag" -R "$repo" >/dev/null 2>&1; then
        gh release create "$tag" -R "$repo" --title "Arch Linux packages" \
            --notes "The pacman repository. See the README for how to use it."
    fi
    # Only what is there: the first publish has no database yet, and none before the first signed one has signatures.
    assets=$(gh release view "$tag" -R "$repo" --json assets --jq '.assets[].name')
    patterns=()
    for name in "$db.db.tar.zst" "$db.files.tar.zst" "$db.db.tar.zst.sig" "$db.files.tar.zst.sig"; do
        if grep -qxF -- "$name" <<<"$assets"; then patterns+=(-p "$name"); fi
    done
    if [ ${#patterns[@]} -gt 0 ]; then
        gh release download "$tag" -R "$repo" -D "$work" "${patterns[@]}"
    fi
fi

if [ -z "$key" ] && [ -f "$work/$db.db.tar.zst.sig" ]; then
    echo "the database is signed: set GPGKEY to the signing key's fingerprint to update it" >&2
    exit 1
fi

names=()
for pkg in "$@"; do
    name=$(basename -- "$pkg")
    cp -- "$pkg" "$work/"
    names+=("$name")
    if [ -f "$pkg.sig" ]; then
        cp -- "$pkg.sig" "$work/"
    elif [ -n "$key" ]; then
        gpg --batch --yes --detach-sign --use-agent --no-armor -u "$key" -o "$work/$name.sig" -- "$pkg"
    fi
    if [ -f "$work/$name.sig" ]; then
        gpg --batch --verify -- "$work/$name.sig" "$work/$name"
        names+=("$name.sig")
    fi
done

cd "$work"
pkgs=()
for name in "${names[@]}"; do
    case "$name" in *.sig) ;; *) pkgs+=("$name") ;; esac
done
if [ -n "$key" ]; then
    repo-add -q --verify --sign --key "$key" "$db.db.tar.zst" "${pkgs[@]}"
    # repo-add only warns when signing fails.
    for name in "$db.db.tar.zst" "$db.files.tar.zst"; do
        [ -f "$name.sig" ] || { echo "repo-add did not sign $name" >&2; exit 1; }
    done
else
    repo-add -q "$db.db.tar.zst" "${pkgs[@]}"
fi

# repo-add makes $db.db and $db.files (and their .sig) symlinks, and a release can only hold real files.
uploads=("${names[@]}")
for name in "$db.db" "$db.files"; do
    rm -f -- "$name" "$name.sig"
    cp -- "$name.tar.zst" "$name"
    uploads+=("$name" "$name.tar.zst")
    if [ -n "$key" ]; then
        cp -- "$name.tar.zst.sig" "$name.sig"
        uploads+=("$name.sig" "$name.tar.zst.sig")
    fi
done
rm -f -- "$db".*.old "$db".*.old.sig

if [ -n "$dry_run" ]; then
    echo "dry run: database built in $work${key:+, signed with $key}"
    exit 0
fi

gh release upload "$tag" -R "$repo" --clobber "${uploads[@]}"
echo "published: ${pkgs[*]}${key:+ (signed with $key)}"
