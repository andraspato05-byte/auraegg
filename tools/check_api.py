"""Cross-checks Roblox API usage in the Luau sources against the official API dump.

    python3 tools/check_api.py [src_dir]

Checks every Instance.new class, GetService name, IsA/FindFirst*OfClass class,
Enum item, and (for variables whose class is known) every property, method and
event name, including writes to read-only or deprecated members.
The API dump is downloaded once into .cache/API-Dump.json.
Exit code 1 if a problem is found.
"""
import json
import pathlib
import re
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
CACHE = ROOT / ".cache" / "API-Dump.json"
DUMP_URL = "https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json"

if not CACHE.exists():
    CACHE.parent.mkdir(exist_ok=True)
    print("downloading Roblox API dump...")
    urllib.request.urlretrieve(DUMP_URL, CACHE)

dump = json.load(open(CACHE))
src = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "src"

classes = {c["Name"]: c for c in dump["Classes"]}
enums = {e["Name"]: {i["Name"] for i in e["Items"]} for e in dump["Enums"]}


def members(cls):
    out = {}
    while cls:
        c = classes[cls]
        for m in c["Members"]:
            out.setdefault(m["Name"], (m, cls))
        sup = c.get("Superclass")
        cls = sup if sup and sup in classes else None
    return out


# Variable names whose class is known from how they are used throughout the code.
MANUAL = {
    "Players": "Players", "mogButton": "TextButton", "sizeLabel": "TextLabel", "mogRemote": "RemoteEvent", "body": "BasePart", "rim": "Part", "upgradeTerminal": "Part", "eventTitle": "TextLabel", "eventTimer": "TextLabel", "shopItems": "ScrollingFrame", "headerTemplate": "TextLabel", "itemTemplate": "Frame", "eventBanner": "Frame", "stormTestButton": "TextButton", "cashPanel": "Frame", "hud": "ScreenGui", "speedLabel": "TextLabel", "startEventRemote": "RemoteEvent", "MarketplaceService": "MarketplaceService", "purchaseStore": "GlobalDataStore", "buy": "TextButton", "shopButton": "TextButton", "closeButton": "TextButton", "shopPanel": "Frame", "shopList": "ScrollingFrame", "shopScale": "UIScale", "row": "Frame", "header": "TextLabel", "nameLabel": "TextLabel", "descLabel": "TextLabel", "shopTitle": "TextLabel", "camera": "Camera", "ReplicatedStorage": "ReplicatedStorage", "PhysicsService": "PhysicsService",
    "RunService": "RunService", "TweenService": "TweenService", "CollectionService": "CollectionService",
    "StarterPack": "StarterPack", "Lighting": "Lighting", "DataStoreService": "DataStoreService",
    "workspace": "Workspace", "game": "DataModel", "store": "GlobalDataStore",
    "player": "Player", "thief": "Player", "victim": "Player", "attacker": "Player", "other": "Player",
    "owner": "Player", "character": "Model", "humanoid": "Humanoid", "root": "BasePart",
    "otherRoot": "BasePart", "handle": "Part", "model": "Model", "core": "Part", "barrier": "Part",
    "pedestal": "Part", "machine": "Part", "titleAnchor": "Part", "signAnchor": "Part",
    "label": "TextLabel", "cashLabel": "TextLabel", "incomeLabel": "TextLabel", "carryBanner": "TextLabel",
    "tips": "TextLabel", "prompt": "ProximityPrompt", "stealPrompt": "ProximityPrompt",
    "sellPrompt": "ProximityPrompt", "cash": "IntValue", "leaderstats": "Folder", "sound": "Sound",
    "folder": "Folder", "carriedFolder": "Folder", "notifyHolder": "Frame", "screenGui": "ScreenGui",
    "remote": "RemoteEvent", "notifyEvent": "RemoteEvent", "knockbackEvent": "RemoteEvent",
    "remotes": "Folder", "backpack": "Backpack", "fade": "Tween", "carryWeld": "Weld",
    "tipWeld": "WeldConstraint", "instance": "Instance", "child": "Instance", "descendant": "Instance",
    "cashValue": "IntValue", "stealsValue": "IntValue", "bloom": "BloomEffect", "spawn": "SpawnLocation",
    "lockPad": "Part", "pad": "Part", "tip": "Part", "tool": "Tool", "template": "Tool",
    "gui": "BillboardGui", "shell": "Part", "band": "Part", "emitter": "ParticleEmitter",
    "light": "PointLight", "attachment": "Attachment", "mesh": "SpecialMesh", "corner": "UICorner",
    "stroke": "UIStroke", "cashPanel": "Frame", "notifyLayout": "UIListLayout", "tipsPadding": "UIPadding",
}

