# Optiwand

Ein Unter-Tuer-Spiegel fuer Arma 3, angelehnt an den Mirrorgun aus Ready or Not und den
Optiwand aus SWAT 4.

Der Spiegelstab ist eine eigene Waffe im Pistolen-Slot. Nur wenn er **in der Hand** ist,
gibt es unten am Tuerspalt eine ACE-Interaktion, und nur dann greift der Tastendruck.
Nach einer kurzen Progressbar wird der Spiegel durchgeschoben und ein Handmonitor
eingeblendet, den man mit den Pfeiltasten schwenken, neigen, weiter durchschieben,
seitlich verschieben und zoomen kann.

## Voraussetzungen

* CBA_A3
* ACE3
* **Contact Platform** (gratis, liegt bei jeder Arma-3-Installation im Ordner `enoch`) -
  nur wegen des Modells. Die Contact-Expansion selbst wird **nicht** gebraucht.

## Waffe

`opw_MirrorWand` - Pistolen-Slot, im Arsenal also im **Handfeuerwaffen-Reiter**, nicht bei
Primaer- oder Sekundaerwaffen. Im Editor als platzierbares Objekt `OPW_Item_MirrorWand`
unter Ausruestung > Inventargegenstaende.

Aufgebaut wie ACEs Maglite (`ace_flashlights`): eine schlichte `Pistol_Base_F`, die sich nur
das Modell des Spectrum Device ausleiht. Erben von `hgun_esd_01_F` funktioniert nicht - die
Waffe wird vom Geschwister-Subaddon `A3_Weapons_F_Enoch_Pistols_ESD` definiert, dessen
Merge-Reihenfolge sich per `requiredAddons` nicht festnageln laesst, und sie traegt
`DLC = "Enoch"`, worauf das Arsenal filtert. Ein reiner Dateiverweis auf das Modell hat
beide Probleme nicht.

## Schaft

`opw_MirrorWand_Shaft` ("Optiwand Shaft") - sitzt im Muendungsslot und traegt Spiegelkopf und
Kamera. Eigene Klasse mit dem Modell der Contact-Antenne `muzzle_antenna_03_F` (die schlanke
Teleskopstange, nicht die dicke Roehre), damit sie passend heisst und nicht an der DLC-Sperre
haengt. Die Vanilla-Antennen passen bewusst **nicht** mehr.

Arma kann Anbauslots nicht per Config sperren, deshalb setzt `fnc_enforceShaft` den Schaft
ueber das CBA-Loadout-Event einfach wieder auf, sobald er entfernt wird - im Arsenal, im
Inventar und bei Skript-Loadouts gleichermassen. Das laesst sich nicht abschalten - ein Stab ohne Schaft ist nur eine Kiste mit Bildschirm.

Abnehmen zerstoert den Schaft nicht, es legt eine lose Kopie irgendwo ab: in die eigene
Ausruestung, per Rechtsklick auf den Boden, oder in ein offenes Fahrzeug- bzw. Kistenmenue.
Jede davon waere ein Gratis-Schaft, deshalb wird die lose Kopie vorher eingesammelt - eigene
Behaelter direkt, alles im Umkreis von 8 m einen Frame spaeter, weil ein Boden-Holder im
Moment des Events noch nicht existiert. Arma hat keinen Befehl, ein einzelnes Item aus einem
Behaelter zu nehmen, also wird dessen Item-Fracht ohne unseren Schaft neu aufgebaut.

## Bedienung## Bedienung

Drei Wege:

1. **Zielen** - Stab in der Hand, rechte Maustaste. Zeigt der Strahl auf eine Tuer, geht der
   Spiegel in den Tuerspalt. Zeigt er auf nichts, sitzt der Kopf stattdessen am Ende des
   Schafts in die anvisierte Richtung - zum Schauen ueber Mauern und um Ecken. Ein zweiter
   Rechtsklick zieht wieder ein.
2. **Tastendruck** - dasselbe per Taste. **Standardmaessig nicht belegt**, damit nichts
   ueberschrieben wird: CBA Addon-Optionen > Tastenbelegung > Optiwand.
3. **ACE-Interaktion** - Interaktionsmenue oeffnen, Icon unten am Tuerspalt. Immer Tuermodus.

Solange der Monitor offen ist, laeuft ein Dialog. Bewegung, Waffe und Interaktion sind
gesperrt, der Mauszeiger ist ausgeblendet.

Zwei Haende am Geraet: **WASD richtet den Kopf, die Pfeiltasten arbeiten den Schaft.**
Reine Tastensteuerung - die Maus bewegt hier nichts.

