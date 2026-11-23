#!/usr/bin/env python3
"""
Builds a ready-to-open Roblox place file (.rbxlx) from src/, mirroring
default.project.json, so the game opens in Studio with one double-click
(no Rojo needed).

    python3 tools/build_place.py            -> build/Zabour.rbxlx
"""
import os
import sys
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
OUT_DIR = os.path.join(ROOT, "build")
OUT = os.path.join(OUT_DIR, "Zabour.rbxlx")

_ref = 0


def ref():
    global _ref
    _ref += 1
    return f"RBX{_ref:06d}"


def cdata(text):
    # "]]>" cannot appear inside CDATA; split it across two sections.
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(cls, name, props="", children=""):
    return (
        f'<Item class="{cls}" referent="{ref()}"><Properties>'
        f'<string name="Name">{escape(name)}</string>{props}</Properties>'
        f"{children}</Item>"
    )


def script_item(path, name):
    with open(path, encoding="utf-8") as f:
        source = f.read()
    if path.endswith(".server.luau"):
        cls = "Script"
    elif path.endswith(".client.luau"):
        cls = "LocalScript"
    else:
        cls = "ModuleScript"
    return item(cls, name, f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>')


def strip_ext(filename):
    for ext in (".server.luau", ".client.luau", ".luau"):
        if filename.endswith(ext):
            return filename[: -len(ext)]
    return filename


def folder_item(path, name):
    children = []
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if os.path.isdir(full):
            children.append(folder_item(full, entry))
        elif entry.endswith(".luau"):
            children.append(script_item(full, strip_ext(entry)))
    return item("Folder", name, children="".join(children))


def main():
    s = lambda *p: os.path.join(SRC, *p)
    services = [
        item("ReplicatedFirst", "ReplicatedFirst",
             children=script_item(s("ReplicatedFirst", "LoadingScreen.client.luau"), "LoadingScreen")),
        item("ReplicatedStorage", "ReplicatedStorage",
             children=folder_item(s("ReplicatedStorage", "Shared"), "Shared")),
        item("ServerScriptService", "ServerScriptService",
             children=folder_item(s("ServerScriptService", "Server"), "Server")),
        item("StarterPlayer", "StarterPlayer",
             children=item("StarterPlayerScripts", "StarterPlayerScripts",
                           children=folder_item(s("StarterPlayer", "StarterPlayerScripts", "Client"), "Client"))),
        item("Players", "Players", '<bool name="CharacterAutoLoads">false</bool>'),
        item("Lighting", "Lighting",
             '<token name="Technology">4</token>'  # Enum.Technology.Future
             '<bool name="GlobalShadows">true</bool>'
             '<float name="EnvironmentDiffuseScale">0.85</float>'
             '<float name="EnvironmentSpecularScale">1</float>'
             '<float name="ShadowSoftness">0.2</float>'),
        item("MaterialService", "MaterialService", '<bool name="Use2022Materials">true</bool>'),
    ]
    xml = '<roblox version="4">' + "".join(services) + "</roblox>"
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(xml)
    print(f"wrote {OUT} ({len(xml)//1024} KB)")


if __name__ == "__main__":
    sys.exit(main())