problems = []
notes = []

for path in sorted(src.rglob("*.luau")):
    text = path.read_text()
    code = re.sub(r"--\[\[.*?\]\]", "", text, flags=re.S)
    code = re.sub(r"--[^\n]*", "", code)
    rel = path.relative_to(src.parent)

    # Instance.new class names
    for m in re.finditer(r'Instance\.new\("(\w+)"\)', code):
        c = classes.get(m.group(1))
        if not c:
            problems.append(f"{rel}: unknown class Instance.new({m.group(1)})")
        elif "NotCreatable" in c.get("Tags", []):
            problems.append(f"{rel}: class not creatable: {m.group(1)}")

    for m in re.finditer(r'GetService\("(\w+)"\)', code):
        c = classes.get(m.group(1))
        if not c or "Service" not in c.get("Tags", []):
            problems.append(f"{rel}: not a service: {m.group(1)}")

    for m in re.finditer(r'(?:IsA|FindFirstChildOfClass|FindFirstAncestorOfClass)\("(\w+)"\)', code):
        if m.group(1) not in classes:
            problems.append(f"{rel}: unknown class in IsA/FindFirst*: {m.group(1)}")

    for m in re.finditer(r"Enum\.(\w+)\.(\w+)", code):
        e, item = m.groups()
        if e not in enums:
            problems.append(f"{rel}: unknown enum Enum.{e}")
        elif item not in enums[e]:
            problems.append(f"{rel}: unknown enum item Enum.{e}.{item}")

    # Per-file variable types: manual map, overridden by `local x = Instance.new("C")`
    types = dict(MANUAL)
    for m in re.finditer(r'local\s+(\w+)\s*=\s*Instance\.new\("(\w+)"\)', code):
        types[m.group(1)] = m.group(2)

    for m in re.finditer(r"(?<![\w.:])(\w+)([.:])(\w+)(\s*=(?!=))?", code):
        var, sep, name, assign = m.groups()
        cls = types.get(var)
        if not cls or cls not in classes:
            continue
        mem = members(cls)
        line = code.count("\n", 0, m.start()) + 1
        if name not in mem:
            notes.append(f"{rel}:{line}: {var}{sep}{name}  ({var} assumed {cls}) - not a member")
            continue
        info, owner = mem[name]
        tags = info.get("Tags", []) or []
        if "Deprecated" in tags:
            problems.append(f"{rel}:{line}: {var}{sep}{name} is deprecated on {owner}")
        if sep == ":" and info["MemberType"] not in ("Function",):
            problems.append(f"{rel}:{line}: {var}:{name} is a {info['MemberType']}, not a method")
        if sep == "." and info["MemberType"] == "Function":
            notes.append(f"{rel}:{line}: {var}.{name} is a method used with '.'")
        if assign and sep == ".":
            if info["MemberType"] != "Property":
                if info["MemberType"] != "Callback":  # callbacks (e.g. ProcessReceipt) are assigned
                    problems.append(f"{rel}:{line}: assigning to non-property {var}.{name}")
            elif "ReadOnly" in tags:
                problems.append(f"{rel}:{line}: {var}.{name} is read-only")
            else:
                sec = info.get("Security", {})
                w = sec.get("Write") if isinstance(sec, dict) else sec
                if w not in (None, "None"):
                    problems.append(f"{rel}:{line}: {var}.{name} write security {w}")

    # Generic `part[property] = value` in MapBuilder: check the extra-props tables passed to newPart
    for m in re.finditer(r"\{\s*((?:\w+\s*=\s*[^,{}]+,?\s*)+)\}", code):
        body = m.group(1)
        keys = re.findall(r"(\w+)\s*=", body)
        if "MapBuilder" in path.name and any(k in ("CanCollide", "Transparency", "CanQuery", "CanTouch", "CastShadow") for k in keys):
            mem = members("Part")
            for k in keys:
                if k not in mem:
                    problems.append(f"{rel}: newPart extra prop {k} is not a Part property")

    # Tween goal properties
    for m in re.finditer(r"TweenService:Create\((\w+),[^{]*\{([^}]*)\}", code, flags=re.S):
        var, body = m.groups()
        cls = types.get(var)
        if cls:
            mem = members(cls)
            for k in re.findall(r"(\w+)\s*=", body):
                if k not in mem:
                    problems.append(f"{rel}: tween goal {k} not on {cls}")

print("API problems:")
print("\n".join("  " + p for p in problems) or "  none")
if notes:
    print("Unknown member notes (fine when the variable isn't really that class):")
    print("\n".join("  " + n for n in sorted(set(notes))))
sys.exit(1 if problems else 0)
