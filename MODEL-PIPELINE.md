# Vom .blend zum funktionierenden Optiwand

Klick-fuer-Klick-Anleitung fuer `MirrorgunModel.blend` + `Data.rar`, ohne Blender-Vorkenntnisse.
Blender-Bezeichnungen sind auf Englisch, so wie sie bei dir auf dem Bildschirm stehen.

Die englische Fassung [MODEL-PIPELINE.en.md](MODEL-PIPELINE.en.md) ist die kompakte
technische Uebersicht fuer jemanden, der Blender schon kann - **nicht** diese Anleitung hier
auf Englisch.

Das Modell ist inzwischen fertig eingebaut und im Spiel eingemessen. Diese Anleitung
beschreibt den Weg dorthin - als Nachschlagewerk, wenn das Modell nochmal ueberarbeitet wird
oder ein zweites dazukommt.

Der komplette Ablauf steckt in `tools/blender_setup_all.py`: Ausrichtung, Ursprung, LODs,
Materialpfade, Memory-Punkte und Export in einem Durchlauf, wiederholbar.

---

## Erst mal: nein, die Data.rar kommt nicht in Blender

Das war deine Frage, und die Antwort ist angenehm kurz.

Blender speichert Texturen nicht - es speichert nur **Pfade als Text**. Die eigentlichen
Dateien braucht spaeter Arma, nicht Blender. Es gibt also nirgends ein "Import"-Feld fuer die
rar.

**Aber** in deiner Blend-Datei stehen schon Pfade drin, und die lauten:

```
//Data\mirrorgun.rvmat
//Data\SOF_Mirrorgun_co.png
```

Die zwei Schraegstriche am Anfang heissen bei Blender "neben der .blend-Datei". Damit die
aufgehen, machst du genau das:

1. Rechtsklick auf `Data.rar` auf dem Desktop
2. **Extract Here** (bei WinRAR: *Hier entpacken*)
3. Es entsteht ein Ordner `Data` **direkt neben** `MirrorgunModel.blend` auf dem Desktop

**Zum Namen:** das `SOF_` in den Originaldateien ist das Kuerzel des Erstellers und bedeutet
fuer Arma nichts. Die vier Texturen liegen darum in diesem Repo unter `art/optiwand/` mit
sauberen Namen (`mirrorgun_co.png`, `_nohq`, `_smdi`, `_as`). Von dort werden sie nach
`addons/optiwand/data/` konvertiert. Die Dateien auf dem Desktop bleiben unangetastet - die
.blend zeigt mit ihren Bildpfaden darauf, und die willst du nicht kaputtmachen.

Mehr nicht. Blender findet die Textur dann von selbst. Wenn das Modell im Viewport trotzdem
grau oder pink aussieht: **egal**. Wie es in Blender aussieht, hat null Einfluss darauf, wie
es in Arma aussieht. Dafuer zaehlt nur, was spaeter in Schritt 5 in den Pfadfeldern steht.

---

## Teil 1: Wo ist in Blender was

Damit du weisst, wovon ich rede. Vier Bereiche brauchst du:

| Bereich | Wo | Wofuer |
| --- | --- | --- |
| **3D Viewport** | die grosse Flaeche in der Mitte | das Modell |
| **Outliner** | Liste oben rechts | alle Objekte, hier klickst du sie an |
| **Properties** | Kasten unten rechts | Einstellungen, hat links eine Reihe kleiner Symbol-Reiter |
| **Sidebar** | rechts **im** Viewport, oeffnet mit Taste `N` | hier sitzt die Arma Toolbox |

Zwei Dinge, die bei Blender staendig schiefgehen:

* **Tastenkuerzel wirken dort, wo die Maus steht.** Nicht dort, wo du zuletzt geklickt hast.
  Wenn ich "druecke `N`" schreibe, muss die Maus ueber dem 3D Viewport stehen.
* Es gibt **Object Mode** und **Edit Mode**. Umschalten mit `Tab`, Maus ueber dem Viewport.
  Oben links im Viewport steht immer, in welchem du gerade bist.

Speichern zwischendurch mit `Strg+S`. Mach das nach jedem Teil.

---

## Teil 2: Aufraeumen

Im **Outliner** oben rechts stehen unter anderem:

