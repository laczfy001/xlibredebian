# XLibre APT tároló Debianra – automatikus frissítéssel

Nem hivatalos Debian tároló az [XLibre X szerverhez](https://github.com/X11Libre/xserver).
A [xlibre-debian/debian](https://github.com/xlibre-debian/debian) mintájára készült, de itt
**a GitHub Actions naponta ellenőrzi, van-e új XLibre kiadás, és ha igen, magától lefordítja és publikálja.**

## Hogyan működik

```
naponta 03:17 UTC
   │
   ├─ check    legfrissebb xlibre-xserver-* tag  +  xlibre-debian/xlibre-server (xlibre/latest) commit
   │           → ha ez a páros még nincs kiadva: build
   ├─ source   upstream forrás + debian/ csomagolás + új changelog bejegyzés → .dsc
   ├─ build    stable/testing × amd64/arm64 (Debian konténerben, natív ARM runneren)
   ├─ release  a .deb-ek GitHub Release-be kerülnek (ez az "állapot", git-be nem kerül bináris)
   ├─ publish  reprepro: saját xlibre-server + tükrözött driverek/metacsomag → aláírt APT tároló
   │           → GitHub Pages
   └─ notify   hiba esetén automatikus issue
```

- **Új build indul**, ha új upstream verzió jelenik meg, *vagy* ha a Debian-csomagolás
  (xlibre-debian/xlibre-server) változik.
- **Verziószám:** `2:<upstream>-<rev>+auto<időbélyeg>`, pl. `2:25.2.3-0+auto202611152124`.
  Mindig nagyobb, mint az xlibre-debian azonos alapú csomagja, így onnan átállva is frissít.
- **Driverek, `xlibre` metacsomag, `x11proto-dev`:** ezeket az xlibre-debian tárolóból
  tükrözi (a `-dbgsym` és a kulcscsomagok nélkül), így ez a tároló önmagában is elég a telepítéshez.
  Kikapcsolható: `MIRROR_EXTRAS=false` változó.
- **ABI-védelem:** a csomagolás `abibumpcheck` lépése leállítja a buildet, ha az új upstream
  verzió megváltoztatja a driver ABI-t – ilyenkor nem kerül ki olyan szerver, amivel a driverek nem mennek.

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
   | `MIRROR_EXTRAS` | driverek stb. tükrözése | `true` |
   | `MIRROR_KEY_FPR` | a tükrözött tároló kulcsának rögzített ujjlenyomata (ajánlott) | letöltéskor kiolvasva |
   | `INCLUDE_DBGSYM` | debug csomagok publikálása | `false` |
   | `DEB_BUILD_OPTIONS` | pl. `nocheck` a gyorsabb buildhez | üres |
5. **Első futás:** Actions → *XLibre build és APT tároló* → **Run workflow**.

Kézi futtatáskor megadható konkrét verzió (`upstream_version`) és kényszerített újrafordítás (`force`).

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

Sikertelen futásnál automatikusan nyílik egy issue a futás linkjével. Tipikus okok:

- a `debian/patches` már nem illeszkedik az új upstream forrásra,
- megváltozott a driver ABI (`serverminver` – ehhez a drivereket is újra kell fordítani),
- új build-függőség kell, ami még nincs Debianban / backportsban.

Ilyenkor a tároló a legutóbbi sikeres buildet szolgálja ki tovább; amint az xlibre-debian
csomagolása frissül, a következő napi futás magától újrapróbálja.

## Fájlok

| Fájl | Szerep |
|---|---|
| `.github/workflows/update.yml` | a teljes automatika |
| `scripts/check-upstream.sh` | legfrissebb upstream tag + csomagolási commit |
| `scripts/prepare-source.sh` | forráscsomag (.dsc) készítése |
| `scripts/build-binary.sh` | fordítás Debian konténerben |
| `scripts/publish-repo.sh` | APT tároló összeállítása (reprepro) |
| `scripts/generate-signing-key.sh` | aláíró kulcs létrehozása |
| `site/index.html.in` | a tároló nyitóoldala |
