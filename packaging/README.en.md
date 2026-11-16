# Debian packaging

[Magyar](README.md) | **English**

This directory holds the Debian packaging of every package (`<package>/debian/`). The workflow
always downloads the source code from the official [X11Libre GitHub](https://github.com/X11Libre)
repositories. It does not depend on any other repository.

## The package list: `packages.list`

The file is tab-separated; the line order is the **build order** (the drivers need the freshly
built server, the metapackage comes last):

| Column | Meaning |
|---|---|
| directory | directory name under `packaging/` (also the Debian source package name) |
| upstream | the official git repository |
| tag prefix | the beginning of the release tags, e.g. `xlibre-xf86-input-libinput-` |
| mode | `latest`: always the newest release · `pinned`: the version in `debian/changelog` · `native`: the directory itself is the source |

`xorgproto` (`x11proto-dev`) is `pinned` because the protocol headers also affect Debian's own
packages. Only bump it when a new server version requires it.

## Origin

The packaging was taken over from the [xlibre-debian](https://github.com/xlibre-debian) repositories
(`xlibre/latest` branch, as of 16 November 2026), which in turn derive from Debian's Xorg packaging.
The license terms are in each package's `debian/copyright` file – do not delete these.
From now on every directory is part of this repository and is not updated from any external source.

| Package | Imported commit |
|---|---|
| xlibre-server | `fe3eb03` |
| xorgproto | `7095514` |
| xlibre | `0a0c7c1` |
| xserver-xlibre-input-elographics | `0abe32a` |
| xserver-xlibre-input-evdev | `114775d` |
| xserver-xlibre-input-joystick | `6265e68` |
| xserver-xlibre-input-keyboard | `b4efa9d` |
| xserver-xlibre-input-libinput | `a5cdb75` |
| xserver-xlibre-input-mouse | `8457ac3` |
| xserver-xlibre-input-synaptics | `c065a62` |
| xserver-xlibre-input-vmmouse | `57deb13` |
| xserver-xlibre-input-void | `0515833` |
| xserver-xlibre-input-wacom | `1a2bae0` |
| xserver-xlibre-video-amdgpu | `57558b1` |
| xserver-xlibre-video-ati | `a488103` |
| xserver-xlibre-video-dummy | `7755db4` |
| xserver-xlibre-video-fbdev | `572d730` |
| xserver-xlibre-video-intel | `64a3029` |
| xserver-xlibre-video-nouveau | `eb2f1d7` |
| xserver-xlibre-video-qxl | `ef2b4c3` |
| xserver-xlibre-video-sisusb | `2d0f0ad` |
| xserver-xlibre-video-vesa | `8ca9947` |
| xserver-xlibre-video-vmware | `7061472` |
| xserver-xlibre-video-voodoo | `3048093` |

## When do you need to touch it?

Most new releases need no changes at all: the workflow adds the changelog entry automatically.
If the build fails, the `::error::` line in the log linked from the opened issue shows which package
failed. Typical causes:

| Error in the log | What to do |
|---|---|
| `serverminver bump required, ABI changed!` | Upstream changed the driver ABI. Update `xlibre-server/debian/serverminver` based on the `diff` in the log (the first line is the minimum server version, e.g. `25.3.0`). The workflow rebuilds the drivers in the same run. |
| `patch ... FAILED` or `does not apply` | A patch under `debian/patches/` no longer applies. If the fix has been merged upstream, delete the patch and remove its name from `debian/patches/series`; otherwise adapt it. |
| `Unmet build dependencies` | A new build dependency is needed: add it to the `Build-Depends` field in `debian/control`. |
| `dh_install: missing files` | A file was added or removed upstream: adjust the matching `debian/*.install` file or the `debian/not-installed` list. |

After the fix, just commit and push: any change in `packaging/` starts a new build.

## Adding a new package

1. Create the `packaging/<source-package-name>/debian/` directory (the `Source:` field in
   `debian/control` must match the directory name).
2. Add a line to `packages.list`, **after** its dependencies.
3. If the metapackage should depend on it, add it to the matching `*-all` package in
   `xlibre/debian/control`.

If a package can only be built on some architectures (according to the `Architecture:` field in
`debian/control`, e.g. `any-amd64`), the build script skips it automatically on the others.

## Local test (optional)

On a Debian machine, from the repository root – builds all source packages, so you see right away
if a patch no longer applies:

```sh
sudo apt install git xz-utils gzip dpkg-dev devscripts
bash scripts/check-upstream.sh
while IFS=$'\t' read -r n v; do bash scripts/prepare-source.sh "$n" "$v" /tmp/xlibre-src; done < build-set.tsv
```