| Eingabe | Funktion |
| --- | --- |
| W / S | Kopf neigen |
| A / D | Kopf schwenken |
| Q / E, Numpad + / - | Zoom |
| Pfeil hoch / runter, Bild hoch / runter | Schaft weiter raus / zurueckziehen (nur Tuermodus) |
| Pfeil links / rechts | Kopf seitlich im Tuerspalt verschieben (nur Tuermodus) |
| R | zentrieren |
| N | Restlichtverstaerker der Kamera |
| Rechte Maustaste, Esc, Backspace | schliessen |

Im Freihand-Modus sitzt der Kopf fest am Schaftende - Reichweite und Seitenversatz gibt es
dort nicht, und die Tastenlegende blendet sie entsprechend aus.

Ist kein Platz fuer den Schaft, geht der Bildschirm trotzdem auf und meldet
`E-02 NO CLEARANCE`. Ohne diese Rueckmeldung sieht ein blockierter Versuch aus wie ein
kaputter Mod.

Der Spiegel wird automatisch eingezogen, wenn man sich mehr als 1,5 m von der Tuer
entfernt, die Waffe wechselt, bewusstlos wird oder jemand die Tuer aufmacht.

Das Inventar-Icon in der Ausruestungsansicht fehlt und erzeugt eine RPT-Warnung ueber
`gear_esd_x_ca.paa`. Arma leitet sich fuer den Waffenslot eine zweite, groessere Variante
des `picture` ab, indem es die Nummer am Ende durch `_x` ersetzt. Die gibt es im
Contact-Ordner nicht - BI liefert solche `_x_ca.paa` nur fuer echte Waffen. **ACEs Maglite
hat exakt dieselbe Luecke**, das ist bei Pistolenslot-Werkzeugen der Normalzustand. Weg
bekommt man es nur mit einem eigenen Bildpaar (`irgendwas_ca.paa` plus `irgendwas_x_ca.paa`).

## Einstellungen

CBA Addon-Optionen, Kategorie *Optiwand*: Stab in der Hand erforderlich,
Freihand-Spaehen, Ausbringzeit, maximale Reichweite, **Hoehe des Spiegelkopfs**, Bildgroesse
und Bildposition (neun Ankerpunkte auf einem Raster) und **Geraetegehaeuse anzeigen**.

Bewusst nicht einstellbar, weil sie zum Verhalten des Geraets gehoeren: der Mod ist an, das
Zielen bringt aus, der Schaft ist immer montiert, der Spiegel geht nur an geschlossene
Tueren, der Restlichtverstaerker ist immer verfuegbar, und die Schaftlaenge steht als
`POLE_LENGTH` in `addons/mirror/script_component.hpp`.

Die Hoehe ist der Knopf gegen Clipping: Armas Kollisionsboden (Geometry LOD) und der
sichtbare Boden sind nicht immer dieselbe Flaeche. Wenn das Bild irgendwo durch den Boden
guckt, Wert hochdrehen - das laesst sich live im Spiel machen, ohne Rebuild.

## Eigenes Geraet-Bild einsetzen

Aktuell wird das Gehaeuse aus prozeduralen Farbflaechen gebaut und der Bildschirm mit ACEs
`optic_window_ca.paa` maskiert (runde Ecken plus Vignette). Wer ein richtiges Bild will:

1. Ein `.paa` malen, das das Geraet zeigt, mit **komplett transparentem Bildschirm-Ausschnitt**.
2. In [addons/mirror/script_component.hpp](addons/mirror/script_component.hpp) oben eintragen:
   * `TEXTURE_DEVICE` - Pfad zur Datei
   * `DEVICE_CUT_L/T/R/B` - wo der Ausschnitt im Bild sitzt, als Anteil des Bildes
     (Beispiel: 1024x640 Bild, Ausschnitt Pixel 96..928 quer und 72..520 hoch
     ergibt L 0.094, T 0.113, R 0.906, B 0.813)

Sobald `TEXTURE_DEVICE` gesetzt ist, wird das Bild so skaliert, dass der Ausschnitt genau
auf dem Kamerabild liegt, und das prozedurale Gehaeuse wird ausgeblendet. Statusleiste,
Messwerte und Tastenlegende bleiben und liegen weiterhin oben bzw. unten am Bildschirm.

Ich kann `.paa` nicht selbst erzeugen - HEMTT konvertiert nur PAA nach PNG, und Arma 3
Tools ist hier nicht installiert. Konvertieren geht mit `ImageToPAA.exe` aus Arma 3 Tools
oder mit TexView 2.

