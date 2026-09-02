# Macht Teil 6, 7 und 8 der MODEL-PIPELINE in einem Rutsch und exportiert die p3d.
#
# In Blender: Reiter "Scripting" -> Text -> Open -> diese Datei -> "Run Script".
# Ausgabe: Window -> Toggle System Console.
#
# Voraussetzung ist nur der Stand nach Teil 5:
#   - ein Objekt "MirrorLP" mit angewendeten Transformationen
#   - darin eine Vertex Group "screen" auf den Bildschirmflaechen
#
# Was passiert:
#   0. Arma Toolbox einschalten, falls sie nicht laeuft
#   1. Reste loeschen (Camvert und Co. wuerden als kaputte LODs exportiert)
#   2. Materialnamen saeubern und Materialpfade auf die Mod-Pfade setzen
#   3. Material "mirrorgun_screen" anlegen und den Flaechen der Gruppe "screen" zuweisen
#   4. MirrorLP als Resolution-0-LOD markieren
#   5. Objekt "Geometry" als konvexe Box anlegen, mit Masse
#   6. Objekt "Memory" mit den vier Punkten und fuenf Vertex Groups anlegen
#   7. autocenter = 0 auf allen dreien
#   8. n-gons zerlegen, Blickrichtung pruefen, UVs der Bildschirmflaeche auf 0..1
#   9. Nach addons\optiwand\model\mirrorgun.p3d exportieren
#  10. Die .blend speichern
#
# Mehrfach ausfuehren ist unschaedlich - alles wird jedes Mal neu geschrieben.

import os

import bmesh
import bpy
from math import pi
from mathutils import Matrix, Vector

# Steht oben im Bericht. Wenn da eine aeltere Nummer auftaucht, laeuft eine alte Fassung aus
# Blenders Text-Editor und nicht die Datei von der Platte.
VERSION = 20

SRC = "MirrorLP"
GEO = "Geometry"
MEM = "Memory"
JUNK = ["Camvert", "Screenplane_old", "Screenplane_extra", "Camera", "Light"]

# Die Toolbox dupliziert beim Export alles in eine Collection "tempStuff" und raeumt sie
# hinterher weg. Bricht der Export ab, bleiben die Duplikate liegen.
TEMP_COLL = "tempStuff"

# Der Mod hiess frueher "Tactical Mirror Wand" und der Ordner entsprechend. Statt den
# Pfad fest zu verdrahten wird der erste genommen, den es tatsaechlich gibt - dann ist
# es egal, ob der Ordner schon umbenannt wurde oder nicht.
_CANDIDATES = [
    r"C:\Users\Heda\GitHub Repos\Optiwand",
    r"C:\Users\Heda\GitHub Repos\Tactical-Mirror-Wand",
]
REPO = next((c for c in _CANDIDATES if os.path.isdir(c)), _CANDIDATES[0])
OUT_P3D = os.path.join(REPO, "addons", "optiwand", "model", "mirrorgun.p3d")

DATA = "z\\opw\\addons\\optiwand\\data\\"
TEX_BODY = DATA + "mirrorgun_co.paa"
RVMAT_BODY = DATA + "mirrorgun.rvmat"
RVMAT_SCREEN = DATA + "screen.rvmat"
SCREEN_MAT = "mirrorgun_screen"

# Das "SOF_" in den Originalnamen ist das Kuerzel des Erstellers und bedeutet fuer Arma
# nichts. Blender-Materialnamen landen ohnehin nicht in der p3d - dort zaehlen nur die
# Textur- und rvmat-Pfade -, aber sauber ist sauber.
NAME_PREFIXES = ["SOF_"]
LEGACY_SCREEN_MATS = ["Mirrorgun_Screen", "SOF_Mirrorgun_Screen"]

BAND = 0.02    # Tiefe der abgetasteten Endkappe, Meter
BARREL = 0.10  # usti hlavne -> konec hlavne
AIM = 0.30     # eye -> aimPoint
MASS = 1.5     # kg, Geometry-LOD
# Testrig fuer den Ursprung. Die Drehung ist geklaert (im Spiel gemessen, Variante C), offen
# ist nur noch, wo genau am Griff der Ursprung sitzen muss - dort haengt Arma die Waffe in
# die Hand. Die Hauptwaffe bekommt den berechneten Wert; diese Varianten sind nur da, falls
# er noch danebenliegt. Dann sagt ein Blick, welche stimmt.
#
# Angaben als Verschiebung des MESHES in Blender-Koordinaten. Das Mesh nach unten schieben
# heisst: der Ursprung sitzt weiter oben am Modell.
# Blender nach dem Ausrichten:  -X = Spitze,  +X = Heck,  +Z = oben
#
# Sobald der richtige Wert feststeht: hier auf False und in script_component.hpp das
# #define TESTRIG auskommentieren.
TESTRIG = False
TESTRIG_STEP = 0.030
rig_notes = []

MASS_LAYER = "FHQWeights"   # so heisst der bmesh-Layer, aus dem der Exporter die Masse liest

# LOD-Kennungen der Arma Toolbox. Strings, keine Zahlen - aus der Enum-Liste des Addons.
LOD_CUSTOM = "-1.0"
LOD_GEOMETRY = "1.000e+13"
LOD_MEMORY = "1.000e+15"

log = []


def say(msg):
    log.append(msg)


# ------------------------------------------------------------------ 0 Toolbox anschalten
def enable_toolbox():
    if hasattr(bpy.types.Object, "armaObjProps"):
        return "lief schon"
    names = ["bl_ext.user_default.ArmaToolbox", "ArmaToolbox"]
    try:
        import addon_utils
        for mod in addon_utils.modules():
            if "armatoolbox" in mod.__name__.lower() and mod.__name__ not in names:
                names.append(mod.__name__)
    except Exception:
        pass
    for name in names:
        try:
            bpy.ops.preferences.addon_enable(module=name)
            if hasattr(bpy.types.Object, "armaObjProps"):
                try:
                    bpy.ops.wm.save_userpref()
                except Exception:
                    pass
                return "eingeschaltet: %s" % name
        except Exception:
            continue
    return "FEHLGESCHLAGEN - von Hand unter Edit > Preferences > Add-ons einschalten"