```
Camera
Camvert
Light
MirrorLP
Screenplane_extra
Screenplane_old
```

Weg damit:

1. Klick im Outliner auf **`Camera`**
2. Halte `Strg` und klick zusaetzlich auf **`Light`** und **`Screenplane_old`**
3. Rechtsklick auf eines der markierten → **Delete**

`Camvert` **noch nicht loeschen**. Der Name klingt nach "Camera Vertex", das koennte ein
Hilfspunkt sein, den der Ersteller extra dahin gesetzt hat, wo die Kamera sitzen soll. Klick
ihn im Outliner an und schau im Viewport, wo er liegt. Sitzt er vorne am Spiegelkopf, heb ihn
auf - er ist eine perfekte Vorlage fuer die Memory-Punkte in Teil 7. Ist es irgendein Rest
mitten im Nichts, loesch ihn genauso wie die anderen.

Uebrig bleiben muessen: **`MirrorLP`** und **`Screenplane_extra`** (plus ggf. `Camvert`).

---

## Teil 3: Groesse pruefen und Transformationen anwenden

**Groesse pruefen:**

1. Klick im Outliner auf **`MirrorLP`**
2. Maus in den 3D Viewport, druecke **`N`** → rechts klappt die Sidebar auf
3. Oben rechts an der Sidebar sind senkrechte Reiter. Klick auf **`Item`**
4. Unter **Dimensions** stehen drei Zahlen: X, Y, Z

Eine Blender-Einheit ist bei Arma ein Meter. Die groesste der drei Zahlen sollte also grob
zwischen **0.4 und 0.9** liegen. Steht da 40 oder 0.004, ist das Modell im falschen Massstab -
dann sag mir die Zahlen, bevor du weitermachst.

**Transformationen anwenden** - der Schritt, an dem die meisten Modelle sterben:

1. Maus in den Viewport, druecke **`A`** (waehlt alles aus)
2. Oben im Viewport im Menue: **Object → Apply → All Transforms**

Damit werden Position, Drehung und Skalierung fest ins Modell eingebacken. Ueberspringst du
das, ist der Stab ingame gern mal zwanzigmal zu gross.

---

## Teil 4: Screen mit dem Hauptmesh verbinden

Ein LOD muss **ein** Objekt sein. Also kommt die Bildschirmflaeche ins Hauptmesh.

1. Klick im Outliner auf **`Screenplane_extra`**
2. Halte `Strg` und klick auf **`MirrorLP`**

   Wichtig: **`MirrorLP` als zweites**. Das zuletzt geklickte Objekt ist das aktive, und beim
   Verbinden ueberlebt dessen Name. Im Outliner ist es an der etwas helleren Schrift zu
   erkennen.
3. Maus in den Viewport, druecke **`Strg+J`**

Im Outliner steht jetzt nur noch `MirrorLP`. Der Bildschirm steckt darin.

---

## Teil 5: Die Vertex Group `screen`

Das ist der wichtigste Schritt der ganzen Anleitung. Ohne ihn bleibt der Bildschirm spaeter
tot.

**Bildschirmflaechen auswaehlen:**

1. `MirrorLP` ist noch ausgewaehlt. Maus in den Viewport, druecke **`Tab`** → du bist im
   **Edit Mode** (oben links im Viewport kontrollieren)
2. Druecke **`3`** → Face-Select-Modus (du waehlst jetzt Flaechen statt Punkte)
3. Druecke **`Alt+A`** → alles abwaehlen
4. Dreh die Ansicht so, dass du den Bildschirm siehst. Drehen: **mittlere Maustaste gedrueckt
   halten** und bewegen. Zoomen: Mausrad.
5. Fahr mit der Maus **ueber die Bildschirmflaeche** und druecke **`L`**

   `L` waehlt alles aus, was mit der Flaeche unter der Maus zusammenhaengt. Da der Screen ein
   eigenes Objekt war, haengt er mit dem Rest nicht zusammen - du bekommst also exakt den
   Bildschirm und sonst nichts. Er ist jetzt orange umrandet.

   Ist versehentlich das ganze Modell orange, hat `L` zu viel erwischt: `Alt+A`, Maus genauer
   auf die Bildschirmflaeche, nochmal `L`.

**Gruppe anlegen und zuweisen:**

