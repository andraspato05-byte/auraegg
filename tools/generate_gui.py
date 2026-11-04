"""Generates the on-screen GUI (StarterGui.AuraEggHud) as a Rojo model file.

    python3 tools/generate_gui.py

Because the GUI is saved in the place, you can see and restyle it in Studio.
The client script (src/client/ClientMain.client.luau) finds elements by name,
so keep the names if you edit it.
"""

import json
import pathlib

OUT = pathlib.Path(__file__).resolve().parent.parent / "gui" / "AuraEggHud.model.json"

FREDOKA = {"Font": {"family": "rbxasset://fonts/families/FredokaOne.json", "weight": "Regular", "style": "Normal"}}
GOTHAM = {"Font": {"family": "rbxasset://fonts/families/GothamSSm.json", "weight": "Medium", "style": "Normal"}}

ALIGN_LEFT = {"Enum": 0}
ALIGN_TOP = {"Enum": 0}


def rgb(r, g, b):
    return {"Color3": [round(r / 255, 5), round(g / 255, 5), round(b / 255, 5)]}


def udim2(xs, xo, ys, yo):
    return {"UDim2": [[xs, xo], [ys, yo]]}


def vec2(x, y):
    return {"Vector2": [x, y]}


def node(name, cls, props=None, children=None):
    n = {"name": name, "className": cls, "properties": props or {}}
    if children:
        n["children"] = children
    return n


def corner(px):
    return node("Corner", "UICorner", {"CornerRadius": {"UDim": [0, px]}})


def stroke(color, thickness):
    return node("Stroke", "UIStroke", {"Color": color, "Thickness": thickness, "ApplyStrokeMode": {"Enum": 1}})


def frame(name, size, pos, color=None, transparency=0.0, anchor=(0, 0), children=None, extra=None):
    p = {
        "Size": size,
        "Position": pos,
        "AnchorPoint": vec2(*anchor),
        "BorderSizePixel": 0,
        "BackgroundColor3": color or rgb(30, 20, 50),
        "BackgroundTransparency": transparency,
    }
    if extra:
        p.update(extra)
    return node(name, "Frame", p, children)


def label(name, text, size, pos, color, anchor=(0, 0), font=FREDOKA, scaled=True, bg=None, bg_transparency=1.0,
          children=None, extra=None):
    p = {
        "Size": size,
        "Position": pos,
        "AnchorPoint": vec2(*anchor),
        "BorderSizePixel": 0,
        "BackgroundColor3": bg or rgb(0, 0, 0),
        "BackgroundTransparency": bg_transparency,
        "FontFace": font,
        "Text": text,
        "TextColor3": color,
        "TextScaled": scaled,
        "TextStrokeTransparency": 0.3,
        "TextStrokeColor3": rgb(0, 0, 0),
    }
    if extra:
        p.update(extra)
    return node(name, "TextLabel", p, children)


def button(name, text, size, pos, color, text_color, anchor=(0, 0), children=None, extra=None):
    p = {
        "Size": size,
        "Position": pos,
        "AnchorPoint": vec2(*anchor),
        "BorderSizePixel": 0,
        "BackgroundColor3": color,
        "FontFace": FREDOKA,
        "Text": text,
        "TextColor3": text_color,
        "TextScaled": True,
    }
    if extra:
        p.update(extra)
    return node(name, "TextButton", p, children)


