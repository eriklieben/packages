# packages

Install my tools with your system's package manager: a pacman repository for Arch Linux and a Scoop bucket for Windows,
both hosted here on GitHub. Updates arrive through the package manager, like any other package.

## What's available

| Package | What it is | Arch Linux | Windows (Scoop) |
|---|---|---|---|
| `erikterm` | GPU terminal with tabs, splits, git worktrees and coding-agent status. | `sudo pacman -S erikterm` | `scoop install eriklieben/erikterm` |

## Arch Linux

The packages and the repository database are GPG-signed with this key, used for nothing else:

```text
D184 5ABF B3BA A7E3 A29B  A1DA 2E14 70A4 5CE8 F07B
```

Trust it once (pacman's keyring is separate from yours):

```sh
sudo pacman-key --recv-keys D1845ABFB3BAA7E3A29BA1DA2E1470A45CE8F07B
sudo pacman-key --finger D1845ABFB3BAA7E3A29BA1DA2E1470A45CE8F07B
sudo pacman-key --lsign-key D1845ABFB3BAA7E3A29BA1DA2E1470A45CE8F07B
```

Compare what `--finger` prints with the fingerprint above before you sign it. No keyserver access? The key is also in
this repository: `curl -fsSLO https://raw.githubusercontent.com/eriklieben/packages/main/eriklieben.asc`, then
`sudo pacman-key --add eriklieben.asc` and the same `--lsign-key`.

Then add the repository, by putting this at the end of `/etc/pacman.conf`:

```ini
[eriklieben]
Server = https://github.com/eriklieben/packages/releases/download/arch
```

Then refresh and install:

```sh
sudo pacman -Sy
sudo pacman -S <package>
```

Updates come with your normal `sudo pacman -Syu`. To remove a package: `sudo pacman -Rs <package>`.

If the key ever changes, the new fingerprint is announced here and in the release notes before packages are signed
with it, and both keys are in `eriklieben.asc` for a while.

## Windows (Scoop)

Install [Scoop](https://scoop.sh) if you don't have it, then add this bucket once:

```powershell
scoop bucket add eriklieben https://github.com/eriklieben/packages
```

Then install:

```powershell
scoop install eriklieben/<package>
```

Update with `scoop update <package>`, or everything with `scoop update *`. To remove a package: `scoop uninstall <package>`.

### Windows without administrator rights

Corporate laptop? The [installer](https://github.com/eriklieben/packages/releases/download/erikterm-v1.0.0/erikterm-win-x64-setup.exe) installs erikterm into your user profile and needs no administrator rights. It is not code-signed, so Windows may warn before it runs, and company application-control policies can still block it.

## How this repository works

| Part | Where | Notes |
|---|---|---|
| Scoop manifests | [`bucket/`](bucket) | One `<package>.json` per package, each pointing at a download with its SHA-256 |
| Arch packages and database | The [`arch` release](https://github.com/eriklieben/packages/releases/tag/arch) | pacman reads `eriklieben.db`, the `.pkg.tar.zst` files and their `.sig` signatures from it |
| Signing key | [`eriklieben.asc`](eriklieben.asc) | The public key the packages and database are signed with |
| Publishing script | [`scripts/publish-arch.sh`](scripts/publish-arch.sh) | Signs packages, adds them to the database, signs it and uploads them |

Package definitions for Arch live in [`arch/`](arch).

### Publishing an Arch package

Run this on an Arch machine, with `gh` logged in and the signing key in your gpg keyring:

```sh
GPGKEY=D1845ABFB3BAA7E3A29BA1DA2E1470A45CE8F07B scripts/publish-arch.sh mypackage-1.0.0-1-x86_64.pkg.tar.zst
```

It downloads the current database and checks its signature, signs the package, adds it, signs the database and uploads
them all with their `.sig` files. Without `GPGKEY` it refuses to touch the signed database.

### Publishing a Scoop package

Add `bucket/<package>.json`:

```json
{
    "version": "1.0.0",
    "description": "What it does",
    "homepage": "https://github.com/eriklieben/packages",
    "license": "Proprietary",
    "architecture": {
        "64bit": {
            "url": "https://github.com/eriklieben/packages/releases/download/<package>-v1.0.0/<package>-win-x64.zip",
            "hash": "<sha256 of the zip>"
        }
    },
    "extract_dir": "<package>",
    "bin": "<package>.exe",
    "shortcuts": [["<package>.exe", "<Package>"]]
}
```

Set `license` to the package's real license.