6. Unten rechts im **Properties**-Kasten: links die senkrechte Symbolleiste. Klick auf das
   **gruene Dreieck** (Object Data Properties). Beim Draufzeigen erscheint der Name.
7. Klapp den Bereich **Vertex Groups** auf
8. Klick rechts daneben auf **`+`** → es erscheint ein Eintrag namens `Group`
9. **Doppelklick** auf `Group`, tippe **`screen`**, `Enter`

   Kleinschreibung, keine Leerzeichen. Der Name muss exakt so sein.
10. Darunter steht ein Feld **Weight**. Da muss **1.000** stehen (Standard).
11. Klick auf **Assign**

**Kontrolle:** Druecke `Alt+A` (alles abwaehlen), dann bei Vertex Groups auf **Select**. Wenn
genau der Bildschirm wieder orange wird, sitzt es.

Der Kasten **Arma Toolbox: Hidden Selection Maker** in der Sidebar ist **nicht** dafuer da,
das zu kontrollieren. Der zeigt nichts an - da tippst du einen Namen rein (voreingestellt
steht `camo` drin) und er legt dir daraus eine Vertex Group an. Also genau das, was du oben
schon von Hand gemacht hast. Finger weg, sonst hast du zwei.

**Nur eine Gruppe fuer den Bildschirm.** In der Liste steht vielleicht schon ein `Screen` mit
grossem S vom Ersteller. Arma unterscheidet bei Selection-Namen keine Gross- und
Kleinschreibung, zwei Gruppen `Screen` und `screen` kollidieren beim Export also, und welche
gewinnt ist nicht vorhersagbar. Loesch die alte:

* Klick `Screen` in der Liste an
* Klick rechts neben der Liste auf das **`−`** (unter dem `+`)

Nicht zu verwechseln mit dem Knopf **Remove** unter `Assign / Remove / Select / Deselect` -
der nimmt nur die markierten Punkte aus der Gruppe raus und loescht die Gruppe selbst nicht.
Eine Gruppe `Mirrorgun` darf bleiben, zusaetzliche Selections stoeren nicht.

12. `Tab` druecken → zurueck in den Object Mode

Warum das so wichtig ist: `screen` steht schon an beiden Stellen im Mod, die das brauchen -
in `addons/optiwand/model.cfg` unter `sections[]` und in `CfgWeapons.hpp` unter
`hiddenSelections[]`. Ueber diesen Namen findet Arma spaeter die Flaeche und legt das
Kamerabild drauf.

---

## Der schnelle Weg durch Teil 6 bis 8

Alles ab hier - Materialpfade, Bildschirm-Material, alle drei LODs, die Memory-Punkte und der
p3d-Export - macht ein einziges Skript. Von Hand ist es die halbe Nacht, per Skript eine
halbe Minute, und es rechnet die Punkte aus dem Modell aus statt sie nach Augenmass zu setzen.

1. Reiter **`Scripting`** oben in der Leiste
2. **Text → Open** → `Optiwand	oolslender_setup_all.py` → **Open Text**
3. **`Run Script`** (Dreieck oben rechts im Editor)
4. **Window → Toggle System Console** - dort steht der Bericht

Das Skript schaltet auch die Arma Toolbox ein, falls sie nach einem Neustart nicht mitkam,
und speichert die .blend am Ende selbst. Mehrfach ausfuehren schadet nicht.

Die Abschnitte darunter beschreiben dieselben Schritte von Hand - als Nachschlagewerk, wenn
etwas klemmt oder du nachvollziehen willst, was passiert.

---

## Teil 6: Materialpfade auf die Mod-Pfade umstellen

In Blender stehen Blender-Pfade. Arma braucht Arma-Pfade.

1. `MirrorLP` im Outliner anklicken
2. Im **Properties**-Kasten links auf die **karierte Kugel** (Material Properties)
3. Oben siehst du eine Liste mit den Materialien des Objekts. Bei dir stehen dort zwei:
   `mirrorgun` und `mirrorgun.002`. Das ist so in Ordnung - beim Verbinden in Teil 4
   raeumt Blender doppelte Slots weg.
4. Klick das erste an
5. Scroll im selben Kasten nach unten bis zum Bereich **Arma Toolbox Material Settings**.
   Darin ist eine Zeile mit den Knoepfen **Texture / Color / Custom** (Texture ist richtig),
   darunter zwei Textfelder: **Face Texture** und **RV Material file**.