toolbox = enable_toolbox()


def probe(owner, attr):
    grp = getattr(owner, attr, None)
    if grp is None:
        return "%s: fehlt" % attr
    return "%s: da" % attr


def set_lod(obj, lod_id, distance=0.0):
    p = getattr(obj, "armaObjProps", None)
    if p is None:
        return "kein armaObjProps"
    bad = []
    for attr, val in (("isArmaObject", True), ("lod", lod_id), ("lodDistance", distance)):
        try:
            setattr(p, attr, val)
        except Exception as exc:
            bad.append("%s -> %s" % (attr, exc))
    return "; ".join(bad) if bad else "ok"


def set_named(obj, name, value):
    p = getattr(obj, "armaObjProps", None)
    col = getattr(p, "namedProps", None) if p is not None else None
    if col is None:
        return "keine namedProps"
    try:
        for item in col:
            if item.name == name:
                item.value = str(value)
                return "ok"
        item = col.add()
        item.name = name
        item.value = str(value)
        return "ok"
    except Exception as exc:
        return str(exc)


def set_material(mat, texture, rvmat):
    p = getattr(mat, "armaMatProps", None)
    if p is None:
        return "kein armaMatProps"
    bad = []
    for attr, val in (("texType", "Texture"), ("texture", texture), ("rvMat", rvmat)):
        try:
            setattr(p, attr, val)
        except Exception as exc:
            bad.append("%s -> %s" % (attr, exc))
    return "; ".join(bad) if bad else "ok"


# ------------------------------------------------------------------ Start
if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
    bpy.ops.object.mode_set(mode="OBJECT")

src = bpy.data.objects.get(SRC)
if src is None:
    print("!! Kein Objekt namens '%s'. Abbruch." % SRC)
    raise SystemExit
if "screen" not in src.vertex_groups:
    print("!! '%s' hat keine Vertex Group 'screen'. Erst Teil 5 machen. Abbruch." % SRC)
    raise SystemExit

coll = src.users_collection[0] if src.users_collection else bpy.context.scene.collection

# ------------------------------------------------------------------ 1 Aufraeumen
#
# Vorher den Kontext entschaerfen. Blender stuerzt hart ab - ohne Fehlermeldung -, wenn das
# aktive Objekt aus bpy.data verschwindet. Und nach einem abgebrochenen Export ist genau das
# aktiv: eines der Duplikate aus tempStuff. Also erst alles abwaehlen und MirrorLP aktiv
# machen, das ueberlebt garantiert.
try:
    for obj in bpy.context.view_layer.objects:
        obj.select_set(False)
except Exception:
    pass
bpy.context.view_layer.objects.active = src
src.select_set(True)

KEEP = {SRC, GEO, MEM}


def drop(obj, why):
    if obj is None or obj.name in KEEP:
        return
    name = obj.name
    for parent in list(obj.users_collection):
        parent.objects.unlink(obj)
    bpy.data.objects.remove(obj, do_unlink=True)
    say("%s: %s" % (why, name))


for name in JUNK:
    drop(bpy.data.objects.get(name), "geloescht")

# Reste eines abgebrochenen Exports. Nur was in tempStuff haengt - die echten Objekte
# liegen in der normalen Collection und werden davon nicht angefasst.
temp = bpy.data.collections.get(TEMP_COLL)
if temp is not None:
    for obj in list(temp.objects):
        drop(obj, "Export-Rest")
    if not temp.objects:
        bpy.data.collections.remove(temp)
        say("Collection %s entfernt" % TEMP_COLL)

# ------------------------------------------------------------------ 1b N-Gons
# Armas p3d-Format kennt nur Dreiecke und Vierecke. Alles mit fuenf oder mehr Ecken laesst
# den Exporter abbrechen. Wir zerlegen nur die n-gons - Vierecke bleiben Vierecke, das
# spart Polygone und haelt das Drahtgitter lesbar.
def kill_ngons(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    ngons = [f for f in bm.faces if len(f.verts) > 4]
    count = len(ngons)
    if count:
        bmesh.ops.triangulate(bm, faces=ngons)
        bm.to_mesh(obj.data)
        obj.data.update()
    bm.free()
    return count


ngons = kill_ngons(src)
if ngons:
    say("n-gons zerlegt: %d Flaechen in %s" % (ngons, src.name))


# ------------------------------------------------------------------ 1b2 Doppelter Bildschirm
# Das Modell bringt ZWEI Bildschirmflaechen an derselben Stelle mit: eine im Hauptmesh, auf
# die "Camera Ready" gemalt ist, und die separate aus Screenplane_extra, die wir zum
# Render-Target machen. Nachgemessen in der exportierten p3d - beide belegen exakt
# X 0.013..0.075  Y 0.021..0.081  Z 0.049..0.060.
#
# Solange beide da sind, gewinnt die texturierte und auf dem Geraet kann nie ein Kamerabild
# erscheinen. Also fliegt die texturierte raus.
#
# Erkannt wird sie ueber die Punktpositionen, nicht ueber eine Bounding Box: nur Flaechen,
# deren saemtliche Ecken auf einem Zehntelmillimeter genau mit Punkten der Gruppe "screen"
# zusammenfallen. Der Haltearm daneben wird davon nicht getroffen.
def drop_duplicate_screen(obj):
    gi = obj.vertex_groups["screen"].index
    in_group = {v.index for v in obj.data.vertices
                if any(g.group == gi for g in v.groups)}
    if not in_group:
        return 0

    def key(co):
        return (round(co.x, 4), round(co.y, 4), round(co.z, 4))

    screen_pos = {key(obj.data.vertices[i].co) for i in in_group}

    victims = []
    for poly in obj.data.polygons:
        if all(vi in in_group for vi in poly.vertices):
            continue                                    # unsere eigene Flaeche
        if all(key(obj.data.vertices[vi].co) in screen_pos for vi in poly.vertices):
            victims.append(poly.index)

    if not victims:
        return 0

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in victims], context="FACES")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return len(victims)


