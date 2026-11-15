# Debian-csomagolások

Ebben a mappában van minden csomag Debian-csomagolása (`<csomag>/debian/`). A forráskódot
a workflow mindig a hivatalos [X11Libre GitHub](https://github.com/X11Libre) tárolókból tölti le.
Más tárolótól nem függ.

## A csomagok listája: `packages.list`

A fájl tabulátorral tagolt; a sorrend a **fordítási sorrend** (a driverekhez már a frissen
fordított szerver kell, a metacsomag a végén jön):

| Oszlop | Jelentés |
|---|---|
| mappa | a `packaging/` alatti mappa neve (egyben a Debian forráscsomag neve) |
| upstream | a hivatalos git tároló |
| tag-előtag | a kiadási tag-ek eleje, pl. `xlibre-xf86-input-libinput-` |
| mód | `latest`: mindig a legfrissebb kiadás · `pinned`: a `debian/changelog` szerinti verzió · `native`: a mappa maga a forrás |

Az `xorgproto` (`x11proto-dev`) azért `pinned`, mert a protokollfejlécek a Debian saját
csomagjait is érintik. Csak akkor érdemes léptetni, ha egy új szerververzió megköveteli.

## Eredet

A csomagolások a [xlibre-debian](https://github.com/xlibre-debian) tárolóiból lettek átvéve
(`xlibre/latest` ág, 2026. november 16-i állapot), azok pedig a Debian Xorg-csomagolásából
származnak. A licencfeltételeket minden csomag `debian/copyright` fájlja tartalmazza – ezeket ne töröld.
Innentől minden mappa a tároló saját része, külső forrásból nem frissül.

| Csomag | Átvett commit |
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

## Mikor kell hozzányúlni?

A legtöbb új kiadáshoz semmit nem kell módosítani: a workflow magától hozzáadja a
changelog-bejegyzést. Ha a build elbukik, a nyitott hibajegyben lévő naplóban a `::error::` sor
mutatja, melyik csomag bukott el. A tipikus okok:

| Hiba a naplóban | Teendő |
|---|---|
| `serverminver bump required, ABI changed!` | Az upstream megváltoztatta a driver ABI-t. A naplóban lévő `diff` alapján frissítsd a `xlibre-server/debian/serverminver` fájlt (az első sor a minimális szerververzió, pl. `25.3.0`). A drivereket a workflow ugyanabban a menetben újrafordítja. |
| `patch ... FAILED` vagy `does not apply` | Egy `debian/patches/` alatti patch már nem illeszkedik. Ha a javítás bekerült az upstreambe, töröld a patchet és a nevét a `debian/patches/series` fájlból; különben igazítsd hozzá. |
| `Unmet build dependencies` | Új build-függőség kell: vedd fel a `debian/control` `Build-Depends` mezőjébe. |
| `dh_install: missing files` | Új vagy eltűnt fájl az upstreamben: igazítsd a megfelelő `debian/*.install` fájlt vagy a `debian/not-installed` listát. |

A javítás után elég commitolni és pusholni: a `packaging/` mappa változása új buildet indít.

## Új csomag felvétele

1. Hozd létre a `packaging/<forráscsomag-név>/debian/` mappát (a `Source:` mező a
   `debian/control`-ban egyezzen a mappanévvel).
2. Vedd fel egy sorral a `packages.list`-be, a függőségei **után**.
3. Ha a metacsomagnak is függenie kell tőle, írd be a `xlibre/debian/control` megfelelő
   `*-all` csomagjához.

## Helyi próba (nem kötelező)

Debian gépen, a tároló gyökeréből – elkészíti az összes forráscsomagot, és már itt kiderül,
ha egy patch nem illeszkedik:

```sh
sudo apt install git xz-utils gzip dpkg-dev devscripts
bash scripts/check-upstream.sh
while IFS=$'\t' read -r n v; do bash scripts/prepare-source.sh "$n" "$v" /tmp/xlibre-src; done < build-set.tsv
```