6. Trag ein:

   | Feld | Wert |
   | --- | --- |
   | Face Texture | `z\opw\addons\optiwand\data\mirrorgun_co.paa` |
   | RV Material file | `z\opw\addons\optiwand\data\mirrorgun.rvmat` |

7. Dasselbe fuer jedes weitere `mirrorgun`-Material in der Liste.

8. **Jetzt der Bildschirm.** In der Materialliste steht wahrscheinlich **kein**
   `mirrorgun_screen` - das Material hing am geloeschten `Screenplane_old` und ist beim
   Aufraeumen mitgegangen. Die Bildschirmflaechen selbst sind da, sie teilen sich nur ein
   Material mit dem Rest. Also legst du eins an:

   a. Rechts neben der Materialliste auf das kleine **`+`** → ein leerer Slot erscheint
   b. Darunter auf **New** → es entsteht `Material.001`
   c. Ins Namensfeld klicken, in **`mirrorgun_screen`** umbenennen, `Enter`
   d. Unter **Arma Toolbox Material Settings** eintragen:

      | Feld | Wert |
      | --- | --- |
      | Face Texture | *leer lassen* |
      | RV Material file | `z\opw\addons\optiwand\data\screen.rvmat` |

   e. Maus in den Viewport, **`Tab`** (Edit Mode), **`3`** (Face-Modus), **`Alt+A`**
   f. Im Properties-Kasten aufs **gruene Dreieck** (Object Data Properties) → **Vertex
      Groups** → `screen` anklicken → Knopf **Select** → der Bildschirm wird orange
   g. Zurueck auf die **karierte Kugel** (Material Properties), in der Liste
      **`mirrorgun_screen`** anklicken, dann **Assign**
   h. **`Tab`** zurueck in den Object Mode

   Die Face Texture bleibt leer, weil Arma da spaeter das Kamerabild reinlegt. Das
   `screen.rvmat` legst du in Teil 9 an.

Die Pfade beginnen **ohne** Schraegstrich und benutzen Backslashes. Die Dateien gibt es noch
nicht - das ist in Ordnung, es sind nur Textfelder.

---

## Teil 7: LODs

Ein Arma-Modell besteht aus mehreren Ebenen. Du brauchst drei.

### 7a: Das sichtbare Modell

1. `MirrorLP` im Outliner anklicken
2. Maus in den Viewport, **`N`** falls die Sidebar zu ist
3. An der Sidebar rechts stehen senkrechte Reiter: `Item`, `Tool`, `View`, `Animation`,
   **`Arma 3`**, **`Arma 3 Tools`**. Klick auf **`Arma 3`**.

   Die zwei Arma-Reiter sind leicht zu verwechseln. **`Arma 3 Tools`** ist der Werkzeugkasten
   (Weight Tools, Relocation, VGroup Maker, Proxy Tools). Die LOD-Einstellungen sind
   ausschliesslich im Reiter **`Arma 3`**.
4. Im Kasten **Arma Object Properties** ganz oben die Checkbox einschalten.

   Solange die aus ist, ist der Rest des Kastens leer - die LOD-Felder erscheinen erst
   danach. Deshalb findest du sie vorher nicht.
5. **LOD Preset** auf **`Custom`** lassen und im Feld **`Resolution`** direkt darunter eine
   **`0`** eintragen.

   In der langen Auswahlliste steht **kein** "Resolution" - such da nicht danach. Sichtbare
   Modell-Ebenen laufen in der Toolbox ueber `Custom` plus die Zahl. `0` ist die erste und
   detaillierteste. Aus der Liste waehlst du nur bei den naechsten beiden LODs etwas aus.
6. Weiter unten ist eine Liste **Named Properties**. Klick `+`, dann eintragen:

   | Name | Value |
   | --- | --- |
   | `autocenter` | `0` |

   Ohne das zentriert Arma das Modell selbst und es sitzt schief in der Hand.

### 7b: Geometry

Das ist die Kollisionsform fuer die abgelegte Waffe. Sie darf grob sein.

1. `MirrorLP` anklicken, Maus in den Viewport, **`Shift+D`** dann sofort **`Esc`**

   Das dupliziert ohne zu verschieben. Im Outliner steht jetzt `MirrorLP.001`.
