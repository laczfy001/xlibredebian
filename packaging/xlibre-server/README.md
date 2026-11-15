# Az XLibre X szerver Debian-csomagolása

Ez a `debian/` mappa készíti a `xserver-xlibre-*` csomagokat a hivatalos
[X11Libre/xserver](https://github.com/X11Libre/xserver) forrásból.

**Eredet:** a [xlibre-debian/xlibre-server](https://github.com/xlibre-debian/xlibre-server)
`xlibre/latest` ágáról lett átvéve, a `fe3eb03` commit (2026-08-13) állapotában. Az pedig a Debian
`xorg-server` csomagolásából származik. A licencfeltételeket a `debian/copyright` tartalmazza –
ezt a fájlt ne töröld.

Innentől ez a mappa a tároló saját része, külső forrásból nem frissül.

## Mikor kell hozzányúlni?

A legtöbb új XLibre-verzióhoz semmit nem kell módosítani: a workflow magától hozzáadja a
changelog-bejegyzést. Ha a build elbukik, a nyitott hibajegyben lévő napló alapján jellemzően
az alábbiak egyike a teendő:

| Hiba a naplóban | Teendő |
|---|---|
| `serverminver bump required, ABI changed!` | Az upstream megváltoztatta a driver ABI-t. A naplóban lévő `diff` alapján frissítsd a `debian/serverminver` fájlt (az első sor a minimális szerververzió legyen, pl. `25.3.0`). A drivereket is újra kell fordítani. |
| `dpkg-source: ... patch ... FAILED` vagy `does not apply` | Egy `debian/patches/` alatti patch már nem illeszkedik. Ha a javítás bekerült az upstreambe, töröld a patchet és a nevét a `debian/patches/series` fájlból; különben igazítsd hozzá. |
| `Unmet build dependencies` | Új vagy újabb build-függőség kell: vedd fel a `debian/control` `Build-Depends` mezőjébe. |
| `dh_install: missing files` vagy `not-installed` | Új vagy eltűnt fájl az upstreamben: igazítsd a megfelelő `debian/*.install` fájlt vagy a `debian/not-installed` listát. |

A javítás után elég commitolni és pusholni: a mappa változása új buildet indít.

## Helyi próba (nem kötelező)

Debian gépen, a tároló gyökeréből:

```sh
sudo apt install git xz-utils dpkg-dev devscripts
bash scripts/prepare-source.sh 25.2.3 packaging/xlibre-server /tmp/xlibre-src
```

Ez elkészíti a forráscsomagot (`.dsc`), és már itt kiderül, ha egy patch nem illeszkedik.
