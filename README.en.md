# XLibre APT repository for Debian – automatically updated

[Magyar](README.md) | **English**

Unofficial Debian repository for the [XLibre X server](https://github.com/X11Libre/xserver) and its drivers.
Inspired by [xlibre-debian/debian](https://github.com/xlibre-debian/debian), but here
**GitHub Actions checks every day for new XLibre releases and, when there is one, builds and publishes it automatically.**
Every package is built from the official [X11Libre GitHub](https://github.com/X11Libre) sources,
and the Debian packaging lives in this repository – it does not depend on any other repository.

## Installation

```sh
sudo apt-get update
sudo apt-get install -y ca-certificates curl gpg

curl -fsSL https://laczfy001.github.io/xlibredebian/key.asc | gpg --dearmor | sudo tee /usr/share/keyrings/xlibre-auto.pgp > /dev/null

cat <<EOF | sudo tee /etc/apt/sources.list.d/xlibre-auto.sources
Types: deb
URIs: https://laczfy001.github.io/xlibredebian/
Suites: main
Components: stable
Signed-By: /usr/share/keyrings/xlibre-auto.pgp
EOF

sudo apt-get update
sudo apt-get install xlibre
```

On Debian Testing (Forky), use `Components: testing`.

If you previously used the xlibre-debian repository, disable it first so that there are not two
sources for the same packages. `apt-get upgrade` will then move you to these builds, because
their version numbers are always higher:

```sh
sudo rm -f /etc/apt/sources.list.d/xlibre-debian.sources
```

If `apt` reports a missing dependency, also enable Debian
[backports](https://backports.debian.org/Instructions/).

Switching back to Xorg:

```sh
sudo apt-get remove xlibre 'xserver-xlibre*'
sudo apt-get install xorg
sudo rm -f /etc/apt/sources.list.d/xlibre-auto.sources /usr/share/keyrings/xlibre-auto.pgp
sudo apt-get update
```

## How it works

```
daily at 03:17 UTC
   │
   ├─ check    latest release of all 24 packages (packaging/packages.list) + state of packaging/
   │           → if this combination has not been released yet: build
   ├─ source   upstream source + debian/ packaging + new changelog entry → .dsc (for each package)
   ├─ build    stable/testing × amd64/arm64, in a Debian container, in this order:
   │           xorgproto → xlibre-server → 21 drivers (against the fresh server) → xlibre metapackage
   ├─ release  the .deb files go into a GitHub Release (this is the "state"; no binaries in git)
   ├─ publish  reprepro → signed APT repository → GitHub Pages
   └─ notify   automatic issue on failure
```

- **Packages:** the X server (`xserver-xlibre-*`), 10 input and 11 video drivers,
  `x11proto-dev` and the `xlibre` metapackage. Full list: [packaging/packages.list](packaging/packages.list);
  currently published versions: [packages.txt](https://laczfy001.github.io/xlibredebian/packages.txt).
- **Supported systems:**

  | Debian | Component | Architectures |
  |---|---|---|
  | 13 Trixie (stable) | `stable` | amd64, arm64 |
  | Forky (testing) | `testing` | amd64, arm64 |

  On arm64, the x86-only drivers are not built (`vmmouse`, `intel`, `vesa`, `vmware`);
  the `xlibre` metapackage does not require them there.
- **A new build starts** when any package has a new upstream release, *or* when anything
  changes in the `packaging/` directory. All packages are then rebuilt, so the drivers
  always match the current server.
- **The packaging lives in this repository.** Maintenance guide and adding new packages:
  [packaging/README.en.md](packaging/README.en.md).
- **Version numbers:** `<epoch>:<upstream>-<rev>+auto<timestamp>`, e.g. `2:25.2.3-0+auto202611152124`.
  Always higher than the xlibre-debian package of the same upstream version, so switching from there upgrades cleanly.
- **ABI protection:** the server packaging's `abibumpcheck` step stops the build if a new
  upstream version changes the driver ABI – a server that the drivers cannot work with is never published.
- **On failure** nothing is published: the repository keeps serving the last successful build.
- **Releases:** every successful build is published on the [Releases](https://github.com/laczfy001/xlibredebian/releases)
  page, with the list of package versions and downloadable `.deb`/source files.

## When something breaks

A failed run automatically opens an issue with a link to the run. In the log, the `::error::`
line shows which package failed. Typical causes: a patch that no longer applies, a changed driver ABI
(`serverminver`), a new build dependency. What to do is described in [packaging/README.en.md](packaging/README.en.md);
after pushing the fix, the workflow retries automatically.

In the meantime, the repository keeps serving the last successful build.

## Setting up your own instance

This repository is already set up and running. The steps below are only needed if you want to
run your own instance (fork or copy):

1. **Create the repository** on GitHub. Make it public: ARM runners and Pages are free that way.
2. **Signing key:**
   ```sh
   ./scripts/generate-signing-key.sh "Your Name" you@example.com
   gh secret set APT_SIGNING_KEY < apt-signing-private.asc
   shred -u apt-signing-private.asc
   ```
   Keep an offline backup of the private key first: if it is lost, every user has to import a new key.
3. **Pages:** Settings → Pages → *Build and deployment* → Source: **GitHub Actions**.
4. **Optional variables** (Settings → Secrets and variables → Actions → Variables):
   | Variable | Meaning | Default |
   |---|---|---|
   | `MAINTAINER_NAME`, `MAINTAINER_EMAIL` | author of the changelog entries | `XLibre auto-builder` |
   | `MIRROR_EXTRAS` | also mirror the packages of another APT repository (`MIRROR_URL`, `MIRROR_KEY_URL`, `MIRROR_KEY_FPR`) – it cannot override the packages built here | `false` |
   | `INCLUDE_DBGSYM` | publish debug symbol packages | `false` |
   | `DEB_BUILD_OPTIONS` | e.g. `nocheck` for faster builds | empty |
5. **Push the files** (`git push`): this starts the first run automatically, which takes about 10 minutes.

It can also be started manually: Actions → *XLibre build és APT tároló* → **Run workflow**. There you
can specify a server version (`upstream_version`) and force a rebuild (`force`).

## Files

| File | Purpose |
|---|---|
| `.github/workflows/update.yml` | the whole automation |
| `packaging/packages.list` | list of packages, their upstream sources and build order |
| `packaging/<package>/debian/` | Debian packaging of each package |
| `scripts/check-upstream.sh` | latest upstream release of every package + build ID |
| `scripts/prepare-source.sh` | builds one source package (.dsc) |
| `scripts/build-binary.sh` | builds all packages in order, in a Debian container |
| `scripts/publish-repo.sh` | assembles the APT repository (reprepro) |
| `scripts/generate-signing-key.sh` | creates the signing key |
| `site/index.html.in` | the repository's landing page |

## License

The repository's own files (workflow, scripts, landing page) are available under the [GNU GPL v3](LICENSE).
The Debian packaging under `packaging/` and the packages built from it are covered by their own
licenses, given in each package's `debian/copyright` file.
XLibre is the work of the [X11Libre](https://github.com/X11Libre) project; this repository is
unofficial and not affiliated with the project.