2. Doppelklick auf den Namen, umbenennen in **`Geometry`**
3. Sidebar-Reiter **`Arma 3`**, Checkbox an, in **LOD Preset** aus der Liste **`Geometry`**
   waehlen
4. Named Properties, ein Eintrag:

   | Name | Value |
   | --- | --- |
   | `autocenter` | `0` |

**Masse:** die ist bei Arma **kein** Named Property, sondern haengt an den Punkten des
Geometry-LODs. Dafuer ist der Kasten **Arma Weight Tools** im Reiter `Arma 3 Tools` da. Fuer
den ersten Test kannst du das ueberspringen - die Waffe funktioniert auch ohne, sie liegt
dann nur etwas albern rum, wenn man sie fallen laesst. Das Inventargewicht kommt sowieso aus
der Config (`mass = 12` in `CfgWeapons.hpp`), nicht aus dem Modell.

**Und jetzt das Duplikat wieder loswerden.** Ein Geometry-LOD muss in Arma konvex und
geschlossen sein, und eine Kopie des Stabs ist beides nicht - duenner Ausleger, Griff,
abstehender Bildschirm. Als Kollisionsform fuer eine hingelegte Waffe reicht ein Quader:

1. Reiter **`Scripting`** → **Text → Open** →
   `Optiwand\tools\blender_setup_all.py` → **Open Text**
2. **`Run Script`**

Das ersetzt das Mesh von `Geometry` durch eine Box um das Modell - 8 Punkte statt 1245. Die
Arma-Einstellungen am Objekt bleiben stehen. Mehrfach ausfuehren schadet nicht.

Du brauchst das Duplikat aus Schritt 1 trotzdem: das Skript ersetzt nur das Mesh, das Objekt
mit seinen LOD-Einstellungen muss vorher existieren.

### 7c: Memory

Hier sitzen die Punkte, an denen Arma sich orientiert.

1. Maus in den Viewport, Menue oben: **Add → Mesh → Plane**
2. **`Tab`** (Edit Mode), **`A`** (alles waehlen), **`M`** → **At Center**

   Aus dem Viereck wird ein einzelner Punkt.
3. **`Tab`** zurueck in den Object Mode, im Outliner in **`Memory`** umbenennen
4. Sidebar-Reiter **`Arma 3`**, Checkbox an, in **LOD Preset** aus der Liste **`Memory`**
   waehlen, Named Property
   `autocenter` = `0`

### Der schnelle Weg: Skript

Punkte von Hand zu setzen ist der fummeligste Teil der ganzen Anleitung. Es geht auch exakt,
und zwar in etwa dreissig Sekunden:

1. Oben in der Reiterleiste (`Layout`, `Modeling`, ... ) auf **`Scripting`**
2. Im Editor in der Mitte oben: **Text → Open**
3. Navigier zu `Optiwand\tools\blender_setup_all.py`, **Open Text**
4. Klick auf **`Run Script`** (das Dreieck oben rechts im Editor)
5. **Window → Toggle System Console** - dort steht der Bericht

Das Skript vermisst dein Modell selbst: es sucht das duennere der beiden Enden, weil da der
Spiegelkopf sitzt, und leitet daraus alle vier Positionen ab. Danach schreibt es sie ins
Objekt `Memory` und legt die fuenf Vertex Groups an. Deine Arma-Toolbox-Einstellungen am
Objekt bleiben unangetastet.

Danach `Layout`-Reiter, `Strg+S`, weiter mit Teil 8.

Der Rest dieses Abschnitts beschreibt denselben Vorgang von Hand - fuer den Fall, dass das
Skript meckert, oder wenn du nachvollziehen willst, was es tut.

### Der Weg von Hand

**Wo ist ueberhaupt ein Punkt?** Es gibt genau **einen**, er ist winzig und steckt mitten im
Modell. Deshalb siehst du im Edit Mode nichts zum Anklicken. Klick auch nicht:

* **`A`** waehlt alles aus - und "alles" ist dieser eine Punkt
* Findest du ihn danach immer noch nicht: **`Numpad .`** (Punkt auf dem Ziffernblock) zoomt
  die Ansicht auf die Auswahl