## Performance

Drei Per-Frame-Handler, alle drei zugeschaltet statt dauerhaft:

* **Ziel-Beobachter** existiert nur, solange der Stab tatsaechlich in der Hand ist - er wird
  ueber das CBA-Waffenevent an- und abgemeldet, im Ruhezustand kostet er nichts.
* **Interaktions-Scan** laeuft nur bei gedrueckter ACE-Interaktionstaste, alle 0,15 s, und
  auch dann nur, wenn sich die Kamera seit dem letzten Durchlauf bewegt hat. Steht man still
  und schaut dieselbe Tuer an, faellt kein einziger Raycast an.
* **Kamera-Update** laeuft nur bei ausgebrachtem Spiegel, und alles darin ist gestaffelt:
  Bodensuche erst ab 2 cm Bewegung, Kollisions-Sweep nur wenn der Kopf sich wirklich bewegt,
  Tuerpruefung viermal pro Sekunde statt jeden Frame, `setPosASL` und `setVectorDirAndUp` nur
  wenn Position oder Blickrichtung sich geaendert haben, und die Anzeige wird nur neu gebaut,
  wenn sich eine angezeigte Zahl geaendert hat (`parseText` allokiert). Steht der Kopf still,
  sind das eine Handvoll Vergleiche und sonst nichts.

Moduskonstanten (Schwenk- und Neigungsgrenzen) und die lokalisierten Anzeigetexte werden
einmal beim Oeffnen gesetzt, nicht pro Frame neu gebaut.

Es gibt keine Endlosschleifen. Die drei `while`-Schleifen in `fnc_getPanelSpan` zaehlen einen
Offset hoch und sind damit bei 18 bzw. 36 Durchlaeufen zu Ende; das Ergebnis wird pro
Gebaeudetyp gecacht und laeuft nur beim ersten Blick auf eine Tuer dieses Typs. Das Einsammeln
loser Schaefte laeuft ebenfalls ueber eine gezaehlte Schleife, nie ueber eine Bedingung.

## Zweiter Stab mit eigenem Modell

`addons/optiwand/` ist das Geruest fuer eine zweite Waffe auf einem eigenen Modell, mit
Bildschirm direkt am Geraet. Es ist abgeschaltet, bis die Modelldateien da sind, und der
bestehende Stab auf dem Spectrum Device bleibt davon unberuehrt. Anleitung vom .blend bis ingame:
[MODEL-PIPELINE.md](MODEL-PIPELINE.md) klick fuer klick auf Deutsch,
[MODEL-PIPELINE.en.md](MODEL-PIPELINE.en.md) als kompakte Uebersicht auf Englisch.

Registriert sich beim Laden selbst in `opw_mirror_wandClasses`. Ab da behandeln alle
Pruefungen im Mod - in der Hand, Zielen, Ausbringen, Interaktion - beide Waffen gleich,
ohne dass Logik doppelt existiert.

## Gehaeuse oder nur Bild

Die CBA-Option *Geraetegehaeuse anzeigen* schaltet zwischen dem kompletten Handmonitor und
nur dem nackten Kamerabild um. Steuerung und Sperre bleiben in beiden Faellen gleich.

Auf den echten kleinen Bildschirm des Spectrum Device laesst sich das Bild **nicht** legen.
Arma bietet keinen Weg, die Textur einer in der Hand gehaltenen Waffe zu setzen, und im
gesamten Contact-Waffen-PBO steht kein einziges `r2t(` - BI zeichnet den Spektrum-Bildschirm
engine-seitig, da haengt kein anschreibbares Render-Target hinter.

## Inventarbild

Contact liefert kein Bild vom Geraet mit Stab. Arma setzt das Inventar-Icon zur Laufzeit
zusammen: `picture` der Waffe plus `iconPicture` jedes belegten Slots, gezeichnet an dessen
`iconPosition`. Deshalb stimmt das Bild im Inventar, waehrend Arsenal-Liste und Tooltip nur
das rohe `picture` zeigen, also das nackte Geraet.

`art/mirror_wand_ca.png` ist die zusammengesetzte Fassung aus BIs eigenen zwei Bildern,
256x128 wie das Original. Konvertieren und einbauen: siehe `art/README.md`.

## Wie es funktioniert

* **Tuererkennung** (`fnc_findDoor`) - derselbe GEOM-Raycast, den ACE fuer seine eigene
  Tueroeffnen-Interaktion nutzt (`ace_interaction_fnc_getDoor`). Dadurch werden dieselben
  Tueren erkannt, inklusive Glastueren und Tueren aus Terrain-Mods.