# Die Bildschirmflaeche wird auf ihre urspruengliche Groesse zurueckgesetzt.
#
# Ein Versuch, sie aufzublasen, um die dunkle Blende drumherum loszuwerden, ging schief: die
# Flaeche stand ueber die Blende hinaus und das Bild sass als kleines Quadrat mitten in einem
# zu grossen Rahmen. Der Rand ist Modellgeometrie und gehoert dort hin - eine Blende um einen
# Monitor ist keine Stoerung.
#
# Absolut statt relativ, und genau deshalb: ein Faktor wuerde sich bei jedem Lauf erneut
# aufmultiplizieren, und ein Faktor von 1.0 wuerde eine bereits verzerrte Datei nicht
# reparieren. Die Zielgroesse stammt aus der Messung an der p3d vor dem Fehlgriff.
SCREEN_SIZE = 0.062     # groesste Kantenlaenge der Bildschirmflaeche, Meter


def restore_screen(obj):
    gi = obj.vertex_groups["screen"].index
    idx = [v.index for v in obj.data.vertices
           if any(g.group == gi for g in v.groups)]
    if len(idx) < 3:
        return None
    verts = obj.data.vertices
    co = [verts[i].co for i in idx]
    span = max(max(c[k] for c in co) - min(c[k] for c in co) for k in range(3))
    if span < 1e-6:
        return None
    factor = SCREEN_SIZE / span
    if abs(factor - 1.0) < 0.005:
        return span
    centre = Vector((0.0, 0.0, 0.0))
    for c in co:
        centre += c
    centre /= len(co)
    for i in idx:
        verts[i].co = centre + (verts[i].co - centre) * factor
    obj.data.update()
    return span


_span = restore_screen(src)
if _span is not None:
    say("Bildschirmflaeche: war %.1f mm, jetzt %.1f mm" % (_span * 1000, SCREEN_SIZE * 1000))

dupes = drop_duplicate_screen(src)
say("doppelte Bildschirmflaechen entfernt: %d" % dupes)


# ------------------------------------------------------------------ 1c Ausrichtung
# Der Exporter schreibt Blender (x, y, z) als Arma (x, z, y) - nachgelesen in MDLExporter.py,
# writeVertices(), und an der fertigen p3d nachgemessen. Blender X bleibt Arma X, Blender Z
# wird Arma Y (oben), Blender Y wird Arma Z (vorne).
#
# Welche Richtung fuer diese Waffe richtig ist, wurde NICHT hergeleitet sondern gemessen:
# das Skript hat sechs gedrehte Varianten exportiert, die im Arsenal nebeneinander standen,
# und im Spiel war Variante C richtig - die Spitze zeigt dort nach Arma -X, also in Blender
# nach -X. Diese Richtung wird hier fest hergestellt.
#
# Hergestellt, nicht gedreht: das Skript misst, wo das duenne Ende gerade liegt, und dreht
# genau so weit, dass es bei -X landet. Damit ist voellig egal, wie oft es laeuft und in
# welchem Zustand die .blend gerade ist.
# Die Spitze gehoert nach Blender -X, also Arma -X.
#
# Das ist zweimal im Spiel bestaetigt worden und einmal von mir wieder verworfen. Meine
# Begruendung damals: die Bildschirmnormale zeigt entlang X, die Zielachse laeuft entlang Z,
# also stehe die Zielachse in der Bildschirmebene statt senkrecht darauf. Die Rechnung stimmt
# - die Schlussfolgerung war trotzdem falsch, denn ungedreht liegt das Geraet sichtbar
# schlechter in der Hand. Wo genau mein Modell der Arma-Achsen nicht passt, weiss ich nicht.
# Die Beobachtung im Spiel schlaegt die Herleitung.
#
# Hergestellt statt gedreht: gemessen wird, wo das duenne Ende liegt, und genau so weit
# gedreht, dass es bei -X landet. Damit ist egal, wie oft das Skript laeuft.
TIP_AXIS = 0      # 0 = X
TIP_SIGN = -1     # negativ

# Wie weit das Mesh damit gegenueber der ungedrehten Lage verdreht ist. Bewusst eine
# Konstante und nicht "was dieser Lauf gedreht hat": beim zweiten Durchlauf steht das Modell
# schon richtig und es wird nichts mehr gedreht, der Versatz gegenueber der ungedrehten Lage
# bleibt aber derselbe. Wird gebraucht, um die Zielachse wieder geradezustellen.
TIP_TURN = 90


def find_tip(obj):
    """(Achse, Vorzeichen) des duennen Endes in der waagerechten Ebene."""
    co = [obj.matrix_world @ v.co for v in obj.data.vertices]
    axis = max(((max(c[i] for c in co) - min(c[i] for c in co), i) for i in (0, 1)))[1]
    vals = [c[axis] for c in co]
    lo = [c for c in co if c[axis] <= min(vals) + BAND]
    hi = [c for c in co if c[axis] >= max(vals) - BAND]
    others = [i for i in (0, 1, 2) if i != axis]

    def thickness(band):
        return sum(max(c[i] for c in band) - min(c[i] for c in band) for i in others)

    return axis, (-1 if thickness(lo) <= thickness(hi) else +1)


