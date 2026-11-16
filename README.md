# XLibre APT tároló Debianra – automatikus frissítéssel

**Magyar** | [English](README.en.md)

Nem hivatalos Debian tároló az [XLibre X szerverhez](https://github.com/X11Libre/xserver) és a drivereihez.
A [xlibre-debian/debian](https://github.com/xlibre-debian/debian) mintájára készült, de itt
**a GitHub Actions naponta ellenőrzi, van-e új XLibre kiadás, és ha igen, magától lefordítja és publikálja.**
Minden csomag a hivatalos [X11Libre GitHub](https://github.com/X11Libre) forrásaiból készül,
a Debian-csomagolás pedig ebben a tárolóban van – más tárolótól nem függ.

## Telepítés

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

Debian Testing (Forky) esetén `Components: testing`.

A letöltött kulcs ellenőrzése: a `gpg --show-keys /usr/share/keyrings/xlibre-auto.pgp` által kiírt
ujjlenyomatnak egyeznie kell a [nyitóoldalon](https://laczfy001.github.io/xlibredebian/) közölttel.

Ha korábban a xlibre-debian tárolót használtad, előbb kapcsold ki, hogy ne legyen két forrás
ugyanazokra a csomagokra. Az `apt-get upgrade` ezután a saját buildekre frissít, mert azok
verziószáma mindig nagyobb:

```sh
sudo rm -f /etc/apt/sources.list.d/xlibre-debian.sources
```

Ha az `apt` hiányzó függőséget jelez, engedélyezd a Debian
[backports](https://backports.debian.org/Instructions/) tárolót is.

Visszatérés Xorg-ra:

```sh
sudo apt-get remove xlibre 'xserver-xlibre*'
sudo apt-get install xorg
sudo rm -f /etc/apt/sources.list.d/xlibre-auto.sources /usr/share/keyrings/xlibre-auto.pgp
sudo apt-get update
```

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
  `x11proto-dev` és az `xlibre` metacsomag. A teljes lista: [packaging/packages.list](packaging/packages.list),
  az aktuálisan publikált verziók: [packages.txt](https://laczfy001.github.io/xlibredebian/packages.txt).
- **Támogatott rendszerek:**

  | Debian | Komponens | Architektúrák |
  |---|---|---|
  | 13 Trixie (stable) | `stable` | amd64, arm64 |
  | Forky (testing) | `testing` | amd64, arm64 |

  arm64-en a csak x86-on értelmes driverek nem készülnek el (`vmmouse`, `intel`, `vesa`, `vmware`);
  az `xlibre` metacsomag ott nem is kéri őket.
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
- **Kiadások:** minden sikeres build a [Releases](https://github.com/laczfy001/xlibredebian/releases)
  oldalra kerül, a csomagverziók listájával és a letölthető `.deb`/forrásfájlokkal.

## Ha elromlik

Sikertelen futásnál automatikusan nyílik egy issue a futás linkjével. A naplóban a `::error::`
sor mutatja, melyik csomag bukott el. Tipikus okok: nem illeszkedő patch, megváltozott driver ABI
(`serverminver`), új build-függőség. A teendőket a [packaging/README.md](packaging/README.md) írja le;
a javítás pusholása után a workflow magától újrapróbálja.

Ilyenkor a tároló a legutóbbi sikeres buildet szolgálja ki tovább.

## Biztonság

- **Jogosultságok:** a workflow alapból csak olvasási jogot kap. Írási jogot csak a kiadást
  készítő, a publikáló és a hibajegyet nyitó lépés kér. A fordító lépések, amelyek az upstream
  projektek kódját futtatják, nem kapnak írási jogot, és a tároló tokenje sem marad elérhető számukra.
- **Aláíró kulcs:** csak a publikáló lépés fér hozzá, a fordításokhoz nem kerül el.
- **Az upstream forrás hitelessége:** a szerver kiadási tag-jeit az XLibre vezető fejlesztője
  PGP-vel aláírja. Ha a `SERVER_TAG_KEY_FPR` változó be van állítva, a workflow csak az e kulccsal
  aláírt szerverkiadást fordítja le. Ajánlott bekapcsolni (lásd lent). A driverek tag-jei nincsenek
  aláírva; ezeknél a GitHub-tárolóban kell megbízni.
- **Automatikus aláírás:** a workflow mindent aláír és kiad, amit az upstream kiad. Ha minden
  kiadás előtt kézi jóváhagyást szeretnél: Settings → Environments → `github-pages` →
  *Required reviewers*. Ekkor a publikálás megvárja, hogy jóváhagyd.
- **Tükrözés** (`MIRROR_EXTRAS=true`) csak rögzített kulcs-ujjlenyomattal (`MIRROR_KEY_FPR`) indul.
- **A kulcs lejárata:** a `generate-signing-key.sh` 5 évre szóló kulcsot készít. Lejárat előtt
  hosszabbítsd meg a biztonsági mentésből (`gpg --quick-set-expire <ujjlenyomat> 5y`), töltsd fel
  újra a secretet, és szólj a felhasználóknak, hogy töltsék le újra a `key.asc`-t.

### A szerver aláírás-ellenőrzésének bekapcsolása

Az eddigi kiadásokat ez a kulcs írta alá: `AD5E30F506DB217B8C4D02C9FD134449A70E5E66`
(Enrico Weigelt, metux IT consult, `info@metux.net`). Bekapcsolás előtt ellenőrizd te is:

```sh
git clone -q --depth 1 --branch xlibre-xserver-25.2.3 https://github.com/X11Libre/xserver.git /tmp/xs
git -C /tmp/xs cat-file -p xlibre-xserver-25.2.3 | sed -n '/BEGIN PGP/,$p' | gpg --list-packets | grep 'issuer fpr'
curl -fsSL 'https://keyserver.ubuntu.com/pks/lookup?op=get&options=mr&search=0xAD5E30F506DB217B8C4D02C9FD134449A70E5E66' | gpg --show-keys
```

Ha a két kimenetben ugyanaz az ujjlenyomat szerepel:

```sh
gh variable set SERVER_TAG_KEY_FPR --body AD5E30F506DB217B8C4D02C9FD134449A70E5E66
```

Ha egyszer más kulccsal (vagy aláírás nélkül) jön ki egy kiadás, a build leáll, és hibajegy nyílik.
Ilyenkor nézz utána, valóban hiteles-e a kiadás, és szükség esetén írd át a változót.

## Beállítás saját példányhoz

Ez a tároló már be van állítva és fut. Az alábbi lépések akkor kellenek, ha valaki egy saját
példányt akar indítani belőle (fork vagy másolat):

1. **Hozd létre a tárolót** GitHubon. Legyen nyilvános, mert így ingyenes az ARM runner és a Pages.
2. **Aláíró kulcs:**
   ```sh
   ./scripts/generate-signing-key.sh "Neved" email@cimed.hu
   gh secret set APT_SIGNING_KEY < apt-signing-private.asc
   shred -u apt-signing-private.asc
   ```
   Előtte készíts a privát kulcsról offline biztonsági mentést: ha elveszik, minden felhasználónak új kulcsot kell importálnia.
3. **Pages:** Settings → Pages → *Build and deployment* → Source: **GitHub Actions**.
4. **Opcionális változók** (Settings → Secrets and variables → Actions → Variables):
   | Változó | Jelentés | Alapérték |
   |---|---|---|
   | `MAINTAINER_NAME`, `MAINTAINER_EMAIL` | a changelog-bejegyzés szerzője | `XLibre auto-builder` |
   | `SERVER_TAG_KEY_FPR` | a szerver tag-aláírásának ellenőrzése ezzel a kulccsal (lásd *Biztonság*) | üres (kikapcsolva) |
   | `SERVER_TAG_KEY_URL` | honnan töltse le ehhez a kulcsot | keyserver.ubuntu.com |
   | `MIRROR_EXTRAS` | egy másik APT tároló csomagjainak tükrözése (`MIRROR_URL`, `MIRROR_KEY_URL`, kötelező `MIRROR_KEY_FPR`) – a saját csomagokat felülírni nem tudja | `false` |
   | `INCLUDE_DBGSYM` | debug csomagok publikálása | `false` |
   | `DEB_BUILD_OPTIONS` | pl. `nocheck` a gyorsabb buildhez | üres |
5. **Fájlok feltöltése** (`git push`): ez magától elindítja az első futást, ami kb. 10 perc.

Kézzel is indítható: Actions → *XLibre build és APT tároló* → **Run workflow**. Ekkor megadható
konkrét szerververzió (`upstream_version`) és kényszerített újrafordítás (`force`).

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
| `site/index.html.in`, `site/en.html.in` | a tároló nyitóoldala magyarul és angolul |

## Licenc

A tároló saját fájljai (workflow, szkriptek, nyitóoldal) a [GNU GPL v3](LICENSE) alatt érhetők el.
A `packaging/` alatti Debian-csomagolások és a belőlük készült csomagok a saját licencük alá
tartoznak; ezt csomagonként a `debian/copyright` fájl tartalmazza.
Az XLibre a [X11Libre](https://github.com/X11Libre) projekt munkája; ez a tároló nem hivatalos,
és nem áll kapcsolatban a projekttel.