* **Fenster** werden bewusst ausgeschlossen. Oeffenbare Fenster haben Animationsquellen wie
  Tueren, der Animationstest allein laesst sie also durch. Deshalb zwei Filter: Selektionen,
  die sich selbst Fenster nennen, fliegen sofort raus, und danach entscheidet die Messung -
  eine Tuer reicht bis zum Boden, ein Fenster sitzt auf einer Bruestung. Alles, dessen
  Unterkante mehr als 45 cm ueber den Fuessen liegt, faellt in den Freihand-Modus.
* **Tuervermessung** (`fnc_getPanelSpan`) - `selectionPosition` liefert bei einer Tuer
  irgendeinen Punkt auf dem Blatt, nicht zuverlaessig dessen Mitte. Deshalb wird die Tuer
  abgetastet: Strahlen werden seitlich und nach unten durch das Blatt geschoben, bis sie es
  nicht mehr treffen. Das ergibt echte Mitte, halbe Breite und Unterkante. Ergebnis wird pro
  Gebaeudetyp im Modellraum gecacht, laeuft also nur einmal je Tuer eines Haustyps.
* **Interaktionspunkt** (`fnc_handleInteractMenuOpened`) - ACE rendert Interaktionen nur auf
  Objekten, also wird ein lokaler `ACE_LogicDummy` in den Tuerspalt gesetzt und die Aktion
  daran gehaengt. Genau das macht ACE selbst fuer die UserActions von Gebaeuden
  (`ace_interact_menu_fnc_userActions_addHouseActions`).
* **Kamerabild** (`fnc_openView`) - die Kamera rendert per `cameraEffect ["INTERNAL", "BACK",
  "opw_mirror_rtt"]` in eine Textur statt auf den Bildschirm, dieselbe Technik wie
  `ace_viewports`. Der Monitor ist ein echter Dialog, der die Steuerung sperrt; der
  Mauszeiger wird ueber eine unsichtbare Kartenflaeche mit ACEs Blank-Cursor abgeschaltet,
  genauso wie es ACEs Progressbar macht.
* **Kollision** (`fnc_update`) - der Spiegelkopf sucht sich jeden Frame den Boden unter sich
  neu (Tuerschwellen liegen fast immer hoeher als der Boden davor) und bewegt sich per
  Sweep-Test von der letzten bekannt freien Position zur gewuenschten. Trifft der Sweep
  Geometrie, stoppt der Kopf davor und Reichweite / Seitenversatz werden auf den tatsaechlich
  erreichten Wert zurueckgerechnet. Der Sweep laeuft bewusst waagerecht, sonst haengt er an
  jeder Tuerschwelle fest.
* **Steuerung** (`fnc_handleKeyDown` / `fnc_update`) - Tasten setzen nur eine Achse, bewegt
  wird im PFH mit Delta-Zeit. Dadurch ist das Schwenken fluessig und nicht an die
  Tastenwiederholrate gekoppelt.

## Bauen und Testen

```bash
hemtt check
```

```bash
hemtt dev
```

```bash
hemtt launch
```

`hemtt dev` baut nach `.hemttout/dev`, `hemtt launch` startet Arma mit diesem Build plus
CBA, ACE3, Zeus Enhanced und Advanced Dev Tools (siehe `.hemtt/project.toml`).
Fuer eine signierte Release-Version: `hemtt release`.

### Profil

`hemtt launch` startet mit dem Profil aus `[hemtt.launch] parameters` in
`.hemtt/project.toml`:

```toml
parameters = [
    '"-name=OFw. Mia Johnson"',
]
```

`-name` will den **Anzeigenamen**, nicht den Ordnernamen. Arma prozentkodiert den Namen
fuer den Ordner, der Startparameter bleibt aber lesbar:
`OFw%2e%20Mia%20Johnson` auf der Platte entspricht `OFw. Mia Johnson` als `-name`.
Ein `-profiles=` braucht es nicht, solange das Profil unter
`Dokumente\Arma 3 - Other Profiles` liegt - da sucht Arma von sich aus.

Pruefen laesst sich das in der Debug-Konsole mit `hint profileName`.

## Noch offen

* `logo.paa` / `logo_small.paa` fehlen noch - sobald sie da sind, die auskommentierten
  Zeilen in `mod.cpp` und den `[files] include` Block in `.hemtt/project.toml` ergaenzen.
* Fenster und Haeuserecken sind noch nicht drin, siehe Notizen im Chat.