# Drehwinkel um die Hochachse, der aus dem Ist- den Sollzustand macht
# Drehung um die Hochachse, die aus dem Ist- den Sollzustand macht (Spitze nach -X)
TURN = {(0, -1): 0, (1, -1): -90, (0, 1): 180, (1, 1): 90}

axis, sign = find_tip(src)
deg = TURN[(axis, sign)]
if deg:
    src.data.transform(Matrix.Rotation(deg * pi / 180.0, 4, "Z"))
    src.data.update()
    say("um %+d Grad gedreht, damit die Spitze nach -X zeigt" % deg)
    axis, sign = find_tip(src)
turn_note = "Spitze bei %s%s" % ("+" if sign > 0 else "-", "XY"[axis])

# ------------------------------------------------------------------ 1d Ursprung
# Arma haengt die Waffe am Modellursprung in die Hand. Liegt der woanders als am Griff,
# steht das Geraet neben der Faust statt darin.
#
# Der Griff wird gemessen statt geraten: die untersten drei Zentimeter des Modells sind
# genau der hintere Pistolengriff - nachgeprueft an der p3d, das ergibt eine saubere
# 20-Punkte-Wolke, waehrend eine hoehere Schwelle auch den vorderen Haltegriff einsammelt.
# Der Ursprung kommt auf dessen Mitte, ein Stueck oberhalb des unteren Endes, also dahin
# wo der Handballen sitzt.
GRIP_BAND = 0.03    # wie tief von unten abgetastet wird
GRIP_UP = 0.045     # wie weit ueber dem unteren Griffende der Ursprung sitzt


def grip_origin(obj):
    co = [obj.matrix_world @ v.co for v in obj.data.vertices]
    zmin = min(c.z for c in co)
    grip = [c for c in co if c.z <= zmin + GRIP_BAND]
    if len(grip) < 4:
        return None, "zu wenige Punkte, Ursprung unveraendert"
    return (Vector((sum(c.x for c in grip) / len(grip),
                    sum(c.y for c in grip) / len(grip),
                    zmin + GRIP_UP)),
            "%d Punkte" % len(grip))


# Im Spiel getestet: von den sechs Ursprungsvarianten lag "alter Ursprung" am naechsten,
# also der Punkt, den der Ersteller selbst gesetzt hat. Die berechnete Griffmitte lag daneben
# - Armas Hand sitzt offenbar hoeher am Gehaeuse als in der Mitte des Griffs.
#
# Zurueckholen laesst sich der alte Ursprung nicht mehr direkt: Version 9 hat das Mesh schon
# einmal verschoben und die .blend ueberschrieben, die urspruengliche Lage steht nirgends
# mehr. Sie wird deshalb ueber den Griff rekonstruiert - der ist unabhaengig von jeder
# Verschiebung immer dieselbe Stelle am Modell.
#
# Der Abstand unten stammt aus der Messung am unverschobenen Modell: dort lag die Griffmitte
# in Blender bei (+0.0337, 0.0000, -0.0871) und der Ursprung bei (0, 0, 0).
#
# Dadurch ist das Ganze auch wiederholbar: einmal hergestellt, aendert der naechste Lauf
# nichts mehr, weil Griffmitte + Abstand dann schon bei Null liegt.
# Der Ersteller-Ursprung liegt auf der Rohrachse. Arma haengt die Waffe dort in die Hand,
# also sitzt die Faust mitten auf dem Rohr statt am Griff darunter.
#
# Gemessen am Vergleichsbild mit der MP-443 Grach, beide im selben Arsenal-Griff:
#   Grach     19.8 cm lang, spannt 360 px  ->  1 cm ~ 18 px
#             Faustmitte liegt 50 px unter der Laufachse  ->  rund 2.8 cm
#   Optiwand  40.7 cm lang, spannt 840 px  ->  1 cm ~ 20.6 px
#             Faustmitte liegt auf der Rohrachse
#
# Also muss die Waffe rund 3 cm nach oben. Waagerecht bleibt sie, wo der Ersteller sie
# gesetzt hat: Version 9 hatte sie zusaetzlich 3.4 cm zur Spitze hin geschoben, und genau
# das zieht den Griff aus der Hand - deshalb war der unveraenderte Ursprung damals besser.
#
# Der Griff dient nur als Bezugspunkt, damit das Ganze wiederholbar bleibt: er ist unabhaengig
# von jeder frueheren Verschiebung immer dieselbe Stelle am Modell.
# Gemessen am unverschobenen Modell im gedrehten Zustand: die Griffmitte lag dort bei
# Blender (+0.0337, 0.0000, -0.0871), der Ersteller-Ursprung bei (0, 0, 0). Der Griff dient
# nur als Bezugspunkt, damit das Ganze wiederholbar bleibt - er ist unabhaengig von jeder
# frueheren Verschiebung immer dieselbe Stelle am Modell.
ORIGIN_FROM_GRIP = Vector((-0.0337, 0.0, 0.0871))

LIFT = 0.0

# Versatz gegenueber dem Ersteller-Ursprung, im gedrehten Zustand.
#
# Blender in dieser Lage:  -X = Spitze,  +X = Heck,  -Y = zum Spieler,  +Z = oben
#
#   Y -0.03   die 3 cm, die Variante F schon mitbrachte und die im Spiel fast passten
#   X +0.03   der Versatz nach hinten, der noch gefehlt hat - die Richtung, die sich beim
#             Testen als "nach hinten" gezeigt hat, weil X hier die Laengsachse ist
NUDGE = Vector((0.030, -0.030, 0.0))

grip, grip_note = grip_origin(src)
if grip is None:
    origin_note = grip_note
else:
    target = grip + ORIGIN_FROM_GRIP - Vector((0.0, 0.0, LIFT)) - NUDGE
    if target.length > 1e-5:
        src.data.transform(Matrix.Translation(-target))
        src.data.update()
        origin_note = "um (%+.3f %+.3f %+.3f) verschoben" % (
            -target.x, -target.y, -target.z)
    else:
        origin_note = "sitzt schon richtig"