**Wenn `A` das ganze Modell markiert**, editierst du mehrere Objekte gleichzeitig. Blender
macht das seit 2.8 automatisch: sind in der Object Mode mehrere Objekte ausgewaehlt und du
druckst `Tab`, landen sie alle zusammen im Edit Mode. So:

1. **`Tab`** raus in den Object Mode
2. Im Outliner **einmal normal links auf `Memory`** - ohne `Strg`. Das waehlt Memory aus und
   alles andere ab.
3. Kontrolle: nur `Memory` steht orange, `Camvert` / `Geometry` / `MirrorLP` nicht mehr
4. **`Tab`** rein, **`A`** - jetzt ist es genau ein Punkt

Oben links im Viewport steht immer, welches Objekt aktiv ist. Da muss `Memory | Plane`
stehen.

**Ansicht gerade stellen.** Punkte in der Perspektive zu setzen geht schief, weil du die
Tiefe nicht siehst. Also:

* **`Numpad 3`** - Seitenansicht (der Stab liegt dann laengs vor dir)
* **`Numpad 5`** - schaltet auf orthografisch, ohne Fluchtpunkt

`MirrorLP` siehst du dabei weiter als Umriss, obwohl du im Edit Mode von `Memory` bist. Genau
danach richtest du die Punkte aus.

**Vier Punkte, fuenf Namen.** `usti hlavne` und `zasleh` duerfen sich denselben Punkt teilen -
ein Vertex kann in mehreren Gruppen sein, und Arma stoert das nicht. Zwei Punkte exakt
uebereinander koenntest du sowieso nicht mehr auseinanderklicken.

| Punkt | Wohin | Gruppen |
| --- | --- | --- |
| 1 | aeusserste Spitze des Spiegelkopfs | `usti hlavne` **und** `zasleh` |
| 2 | rund 10 cm dahinter, auf derselben Achse | `konec hlavne` |
| 3 | hinter dem Bildschirm, Richtung Spieler | `eye` |
| 4 | rund 30 cm vor Punkt 3, in dieselbe Richtung wie 2 → 1 zeigt | `aimPoint` |

Die Namen **exakt so** - klein, mit Leerzeichen, ohne Umlaute. Das sind tschechische
Bezeichnungen aus dem Engine-Kern, Arma sucht wortwoertlich danach.

**Erst alle vier Punkte setzen:**

1. Maus im Viewport, **`A`**
2. **`G`**, Maus bewegen, **Linksklick** setzt ab → schieb ihn auf die Spitze des
   Spiegelkopfs. (`G` dann `X`, `Y` oder `Z` bewegt nur entlang einer Achse.)
3. **`Shift+D`**, sofort **`Esc`** → Kopie liegt an derselben Stelle und ist ausgewaehlt
4. **`G`** → an Position 2 schieben, Linksklick
5. Schritt 3 und 4 nochmal fuer Position 3 und 4

Danach hast du vier Punkte im Raum und noch keine Gruppe.

**Dann die Gruppen vergeben:**

1. Im **Properties**-Kasten unten rechts links auf das **gruene Dreieck** (Object Data
   Properties).

   Nicht die rot-weisse Kugel ganz unten - das sind die Materialien. Die hat auch
   `Assign / Select / Deselect`, ist aber die falsche Stelle. Der richtige Kasten heisst
   **Vertex Groups**.
2. **`Alt+A`** (alles abwaehlen), dann **Punkt 1 anklicken**
3. Vertex Groups → **`+`** → Doppelklick auf `Group` → **`usti hlavne`** → `Enter` →
   **Assign**
4. Punkt 1 ist noch ausgewaehlt: nochmal **`+`** → **`zasleh`** → `Enter` → **Assign**
5. `Alt+A`, Punkt 2 anklicken → `+` → `konec hlavne` → **Assign**
6. `Alt+A`, Punkt 3 anklicken → `+` → `eye` → **Assign**
7. `Alt+A`, Punkt 4 anklicken → `+` → `aimPoint` → **Assign**
8. **`Tab`** zurueck in den Object Mode, `Strg+S`

**Kontrolle:** `Tab`, `Alt+A`, dann in der Liste eine Gruppe anklicken und **Select** - es
muss genau ein Punkt aufleuchten, und zwar der richtige. Bei `usti hlavne` und `zasleh`
derselbe.