def build():
    white = rgb(255, 255, 255)
    cash_panel = frame("CashPanel", udim2(0, 260, 0, 92), udim2(0.5, 0, 0, 8), transparency=0.15, anchor=(0.5, 0),
                       children=[
                           corner(14), stroke(rgb(180, 110, 255), 2),
                           label("Cash", "$0", udim2(1, -16, 0, 44), udim2(0, 8, 0, 4), rgb(120, 255, 140)),
                           label("Income", "+$0/s", udim2(1, -16, 0, 22), udim2(0, 8, 0, 48), rgb(255, 230, 120)),
                           label("Speed", "Speed 0", udim2(1, -16, 0, 18), udim2(0, 8, 0, 70), rgb(120, 220, 255)),
                       ])

    notifications = frame("Notifications", udim2(0, 460, 0, 220), udim2(0.5, 0, 0, 168), transparency=1,
                          anchor=(0.5, 0), children=[
                              node("Layout", "UIListLayout", {
                                  "SortOrder": {"Enum": 2}, "HorizontalAlignment": {"Enum": 0},
                                  "Padding": {"UDim": [0, 4]}}),
                          ])

    # under the cash panel (the top-right corner is taken by Roblox's player list)
    event_banner = frame("EventBanner", udim2(0, 320, 0, 54), udim2(0.5, 0, 0, 106), rgb(25, 25, 60), 0.15,
                         anchor=(0.5, 0), children=[
                             corner(12), stroke(rgb(110, 200, 255), 2),
                             label("Title", "NEXT EVENT: AURA STORM", udim2(1, -16, 0, 24), udim2(0, 8, 0, 3),
                                   rgb(150, 220, 255)),
                             label("Timer", "--:--", udim2(1, -16, 0, 22), udim2(0, 8, 0, 28), white),
                         ])

    carry_banner = label("CarryBanner", "", udim2(0, 520, 0, 44), udim2(0.5, 0, 1, -150), rgb(255, 220, 90),
                         anchor=(0.5, 0), bg=rgb(60, 20, 20), bg_transparency=0.25, children=[corner(12)],
                         extra={"Visible": False})

    tips_text = (
        "HOW TO PLAY\n"
        "- Buy Aura Eggs from the conveyor belt (E)\n"
        "- Eggs on your base make cash every second\n"
        "- Stand on the green pads to collect the cash\n"
        "- Steal eggs from other bases (hold E) and run home\n"
        "- Bonk thieves with your Aura Bat to get eggs back\n"
        "- Stand on the red pad to lock your base\n"
        "- Run on treadmills in the GYM to get faster\n"
        "- AURA STORM event: rare + Storm eggs!\n"
        "- Press SHOP for Robux boosts"
    )
    tips = label("HowToPlay", tips_text, udim2(0, 340, 0, 204), udim2(0, 12, 1, -12), white, anchor=(0, 1),
                 font=GOTHAM, scaled=False, bg=rgb(30, 20, 50), bg_transparency=0.25,
                 children=[corner(10), node("Padding", "UIPadding", {
                     "PaddingLeft": {"UDim": [0, 10]}, "PaddingRight": {"UDim": [0, 10]},
                     "PaddingTop": {"UDim": [0, 8]}})],
                 extra={"TextSize": 14, "TextWrapped": True, "TextXAlignment": ALIGN_LEFT,
                        "TextYAlignment": ALIGN_TOP, "TextStrokeTransparency": 1})

    shop_button = button("ShopButton", "SHOP", udim2(0, 130, 0, 56), udim2(0, 12, 0.5, 0), rgb(255, 190, 40),
                         rgb(60, 30, 0), anchor=(0, 0.5), children=[corner(12), stroke(rgb(120, 70, 0), 3)])

    header_template = label("HeaderTemplate", "SECTION", udim2(1, -8, 0, 26), udim2(0, 0, 0, 0),
                            rgb(200, 160, 255), extra={"Visible": False, "TextXAlignment": ALIGN_LEFT})
    item_template = frame("ItemTemplate", udim2(1, -8, 0, 72), udim2(0, 0, 0, 0), rgb(50, 35, 80),
                          extra={"Visible": False}, children=[
                              corner(10),
                              label("ItemName", "Item", udim2(0.62, -12, 0, 30), udim2(0, 12, 0, 6), white,
                                    extra={"TextXAlignment": ALIGN_LEFT}),
                              label("Description", "Description", udim2(0.62, -12, 0, 26), udim2(0, 12, 0, 38),
                                    rgb(200, 200, 220), font=GOTHAM, extra={"TextXAlignment": ALIGN_LEFT}),
                              button("Buy", "BUY", udim2(0.34, 0, 0, 46), udim2(1, -10, 0.5, 0), rgb(60, 190, 90),
                                     white, anchor=(1, 0.5), children=[corner(10)]),
                          ])

    shop_panel = frame("ShopPanel", udim2(0, 440, 0, 470), udim2(0.5, 0, 0.5, 0), rgb(30, 20, 50), 0,
                       anchor=(0.5, 0.5), extra={"Visible": False, "ZIndex": 10}, children=[
                           corner(16), stroke(rgb(255, 190, 40), 3),
                           node("SizeLimit", "UISizeConstraint", {"MaxSize": vec2(440, 470)}),
                           node("Scale", "UIScale", {"Scale": 1}),
                           label("Title", "AURA SHOP", udim2(1, -70, 0, 40), udim2(0, 16, 0, 10),
                                 rgb(255, 210, 80), extra={"TextXAlignment": ALIGN_LEFT}),
                           button("Close", "X", udim2(0, 36, 0, 36), udim2(1, -12, 0, 12), rgb(220, 60, 60), white,
                                  anchor=(1, 0), children=[corner(8)]),
                           node("Items", "ScrollingFrame", {
                               "Size": udim2(1, -24, 1, -72), "Position": udim2(0, 12, 0, 60),
                               "BackgroundTransparency": 1, "BorderSizePixel": 0, "ScrollBarThickness": 6,
                               "CanvasSize": udim2(0, 0, 0, 0), "AutomaticCanvasSize": {"Enum": 2},
                           }, [node("Layout", "UIListLayout", {"SortOrder": {"Enum": 2}, "Padding": {"UDim": [0, 8]}})]),
                           header_template,
                           item_template,
                       ])

    storm_test = button("StormTestButton", "START STORM (Studio test)", udim2(0, 190, 0, 32),
                        udim2(0, 12, 0.5, 50), rgb(70, 110, 220), white, anchor=(0, 0.5),
                        extra={"Visible": False}, children=[corner(8)])

    return {
        "className": "ScreenGui",
        "properties": {"ResetOnSpawn": False, "ZIndexBehavior": {"Enum": 1}},
        "children": [cash_panel, notifications, event_banner, carry_banner, tips, shop_button, storm_test,
                     shop_panel],
    }


if __name__ == "__main__":
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(json.dumps(build(), indent=1))
    print("wrote", OUT)
