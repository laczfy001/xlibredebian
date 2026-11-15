# XLibre APT tároló Debianra – automatikus frissítéssel

Nem hivatalos Debian tároló az [XLibre X szerverhez](https://github.com/X11Libre/xserver) és a drivereihez.
A [xlibre-debian/debian](https://github.com/xlibre-debian/debian) mintájára készült, de itt
**a GitHub Actions naponta ellenőrzi, van-e új XLibre kiadás, és ha igen, magától lefordítja és publikálja.**
Minden csomag a hivatalos [X11Libre GitHub](https://github.com/X11Libre) forrásaiból készül,
a Debian-csomagolás pedig ebben a tárolóban van – más tárolótól nem függ.

## Hogyan működik

```
naponta 03:17 UTC
   │
   ├─ check    mind a 24 csomag legfrissebb kiadása (packaging/packages.list) + a packaging/ állapota
   │           → ha ez a kombináció még nincs kiadva: build
   ├─ source   upstream forrás + debian/ csomagolás + új changelog bejegyzés → .dsc (mindegyikre)
   ├─ build    stable/testing × amd64/arm64, Debian konténerben, sorrendben:
   │           xorgproto → xlibre-server → 21 driver (a friss szerverre) → xlibre metacsomag
   ├─ release  a .deb-ek GitHub Release-be kerülnek (ez az "állapot", git-be nem kerül bináris)
   ├─ publish  reprepro → aláírt APT tároló → GitHub Pages
   └─ notify   hiba esetén automatikus issue
```

- **Csomagok:** az X szerver (`xserver-xlibre-*`), 10 input és 11 video driver, az
  `x11proto-dev` és az `xlibre` metacsomag. A teljes lista: [packaging/packages.list](packaging/packages.list).
- **Új build indul**, ha bármelyik csomagnak új upstream kiadása jelenik meg, *vagy* ha a
  `packaging/` mappában bármi változik. Ilyenkor minden csomag újrafordul, így a driverek
  mindig az aktuális szerverhez készülnek.
- **A csomagolás ebben a tárolóban van.** Karbantartási útmutató és új csomag felvétele:
  [packaging/README.md](packaging/README.md).
- **Verziószám:** `<epoch>:<upstream>-<rev>+auto<időbélyeg>`, pl. `2:25.2.3-0+auto202611152124`.
  Mindig nagyobb, mint az xlibre-debian azonos alapú csomagja, így onnan átállva is frissít.
- **ABI-védelem:** a szerver csomagolásának `abibumpcheck` lépése leállítja a buildet, ha az új
  upstream verzió megváltoztatja a driver ABI-t – ilyenkor nem kerül ki olyan szerver, amivel a driverek nem mennek.
- **Hiba esetén** semmi nem kerül ki: a tároló a legutóbbi sikeres buildet szolgálja ki tovább.

## Beállítás (egyszer)

1. **Hozd létre a tárolót** GitHubon (nyilvános legyen – az ARM runner és a Pages így ingyenes),
   és töltsd fel ezeket a fájlokat.
2. **Aláíró kulcs:**
   ```sh
   ./scripts/generate-signing-key.sh "Neved" email@cimed.hu
   gh secret set APT_SIGNING_KEY < apt-signing-private.asc
   shred -u apt-signing-private.asc
   ```
3. **Pages:** Settings → Pages → *Build and deployment* → Source: **GitHub Actions**.
4. **Opcionális változók** (Settings → Secrets and variables → Actions → Variables):
   | Változó | Jelentés | Alapérték |
   |---|---|---|
   | `MAINTAINER_NAME`, `MAINTAINER_EMAIL` | a changelog-bejegyzés szerzője | `XLibre auto-builder` |
   | `MIRROR_EXTRAS` | egy másik APT tároló csomagjainak tükrözése (`MIRROR_URL`, `MIRROR_KEY_URL`, `MIRROR_KEY_FPR`) – a saját csomagokat felülírni nem tudja | `false` |
   | `INCLUDE_DBGSYM` | debug csomagok publikálása | `false` |
   | `DEB_BUILD_OPTIONS` | pl. `nocheck` a gyorsabb buildhez | üres |
5. **Első futás:** Actions → *XLibre build és APT tároló* → **Run workflow**.

Kézi futtatáskor megadható konkrét szerververzió (`upstream_version`) és kényszerített újrafordítás (`force`).

## Telepítés a felhasználók gépén

Cseréld ki a `FELHASZNALO/TAROLO` részt a saját GitHub-nevedre és tárolónevedre.
Debian Stable (Trixie) esetén engedélyezd a [backports](https://backports.debian.org/Instructions/) tárolót.

```sh
sudo apt-get update
sudo apt-get install -y ca-certificates curl gpg

curl -fsSL https://FELHASZNALO.github.io/TAROLO/key.asc | gpg --dearmor | sudo tee /usr/share/keyrings/xlibre-auto.pgp > /dev/null

cat <<EOF | sudo tee /etc/apt/sources.list.d/xlibre-auto.sources
Types: deb
URIs: https://FELHASZNALO.github.io/TAROLO/
Suites: main
Components: stable
Signed-By: /usr/share/keyrings/xlibre-auto.pgp
EOF

sudo apt-get update
sudo apt-get install xlibre
```

Debian Testing (Forky) esetén `Components: testing`. Ha korábban az xlibre-debian tárolót
használtad, annak `.sources` fájlját töröld, hogy ne legyen két forrás ugyanarra.

Visszatérés Xorg-ra:

```sh
sudo apt-get remove xlibre 'xserver-xlibre*'
sudo apt-get install xorg
sudo rm -f /etc/apt/sources.list.d/xlibre-auto.sources
```

## Ha elromlik

Sikertelen futásnál automatikusan nyílik egy issue a futás linkjével. A naplóban a `::error::`
sor mutatja, melyik csomag bukott el. Tipikus okok: nem illeszkedő patch, megváltozott driver ABI
(`serverminver`), új build-függőség. A teendőket a [packaging/README.md](packaging/README.md) írja le;
a javítás pusholása után a workflow magától újrapróbálja.

Ilyenkor a tároló a legutóbbi sikeres buildet szolgálja ki tovább.

## Fájlok

| Fájl | Szerep |
|---|---|
| `.github/workflows/update.yml` | a teljes automatika |
| `packaging/packages.list` | a csomagok listája, upstream forrása és fordítási sorrendje |
| `packaging/<csomag>/debian/` | az egyes csomagok Debian-csomagolása |
| `scripts/check-upstream.sh` | minden csomag legfrissebb upstream kiadása + build azonosító |
| `scripts/prepare-source.sh` | egy forráscsomag (.dsc) készítése |
| `scripts/build-binary.sh` | az összes csomag fordítása sorrendben, Debian konténerben |
| `scripts/publish-repo.sh` | APT tároló összeállítása (reprepro) |
| `scripts/generate-signing-key.sh` | aláíró kulcs létrehozása |
| `site/index.html.in` | a tároló nyitóoldala |