`usti hlavne` → `konec hlavne` legt fest, wo bei der Waffe vorne ist. Sitzt das verkehrt
herum, haelt dein Charakter den Stab falsch rum. `eye` und `aimPoint` bestimmen die Ansicht
beim Zielen - und Rechtsklick zum Zielen ist bei uns der Ausloeser fuer den ganzen Mod.

Sei da nicht zu pingelig. Nach Augenmass reicht fuer den ersten Durchlauf voellig; wie es
wirklich sitzt, siehst du erst ingame, und dann verschieben wir gezielt nach.

---

## Teil 8: Exportieren

1. Menue ganz oben: **File → Export → Arma 3 P3D (.p3d)**

   Heisst je nach Toolbox-Version leicht anders, ist aber der einzige Arma-Eintrag dort.
2. Als Ziel waehlen:

   ```
   C:\Users\Heda\GitHub Repos\Optiwand\addons\optiwand\model\
   ```
3. Dateiname: **`mirrorgun.p3d`** - genau so, klein
4. Falls es eine Option wie *Selection only* / *Only selected* gibt: **aus**
5. Export klicken

Danach muss in `addons\optiwand\model\` eine Datei `mirrorgun.p3d` liegen.

---

## Teil 9: Texturen umwandeln

Jetzt raus aus Blender.

**Falls Arma 3 Tools noch fehlt:** Steam → Bibliothek → oben den Filter auf **Tools** stellen
→ **Arma 3 Tools** installieren. Gratis.

1. Oeffne den Ordner `Data` auf dem Desktop
2. Markiere die vier PNGs und zieh sie **auf `ImageToPAA.exe`** (im Arma-3-Tools-Ordner).
   Daneben entstehen vier `.paa`-Dateien.
3. Kopier die vier `.paa` nach:

   ```
   Optiwand\addons\optiwand\data\
   ```
4. Kopier auch `mirrorgun.rvmat` dorthin
5. Oeffne `mirrorgun.rvmat` mit einem Texteditor. Darin stehen drei falsche Pfade. Ersetze:

   | vorher | nachher |
   | --- | --- |
   | `\MirrorgunKKC\Data\MirrorgunKKC_nohq.paa` | `\z\opw\addons\optiwand\data\mirrorgun_nohq.paa` |
   | `\MirrorgunKKC\Data\MirrorgunKKC_as.paa` | `\z\opw\addons\optiwand\data\mirrorgun_as.paa` |
   | `\MirrorgunKKC\Data\MirrorgunKKC_smdi.paa` | `\z\opw\addons\optiwand\data\mirrorgun_smdi.paa` |

   Die Zeilen mit `#(argb,8,8,3)color(...)` bleiben, wie sie sind.
6. Leg im selben Ordner eine neue Datei **`screen.rvmat`** an mit genau diesem Inhalt:

   ```cpp
   ambient[] = {0,0,0,1};
   diffuse[] = {0,0,0,1};
   forcedDiffuse[] = {0,0,0,0};
   emmisive[] = {1,1,1,1};
   specular[] = {0,0,0,0};
   specularPower = 1;
   PixelShaderID = "Normal";
   VertexShaderID = "Basic";
   ```

   Das macht den Bildschirm selbstleuchtend, damit Armas Beleuchtung das Kamerabild nicht
   abdunkelt.

Ein Inventarbild fehlt noch. Mach im Ordner `data` einen Unterordner `ui` und leg dort
`gear_optiwand_ca.paa` ab (ein Bild vom Stab, 256x128, ebenfalls durch ImageToPAA). Wenn du
noch keins hast, sag Bescheid - ich rendere dir eins.

---

## Eine Falle, die zwei Anlaeufe gekostet hat

Texturpfade in einer rvmat duerfen beim mainprefix `z` **keinen fuehrenden Backslash** haben.

| Schreibweise | Ergebnis |
| --- | --- |
| `z	mwddons\optiwand\data\mirrorgun_nohq.paa` | laedt |
| `\z	mwddons\optiwand\data\mirrorgun_nohq.paa` | `Cannot load texture` |