# ------------------------------------------------------------------ 2+3 Materialien
# Erst aufraeumen: Ersteller-Kuerzel raus, alles klein. Nur die Materialien dieses Objekts -
# Blender-eigene Voreinstellungen wie "Dots Stroke" gehen uns nichts an.
for mat in list(src.data.materials):
    if mat is None:
        continue
    clean = mat.name
    for prefix in NAME_PREFIXES:
        if clean.startswith(prefix):
            clean = clean[len(prefix):]
    clean = clean.lower()
    if clean != mat.name:
        say("umbenannt: %s -> %s" % (mat.name, clean))
        mat.name = clean

mats = []
for mat in src.data.materials:
    if mat is None or mat.name == SCREEN_MAT:
        continue
    mats.append((mat.name, set_material(mat, TEX_BODY, RVMAT_BODY)))

screen_mat = None
for legacy in [SCREEN_MAT] + [n.lower() for n in LEGACY_SCREEN_MATS]:
    screen_mat = bpy.data.materials.get(legacy)
    if screen_mat is not None:
        screen_mat.name = SCREEN_MAT
        break
if screen_mat is None:
    screen_mat = bpy.data.materials.new(SCREEN_MAT)
if screen_mat.name not in [m.name for m in src.data.materials if m]:
    src.data.materials.append(screen_mat)
screen_idx = list(src.data.materials).index(screen_mat)
mats.append((SCREEN_MAT, set_material(screen_mat, "", RVMAT_SCREEN)))

# Bildschirmflaechen: alle Polygone, deren Punkte komplett in der Gruppe "screen" liegen
gi = src.vertex_groups["screen"].index
in_group = set()
for vert in src.data.vertices:
    for g in vert.groups:
        if g.group == gi:
            in_group.add(vert.index)
            break

hits = 0
for poly in src.data.polygons:
    if all(vi in in_group for vi in poly.vertices):
        poly.material_index = screen_idx
        hits += 1

# Reste frueherer Durchlaeufe wegraeumen, aber nur unsere eigenen und nur die, die
# tatsaechlich niemand mehr benutzt.
for mat in list(bpy.data.materials):
    if mat.users == 0 and mat.name.lower().startswith("mirrorgun"):
        say("verworfen (unbenutzt): %s" % mat.name)
        bpy.data.materials.remove(mat)

# ------------------------------------------------------------------ 8 UV der Bildschirmflaeche
# Das Render-Target hat immer das Seitenverhaeltnis des Spielerbildschirms - Arma bietet
# keinen Weg, das pro Kamera zu setzen. Die Bildschirmflaeche am Modell ist dagegen fast
# quadratisch. Wuerde man das ganze Bild darauf legen, waere es waagerecht zusammengedrueckt:
# Leute sehen schmal und lang aus.
#
# Also bekommt die Flaeche nicht das ganze Bild, sondern den mittleren Ausschnitt im richtigen
# Verhaeltnis. Seitlich fehlt dadurch etwas - das ist der Preis dafuer, dass die Proportionen
# stimmen, und auf einem handtellergrossen Monitor der bessere Tausch. Der externe Monitor im
# GUI zeigt weiterhin das volle Bild, der ist ja auch im richtigen Format.
#
# SCREEN_ASPECT ist das Format, fuer das gerechnet wird. 16:9 deckt praktisch alle Monitore
# ab; bei 21:9 waere seitlich etwas mehr abgeschnitten, verzerrt ist es trotzdem nicht.
SCREEN_ASPECT = 16.0 / 9.0

uv_note = "keine UV-Map"
uvl = src.data.uv_layers.active
if uvl is not None:
    loops = []
    for poly in src.data.polygons:
        if poly.material_index == screen_idx:
            loops.extend(poly.loop_indices)

    if not loops:
        uv_note = "keine Flaechen mit Screen-Material"
    else:
        # Wie breit die Flaeche im Verhaeltnis zu ihrer Hoehe wirklich ist
        gi_s = src.vertex_groups["screen"].index
        sco = [v.co for v in src.data.vertices
               if any(g.group == gi_s for g in v.groups)]
        dims = sorted((max(c[k] for c in sco) - min(c[k] for c in sco)) for k in range(3))
        face_aspect = dims[2] / dims[1] if dims[1] > 1e-6 else 1.0

        # Waagerechte Ausdehnung im UV-Raum, damit nichts gequetscht wird
        u_span = min(1.0, face_aspect / SCREEN_ASPECT)
        u0, u1 = 0.5 - u_span / 2.0, 0.5 + u_span / 2.0

        for li in loops:
            uv = uvl.data[li].uv
            uv[0] = u0
            uv[1] = 0.0

        # Die vier Ecken einzeln setzen, damit das Rechteck auch wirklich eines wird
        corners = {}
        for poly in src.data.polygons:
            if poly.material_index != screen_idx:
                continue
            for vi, li in zip(poly.vertices, poly.loop_indices):
                corners.setdefault(vi, []).append(li)

        pos = {vi: src.data.vertices[vi].co for vi in corners}
        # Senkrecht auf dem Bildschirm ist die Welt-Hochachse, also Blender Z - nicht
        # einfach "die laengere Kante". Bei einer nahezu quadratischen Flaeche entscheiden
        # sonst Zehntelmillimeter darueber, ob das Bild um 90 Grad gedreht ankommt.
        a_lo = 2                                     # Z, das ist oben
        a_hi = 0 if (max(p[0] for p in pos.values()) - min(p[0] for p in pos.values())) >                     (max(p[1] for p in pos.values()) - min(p[1] for p in pos.values())) else 1
        rng = {}
        for k in (a_lo, a_hi):
            vals = [p[k] for p in pos.values()]
            rng[k] = (min(vals), max(vals) - min(vals) or 1.0)

        for vi, lis in corners.items():
            fx = (pos[vi][a_hi] - rng[a_hi][0]) / rng[a_hi][1]
            fy = (pos[vi][a_lo] - rng[a_lo][0]) / rng[a_lo][1]
            for li in lis:
                uvl.data[li].uv[0] = u0 + fx * (u1 - u0)
                uvl.data[li].uv[1] = fy

        uv_note = ("Flaeche %.2f:1, Bildformat %.2f:1  ->  U %.3f..%.3f, V 0..1"
                   % (face_aspect, SCREEN_ASPECT, u0, u1))

