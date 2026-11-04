# Fejlesztési workflow – Steal the Aura Egg

Minden változtatás ugyanazon a körön megy végig:

```
 1. Fejlesztés  ->  2. Ellenőrzés (tools/check.sh)  ->  3. Teszt Studióban  ->  4. Commit + push  ->  5. CI a GitHubon
       ^                                                                                                 |
       +---------------------------------------- ha valami piros -------------------------------------------+
```

## 1. Fejlesztés – mit hol változtass

| Mit akarsz | Hol |
| --- | --- |
| Árak, tojások, ritkaságok, időzítők, event, bolt, bázisszintek | `src/shared/Config.luau` |
| Szerver logika (lopás, bázis, kikelés, mentés, MOG...) | `src/server/*.luau` |
| Kliens (HUD, bolt, MOG gomb, effektek) | `src/client/ClientMain.client.luau` |
| Pálya (bázisok, futópadok, díszek) | `tools/generate_map.py`, utána `python3 tools/generate_map.py` |
| Képernyő-felület (HUD, SHOP, event sáv) | `tools/generate_gui.py`, utána `python3 tools/generate_gui.py` |
| Állatok 3D modelljei | `tools/generate_pets.py` (Blender: `pip install bpy==5.2.3`), utána `python tools/generate_pets.py` |
| Új teszt | `tests/specs/*.spec.luau` |

Élő szinkron Studióval (nem kötelező): `rojo serve`, és a Rojo pluginnal csatlakozol. Így a fájlmentés azonnal megjelenik Studióban.

## 2. Ellenőrzés – egy parancs

```bash
tools/check.sh
```

Hat lépés, és ha bármelyik hibát talál, ott megáll:

1. **Generálás** – a pálya és a GUI újragenerálása (`--models` kapcsolóval az állatoké is)
2. **Generált fájlok** – CI-ben ellenőrzi, hogy a generált fájlok commitolva vannak-e
3. **Lint (selene)** – szintaxis, nem létező vagy fel nem használt változók
4. **Roblox API ellenőrzés** – minden osztály, property, metódus és Enum név összevetése a hivatalos Roblox API listával
5. **Build (rojo)** – elkészül a `StealTheAuraEgg.rbxlx`
6. **Automata tesztek (lune)** – 36 teszt:
   - **játékadatok:** árak, esélyek, kikelési idők, mentési formátum, egyensúly (például hogy minden futópadon lehet-e futni)
   - **mentés:** sérült és régi mentések kezelése
   - **forráskód:** minden fájl lefordul, nincs hiányzó vagy körkörös `require`
   - **kész place fájl:** megvan-e benne minden alkatrész, amit a scriptek név szerint keresnek, a bázisok a szalag felé néznek, nincsenek egymásba lógó részek, és megvan minden GUI elem

Eszközök: `rokit install` (vagy `aftman install`) a projekt mappájában telepíti a pontos verziókat (`aftman.toml`). Linuxon `tools/install_tools.sh` is működik.

## 3. Teszt Studióban (ezt gép nem tudja helyetted)

Nyisd meg a `StealTheAuraEgg.rbxlx`-et, és nézd meg az **Output** ablakot (View → Output). Ne legyen benne piros hiba.
Több játékoshoz: **Test → Clients and Servers → 2 játékos → Start**.

**Gyors kör (minden változtatás után, ~5 perc):**
- [ ] A pálya, a bázisok, a SHOP gomb és a HUD látszik
- [ ] Tojást veszek a szalagról, és megjelenik a bázisomon
- [ ] A zöld padon begyűjtöm a pénzt
- [ ] A piros padon lezárom a bázist, és a másik játékos nem jut be
- [ ] A 2. játékossal ellopom a tojást, hazaviszem, és megjelenik nála
- [ ] Lopás közben megütöm a tolvajt az Aura Bat-tel, és a tojás visszakerül
- [ ] Az Output ablakban nincs piros hiba

**Teljes kör (nagyobb változtatás vagy publikálás előtt):**
- [ ] Kikelés: egy Common tojás kb. 1 perc alatt állattá kel, és a karakterem nagyobb lesz
- [ ] MOG: a nagyobb játékosnál megjelenik a MOG gomb (vagy G), a kisebbik elrepül, és pénz megy át
- [ ] Bázis fejlesztése a sárga terminálnál: lezárt (szürke) talapzatok nyílnak meg
- [ ] Futópad: futás közben nő a Speed, a 2. szintű futópad 100 Speed alatt szól, hogy nem elég
- [ ] AURA STORM: a START STORM gombra lila ég, villámok és Storm tojások jönnek
- [ ] Bolt: minden tétel látszik, ID nélkül „Not set up” felirattal
- [ ] Mentés (csak publikált place-nél, bekapcsolt API hozzáféréssel): kilépés és visszalépés után megvan a pénz, a tojások és a szint
- [ ] Ha importáltad a 3D állatokat: a megfelelő színnel és előre nézve jelennek meg

## 4. Commit és push

```bash
tools/check.sh
git add -A
git commit -m "Mit változtattál, röviden"
git push
```

Csak akkor commitolj, ha a `tools/check.sh` zöld.

## 5. CI a GitHubon

Minden pushnál a GitHub Actions (`.github/workflows/ci.yml`) lefuttatja a teljes `tools/check.sh --ci` ellenőrzést egy tiszta gépen. A kész `StealTheAuraEgg.rbxlx` letölthető az adott futás oldaláról (**Actions** fül → futás → Artifacts).
Ha a CI piros, a hibát a futás naplójában látod. Javítsd, futtasd a `tools/check.sh`-t, és pusholj újra.

## Hibakeresés

| Tünet | Hol keresd |
| --- | --- |
| `[StealTheAuraEgg] Map is missing '...'` az Outputban | Studióban átnevezted vagy törölted a pálya egy részét. A README „Editing the map” része felsorolja, melyik neveket kell megtartani. |
| Nem ment a játék | Publikált place kell, és Game Settings → Security → Enable Studio Access to API Services |
| A bolt „Not set up”-ot ír | Írd be a Game Pass / Developer Product ID-kat a `Config.luau`-ba |
| Egy teszt piros | A teszt neve és üzenete megmondja, mi a baj. A teszt kódja a `tests/specs/` mappában van |