Belegt ueber die RPT: die Grundtextur steht in der p3d ohne Backslash und lud sofort, die
drei rvmat-Stages standen mit Backslash da und luden nicht - bei identischem Pfad dahinter.
Bei BI-eigenen Prefixen wie `a3\` ist der fuehrende Backslash egal, beim selbst gemounteten
`z\` nicht.

Das betrifft nur Pfade, die **Arma zur Laufzeit** aufloest. `#include "\z	mw\..."` in den
hpp-Dateien ist etwas anderes - das loest HEMTT beim Bauen auf und muss so bleiben.

---

## Teil 10: Einschalten und testen

`MODEL_READY` in `addons\optiwand\script_component.hpp` ist bereits eingeschaltet, das
Modell liegt in `addons\optiwand\model\mirrorgun.p3d` und der Build laeuft durch.

1. Im Terminal:

   ```
   hemtt launch
   ```
2. Ingame ins Arsenal, Reiter **Handfeuerwaffen**. Dort liegt jetzt zusaetzlich **Optiwand**.

**Die Texturen fehlen noch.** Das Modell zeigt auf `mirrorgun_co.paa`, `_nohq`, `_smdi` und
`_as` - die liegen aber noch als PNG in `art\optiwand\`. Bis die konvertiert sind, ist der
Stab ingame weiss und die RPT meldet vier fehlende Dateien. Funktionieren tut trotzdem alles.

Zum Konvertieren brauchst du **ImageToPAA** aus den Arma 3 Tools (Steam, Bibliothek, Filter
auf *Tools*, kostenlos). HEMTTs `paa convert` kann nur die Gegenrichtung, PAA nach PNG.

Der Rest laeuft von selbst: das Addon traegt die Waffe beim Laden in `opw_mirror_wandClasses`
ein, und ab da behandeln alle Pruefungen im Mod - in der Hand, Zielen, Ausbringen,
Interaktion - sie exakt wie den ESD-Stab.

**Wenn etwas nicht stimmt**, schick mir die RPT. Die liegt unter
`C:\Users\Heda\AppData\Local\Arma 3\` und die neueste ist die mit dem juengsten Datum. Da
steht drin, welche Datei Arma nicht laden konnte.

---

## Der Bildschirm

Das ist hier ein **anderer Fall** als beim Spectrum Device, und deutlich aussichtsreicher.

Beim ESD ist der Bildschirm eine Segmentanzeige aus rund fuenfzig Geometrie-Selektionen, die
BI ueber Munitionszaehler ein- und ausblendet. Da gibt es schlicht keine Flaeche zum
Bespielen.

Dein Modell hat eine **echte Flaeche mit eigenem Material**, und die UVs kontrollierst du.
Damit greift der Standardweg, ueber den auch Fahrzeugbildschirme laufen. In
`addons/optiwand/CfgWeapons.hpp` ist es schon eingetragen:

```cpp
hiddenSelections[] = {"screen"};
hiddenSelectionsTextures[] = {"#(argb,512,512,1)r2t(opw_mirror_rtt,1)"};
```

`opw_mirror_rtt` ist dasselbe Render-Target, in das die Spiegelkamera ohnehin schon rendert.
Sobald der Spiegel ausgebracht ist, liegt das Bild also da.

**Was ich nicht garantieren kann:** ob Arma Render-Targets auf **Waffenmodellen** genauso
behandelt wie auf Fahrzeugen. Fuer Fahrzeuge ist es Alltag, fuer eine in der Hand gehaltene
Waffe habe ich kein Beispiel gefunden, das es nachweislich tut. Das siehst du in der Sekunde,
in der du sie das erste Mal in der Hand haeltst.

Zwei Dinge, die auch bei Erfolg so sind:

* Solange nichts ausgebracht ist, rendert niemand ins Target - der Bildschirm zeigt dann das
  letzte Bild oder Schwarz. Bildschirm aus, passt eigentlich ganz gut.
* Das GUI-Panel bleibt unabhaengig davon. Wenn der Bildschirm funktioniert, schaltest du das
  Panel ueber die CBA-Option *Geraetegehaeuse anzeigen* ab und hast nur noch das Geraet.

Falls es nicht klappt: `hiddenSelections` und `hiddenSelectionsTextures` aus
`CfgWeapons.hpp` rauswerfen. Dann ist es ein zweiter Stab mit eigenem Modell, und das Bild
kommt weiter ueber das Panel.