# ------------------------------------------------------------------ 4 MirrorLP als LOD
lod_src = set_lod(src, LOD_CUSTOM, 0.0)
np_src = set_named(src, "autocenter", 0)

# ------------------------------------------------------------------ Modell vermessen
mw = src.matrix_world
co = [mw @ v.co for v in src.data.vertices]
lo3 = [min(c[i] for c in co) for i in range(3)]
hi3 = [max(c[i] for c in co) for i in range(3)]


def ensure(name):
    obj = bpy.data.objects.get(name)
    if obj is None:
        obj = bpy.data.objects.new(name, bpy.data.meshes.new(name))
        coll.objects.link(obj)
        say("angelegt: %s" % name)
    elif obj.name not in coll.objects:
        coll.objects.link(obj)
    return obj


# ------------------------------------------------------------------ 5 Geometry
geo = ensure(GEO)
inv = geo.matrix_world.inverted()
bm = bmesh.new()
corners = []
for ix in (0, 1):
    for iy in (0, 1):
        for iz in (0, 1):
            corners.append(bm.verts.new(inv @ Vector((
                (hi3 if ix else lo3)[0],
                (hi3 if iy else lo3)[1],
                (hi3 if iz else lo3)[2]))))
bm.verts.ensure_lookup_table()
for a, b, c, d in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1),
                   (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
    bm.faces.new((corners[a], corners[b], corners[c], corners[d]))
bm.normal_update()
bm.to_mesh(geo.data)
bm.free()
geo.data.update()
for g in list(geo.vertex_groups):
    geo.vertex_groups.remove(g)
lod_geo = set_lod(geo, LOD_GEOMETRY, 0.0)
np_geo = set_named(geo, "autocenter", 0)

# Masse. Der Exporter liest sie NICHT aus armaObjProps.mass, sondern aus einem
# bmesh-Float-Layer namens "FHQWeights", den sonst die Arma Weight Tools anlegen. Nur mass
# zu setzen laesst ihn mit KeyError abbrechen - es braucht beides.
mass_note = "nicht gesetzt"
try:
    bm = bmesh.new()
    bm.from_mesh(geo.data)
    if MASS_LAYER in bm.verts.layers.float.keys():
        layer = bm.verts.layers.float[MASS_LAYER]
    else:
        layer = bm.verts.layers.float.new(MASS_LAYER)
    share = MASS / max(1, len(bm.verts))
    for vert in bm.verts:
        vert[layer] = share
    bm.to_mesh(geo.data)
    bm.free()
    geo.data.update()
    geo.armaObjProps.mass = MASS
    mass_note = "%s kg auf %d Punkte verteilt" % (MASS, len(geo.data.vertices))
except Exception as exc:
    # Lieber ohne Masse exportieren als gar nicht. Das Inventargewicht kommt sowieso aus
    # CfgWeapons, die Modellmasse zaehlt nur fuer die Physik der hingelegten Waffe.
    try:
        geo.armaObjProps.mass = 0.0
    except Exception:
        pass
    mass_note = "abgeschaltet, sonst bricht der Export ab (%s)" % exc

# ------------------------------------------------------------------ 6 Memory
# Die fuenf Memory-Punkte werden gesetzt, nicht aus der Geometrie abgeleitet.
#
# Warum: der Mod liest keinen einzigen davon aus - nachgeprueft, es gibt kein
# selectionPosition auf die Waffe. Sie dienen ausschliesslich Arma selbst, und dort zaehlt
# praktisch nur eins: beim Zielen setzt die Engine die Kamera auf "eye" und blickt Richtung
# "aimPoint". Zeigt diese Achse nicht in Blickrichtung des Spielers, kippt die Ansicht weg.
#
# Genau das ist vorher passiert. Das Mesh muss um 90 Grad gedreht sein, damit der Stab
# richtig in der Hand liegt - dieselbe Drehung auf mitberechnete Punkte angewandt legte die
# Zielachse quer. Ein zweiter Fehler kam dazu: die Vermessung tastete noch die Blender-Y-
# Achse ab, obwohl die Laengsachse nach der Drehung X ist. Dabei kamen Punkte heraus, die an
# keiner Stelle des Modells lagen.
#
# Beides faellt weg, wenn die Punkte fest auf der +Z-Achse durch den Ursprung liegen. Bei
# einer Waffe, die schiesst, waere das Pfusch - dann gehoert die Muendung dorthin wo sie
# aussieht. Dieses Geraet hat weder Geschoss noch Muendungsfeuer.
# Beim Zielen setzt Arma die Kamera auf "eye" und blickt Richtung "aimPoint". Bei einer
# Waffe legt man diese Achse auf die Visierlinie. Dieses Geraet hat keine Visierung - was der
# Spieler beim Zielen sehen will, ist der Bildschirm.
#
# Also wird die Achse durch die Bildschirmmitte gelegt, mit "eye" dahinter und "aimPoint"
# davor. Aimen heisst damit woertlich: den Monitor vors Auge holen.
#
# usti hlavne und konec hlavne liegen auf derselben Achse. Bei einer schiessenden Waffe waere
# das falsch - die Muendung gehoert dorthin, wo sie aussieht. Dieses Geraet hat weder Geschoss
# noch Muendungsfeuer, und der Mod liest keinen der Punkte aus (nachgeprueft: kein einziges
# selectionPosition auf die Waffe).
# Wie nah der Bildschirm beim Zielen ans Auge kommt. Das ist die Stellschraube dafuer, wie
# gross der kleine Monitor am Geraet im Zielen wirkt - nicht die Modellgroesse.
#
# Vorgeschichte: 0.12 war zu nah, der Monitor stand vor der Nase und passte nicht ins Bild.
# 0.32 war die Entfernung, in der man ein Handgeraet haelt - gut lesbar, aber klein. 0.20
# liegt dazwischen und holt ihn spuerbar naeher, ohne dass er ueber den Rand laeuft.
#
# Kleiner heisst naeher und damit groesser. Unter etwa 0.15 wird es wieder eng.
EYE_BACK = 0.20     # wie weit "eye" hinter der Bildschirmmitte sitzt
AIM_FWD = 0.25      # wie weit "aimPoint" davor
MUZZLE_FWD = 0.10   # Abstand konec hlavne -> usti hlavne

gi_screen = src.vertex_groups["screen"].index
screen_co = [src.matrix_world @ v.co for v in src.data.vertices
             if any(g.group == gi_screen for g in v.groups)]
if screen_co:
    centre = Vector((sum(c.x for c in screen_co) / len(screen_co),
                     sum(c.y for c in screen_co) / len(screen_co),
                     sum(c.z for c in screen_co) / len(screen_co)))
    sight_note = "Bildschirmmitte (%+.3f %+.3f %+.3f)" % (centre.x, centre.y, centre.z)
else:
    centre = Vector((0.0, 0.0, 0.0))
    sight_note = "keine Bildschirmpunkte, Achse durch den Ursprung"

# Die Zielachse muss SENKRECHT auf dem Bildschirm stehen. Das ist der Punkt, den Version 13
# richtig hatte - dort war das Mesh ungedreht, die Bildschirmnormale zeigte nach hinten zum
# Spieler, und die Achse entlang Blender +Y traf sie im rechten Winkel. Das Zielen war gut.
#
# Version 15 hat daraus die falsche Lehre gezogen und die Bildschirmmitte zurueckgerechnet,
# statt die Achsrichtung mitzudrehen. Ergebnis: die Achse lag bei Arma X +0.044, der
# Bildschirm bei -0.0845 - 12.8 cm auseinander und auf entgegengesetzten Seiten.
#
# Richtig ist: die Mitte bleibt, wo der Bildschirm wirklich ist, und die Richtung wird
# mitgedreht. Dann steht die Achse wieder senkrecht auf der Flaeche, genau wie in Version 13,
# und das Mesh bleibt unberuehrt.
FORWARD = Matrix.Rotation(TIP_TURN * pi / 180.0, 4, "Z") @ Vector((0.0, 1.0, 0.0))
sight_note += ", Achsrichtung (%+.2f %+.2f %+.2f)" % (FORWARD.x, FORWARD.y, FORWARD.z)


def on_axis(fwd):
    return centre + FORWARD * fwd


eye = on_axis(-EYE_BACK)
konec = on_axis(-EYE_BACK + 0.05)
tip = on_axis(-EYE_BACK + 0.05 + MUZZLE_FWD)
aim = on_axis(AIM_FWD)
points = [tip, konec, eye, aim]

mem = ensure(MEM)
inv = mem.matrix_world.inverted()
bm = bmesh.new()
for p in points:
    bm.verts.new(inv @ p)
bm.to_mesh(mem.data)
bm.free()
mem.data.update()
for g in list(mem.vertex_groups):
    mem.vertex_groups.remove(g)

# usti hlavne und zasleh teilen sich Punkt 0 - ein Vertex darf in mehreren Gruppen sein.
ASSIGN = [("usti hlavne", 0), ("zasleh", 0), ("konec hlavne", 1), ("eye", 2), ("aimPoint", 3)]
for name, idx in ASSIGN:
    mem.vertex_groups.new(name=name).add([idx], 1.0, "REPLACE")
lod_mem = set_lod(mem, LOD_MEMORY, 1.0)
np_mem = set_named(mem, "autocenter", 0)

# ------------------------------------------------------------------ 9 Export
#
# Vorher speichern. Der Exporter dupliziert Objekte, wendet Modifier an und joint herum -
# wenn er dabei stirbt, soll wenigstens die ganze Vorarbeit auf der Platte liegen.
presave = "nicht gespeichert (Datei hat keinen Pfad)"
if bpy.data.filepath:
    bpy.ops.wm.save_mainfile()
    presave = "gespeichert"

export_note = "uebersprungen"
export_op = "-"
if not hasattr(bpy.types.Object, "armaObjProps"):
    export_note = "Toolbox laeuft nicht, kein Export moeglich"
else:
    for obj in bpy.context.view_layer.objects:
        obj.select_set(False)
    for obj in (src, geo, mem):
        obj.select_set(True)
    bpy.context.view_layer.objects.active = src

    found = []
    for modname in dir(bpy.ops):
        try:
            mod = getattr(bpy.ops, modname)
        except Exception:
            continue
        for opname in dir(mod):
            low = (modname + "." + opname).lower()
            if "p3d" in low or "mlod" in low:
                found.append((modname, opname))

    export_op = str(["%s.%s" % f for f in found]) or "nichts gefunden"
    picked = None
    for modname, opname in found:
        if "export" in (modname + opname).lower() and "batch" not in opname.lower():
            picked = (modname, opname)
            break
    if picked is None and found:
        picked = found[0]

    if picked is None:
        export_note = "kein p3d-Export-Operator gefunden"
    else:
        os.makedirs(os.path.dirname(OUT_P3D), exist_ok=True)
        op = getattr(getattr(bpy.ops, picked[0]), picked[1])
        try:
            keys = sorted(op.get_rna_type().properties.keys())
        except Exception:
            keys = []
        export_op = "%s.%s  args=%s" % (picked[0], picked[1],
                                        [k for k in keys if k != "rna_type"])
        # mergeSameLOD aus: wir haben genau ein Objekt pro LOD, da gibt es nichts zu
        # verschmelzen. Mit an versucht der Exporter MirrorLP mit Geometry zusammenzulegen
        # und meldet "No mesh data to join".
        extra = {}
        if "mergeSameLOD" in keys:
            extra["mergeSameLOD"] = False

        def export_to(path):
            os.makedirs(os.path.dirname(path), exist_ok=True)
            try:
                op(filepath=path, **extra)
            except Exception as exc:
                return "FEHLER: %s" % exc
            if not os.path.exists(path):
                return "Operator lief, aber die Datei fehlt"
            return "ok, %d KB" % (os.path.getsize(path) // 1024)

        export_note = export_to(OUT_P3D)

        # ---------------------------------------------------------- Testrig
        # Zweimal habe ich die richtige Ausrichtung geraten und zweimal danebengelegen.
        # Also wird sie jetzt gemessen: jede plausible Drehung wird als eigene p3d
        # exportiert, im Arsenal stehen sie als "Optiwand TEST A".."F" nebeneinander, und ein
        # einziger Blick sagt, welche stimmt. Danach TESTRIG hier und in CfgWeapons ausbauen.
        #
        # Blender -> Arma:  X bleibt X (rechts), Blender Z wird Arma Y (oben),
        #                   Blender Y wird Arma Z (vorne).
        # "Gier" dreht also um Blender Z, "Rolle" um Blender Y (die Laengsachse).
        if TESTRIG:
            d = TESTRIG_STEP
            # Beschriftet danach, wohin sich die WAFFE relativ zur Hand bewegt - das ist die
            # Sicht, die beim Hinschauen zaehlt. Blender nach dem Ausrichten:
            #   -X = Spitze,  +X = Heck,  +Z = oben,  +Y = vom Spieler weg
            def move(x=0.0, y=0.0, z=0.0):
                return Matrix.Translation(Vector((x, y, z)))

            variants = [
                ("a", "wie berechnet",       move()),
                ("b", "3 cm weiter hinten",  move(x=+d)),
                ("c", "6 cm weiter hinten",  move(x=+2*d)),
                ("d", "3 cm nach vorne",     move(x=-d)),
                ("e", "3 cm zum Spieler",    move(y=-d)),
                ("f", "3 cm vom Spieler weg", move(y=+d)),
            ]
            for letter, label, mat in variants:
                path = os.path.join(os.path.dirname(OUT_P3D), "test_%s.p3d" % letter)
                moved = mat != Matrix.Identity(4)
                if moved:
                    for obj in (src, geo, mem):
                        obj.data.transform(mat)
                        obj.data.update()
                rig_notes.append("  TEST %s  %-24s %s"
                                 % (letter.upper(), label, export_to(path)))
                if moved:
                    inv = mat.inverted()
                    for obj in (src, geo, mem):
                        obj.data.transform(inv)
                        obj.data.update()

# ------------------------------------------------------------------ Bericht
line = "=" * 70
print("")
print(line)
print("SKRIPT-VERSION   %d" % VERSION)
print("TOOLBOX          %s" % toolbox)
print("  %s / %s" % (probe(src, "armaObjProps"),
                     probe(src.data.materials[0], "armaMatProps") if src.data.materials else "-"))
print("")
if log:
    print("AUFRAEUMEN / ANLEGEN")
    for entry in log:
        print("  " + entry)
    print("")
print("MATERIALIEN")
for name, status in mats:
    print("  %-22s %s" % (name, status))
print("  Screen-Material auf %d von %d Polygonen" % (hits, len(src.data.polygons)))
print("  Screen-UV: %s" % uv_note)
print("")
print("MODELL")
print("  Ausrichtung: %s  (im Spiel gemessen: Spitze nach -X)" % turn_note)
print("  Ursprung:    %s" % origin_note)
print("  Zielachse:   %s" % sight_note)
print("  %d Punkte" % len(co))
print("  Ausdehnung  X %+.3f..%+.3f   Y %+.3f..%+.3f   Z %+.3f..%+.3f"
      % (lo3[0], hi3[0], lo3[1], hi3[1], lo3[2], hi3[2]))
print("")
print("MEMORY-PUNKTE (global)")
for name, idx in ASSIGN:
    p = points[idx]
    print("  %-14s X %8.4f   Y %8.4f   Z %8.4f" % (name, p.x, p.y, p.z))
print("")
print("LOD-EINSTELLUNGEN")
for obj, lod_res, np_res in ((src, lod_src, np_src), (geo, lod_geo, np_geo), (mem, lod_mem, np_mem)):
    p = getattr(obj, "armaObjProps", None)
    print("  %-10s lod=%-12s dist=%-6s arma=%-6s | %s | autocenter %s"
          % (obj.name, getattr(p, "lod", "?"), getattr(p, "lodDistance", "?"),
             getattr(p, "isArmaObject", "?"), lod_res, np_res))
print("  Geometry-Masse: %s" % mass_note)
print("")
print("EXPORT")
print("  Sicherung vorher: %s" % presave)
print("  Operator: %s" % export_op)
print("  Ziel:     %s" % OUT_P3D)
print("  Ergebnis: %s" % export_note)
if rig_notes:
    print("")
    print("TESTRIG")
    for entry in rig_notes:
        print(entry)
print(line)

if bpy.data.filepath:
    bpy.ops.wm.save_mainfile()
    print("Gespeichert: %s" % bpy.data.filepath)
else:
    print("NICHT gespeichert - die Datei hat noch keinen Pfad. Einmal Strg+S von Hand.")
print(line)
