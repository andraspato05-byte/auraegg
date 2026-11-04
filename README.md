# Steal the Aura Egg

A Roblox game in the "steal a ___" style. Buy glowing **Aura Eggs** off the conveyor belt, put them on your base to earn cash, and **steal other players' eggs** before they steal yours.

## Open it in Roblox Studio (easiest)

1. Download `StealTheAuraEgg.rbxlx` from this repo.
2. Open **Roblox Studio**, then **File > Open from File...** and pick `StealTheAuraEgg.rbxlx`.
3. The whole map is already in the place: 8 bases, the Aura Egg Machine and runway, 2 treadmill gyms, fountains, trees and lights. Press **Play** (F5) to start; the eggs and labels appear when the game runs.
4. To test stealing with several players: **Test** tab > **Clients and Servers** > pick 2 or more players > **Start**.

### Before you publish

- **Game Settings > Places > Max Players = 8.** The map has exactly 8 bases.
- To make progress save: publish the place, then turn on **Game Settings > Security > Enable Studio Access to API Services**. Without it the game still works; it just won't save, and players get a message saying so.

## How to play

| Action | How |
| --- | --- |
| Buy an egg | Walk up to an egg on the belt and press **E** |
| Earn cash | Eggs on your pedestals make cash every second |
| Collect cash | Stand on the **green pad** next to each pedestal |
| Steal | Go into another base and **hold E** on an egg, then run back into your own base |
| Stop a thief | Hit them with your **Aura Bat** (click). They drop the egg and it goes back to its owner |
| Lock your base | Stand on the **red pad** at the back. Nobody else can get in for 60 seconds (then 10 seconds cooldown) |
| Sell an egg | **Hold F** on one of your own eggs to sell it for 50% of its price |
| Get faster | Run on the **treadmills** in the gyms (next to the Egg Vault). The belt pushes you back, so keep running! You earn **Speed**, and every 20 Speed adds +1 walk speed (max 500 Speed) |

### Treadmill gym

| Treadmill | Speed per second | Needs |
| --- | --- | --- |
| Tier 1 (green) | +1 | 0 Speed |
| Tier 2 (blue) | +2 | 100 Speed |
| Tier 3 (purple) | +4 | 250 Speed |
| Tier 4 (gold) | +8 | 400 Speed |

Carrying a stolen egg slows you to 70% of your walk speed (the Speedy Thief game pass removes the slowdown). Speed is saved.

A thief who dies, gets bonked, or leaves the game drops the egg, and it goes back to its owner's pedestal. Carrying an egg slows you down.

## Event: AURA STORM

A purple lightning storm rolls in **3 minutes after a server starts, then every 15 minutes**, and lasts **4 minutes**. A banner under the cash counter shows the countdown, and everyone gets a warning 30 seconds before.

During the storm:
- the sky goes dark purple with storm clouds and lightning flashes
- the Aura Egg Machine sends out eggs **twice as fast**
- **Rare and better eggs are 3x more likely**
- **30% of eggs come out Storm-charged**: they crackle with blue lightning, earn **3x cash** and cost 2.5x. Storm eggs keep their power forever (they're saved) and can be stolen like any other egg.

In Studio there's a blue **START STORM (Studio test)** button under SHOP to start a storm right away. It doesn't show up or work in the live game. Timings and multipliers are in `Config.Event` and `Config.Mutations`.

## Robux shop (game passes and developer products)

Press **SHOP** on the left side of the screen. Nothing can be bought until you add your own IDs:

1. Publish the game, then go to **create.roblox.com > your game > Monetization**.
2. Under **Passes**, create the 3 game passes. Under **Developer Products**, create the 4 products. Set a Robux price for each.
3. Copy each ID into `src/shared/Config.luau` (in Studio: `ReplicatedStorage > Shared > Config`), replacing the `Id = 0` values.

| Type | Name | What it does |
| --- | --- | --- |
| Game pass | 2x Cash | Every egg on your base makes double cash |
| Game pass | Speedy Thief | No slowdown while carrying a stolen egg |
| Game pass | Mega Lock | Base lock lasts 120 s instead of 60 s |
| Product | Pile / Bag / Vault of Cash | +$10K / +$250K / +$5M |
| Product | Lucky Aura Egg | A random Legendary, Mythic or Secret egg (its price in cash if your base is full) |

Items with `Id = 0` show "Not set up" in the shop. Purchases are granted with Roblox's recommended receipt handling (each purchase is recorded, so it's never given twice and never lost).

## The Aura Eggs

| Rarity | Eggs | Price | Cash/sec |
| --- | --- | --- | --- |
| Common | Dusty, Pebble, Leafy | $25 to $60 | 1 to 3 |
| Uncommon | Bubble, Ember, Minty | $150 to $400 | 6 to 15 |
| Rare | Frost, Thunder, Ocean | $1K to $3K | 35 to 95 |
| Epic | Shadow, Crystal, Void | $8K to $25K | 230 to 650 |
| Legendary | Solar, Dragon, Cosmic | $60K to $200K | 1.5K to 4.5K |
| Mythic | Phoenix, Galaxy | $600K to $1.2M | 12K to 22K |
| Secret | Rainbow, Omega (rainbow aura) | $5M to $15M | 80K to 220K |

Higher rarities are bigger and glow more, and they show up on the belt less often. Legendary and better eggs get announced to the whole server when they appear or get stolen.

To add or change eggs, prices, timers or speeds, edit `src/shared/Config.luau` (or `ReplicatedStorage > Shared > Config` in Studio).

## Project layout

```
default.project.json          Rojo project (maps src/ and map/ into the game)
map/Map.model.json            The world (generated by tools/generate_map.py)
map/Plots.model.json          The 8 bases (generated by tools/generate_map.py)
tools/generate_map.py         Map generator: python3 tools/generate_map.py
gui/AuraEggHud.model.json     On-screen GUI: HUD, SHOP, event banner -> StarterGui
tools/generate_gui.py         GUI generator: python3 tools/generate_gui.py
StealTheAuraEgg.rbxlx         Ready-to-open place file (built from src/ with Rojo)
src/shared/Config.luau        Settings + all Aura Eggs      -> ReplicatedStorage.Shared
src/server/Main.server.luau   Server entry point            -> ServerScriptService.Server
src/server/MapBuilder.luau    Finds the map parts the game needs and adds the labels
src/server/PlotService.luau   Bases, income, pads, lock, stealing, selling
src/server/ConveyorService.luau  Egg belt + buying
src/server/BatService.luau    The Aura Bat
src/server/TreadmillService.luau  Treadmills and the Speed stat
src/server/EventService.luau  AURA STORM event schedule and effects
src/server/MonetizationService.luau  Game passes + developer products (Robux)
src/server/EggVisuals.luau    Egg models, auras, particles, name tags
src/server/DataManager.luau   Saving and loading (DataStoreService)
src/server/Session.luau       Cash / steals + leaderstats
src/server/Remotes.luau       RemoteEvents
src/client/ClientMain.client.luau  Makes the GUI work: HUD, SHOP, event banner, effects
```

## Editing the map

You can decorate the map directly in Studio. The scripts find a few parts by name, so keep these:
`Workspace.Map.ConveyorBelt`, `Workspace.Map.AuraEggMachine`, `Workspace.Map.TitleAnchor`, the `Treadmill` models (with their `Belt` part and `Tier` attribute) and, inside every `Workspace.Plots.PlotN`: `Origin`, `LockBarrier`, `SignAnchor`, `LockPad`, `Eggs`, `Pedestal1-10`, `CashPad1-10`.

The on-screen GUI is in `StarterGui > AuraEggHud`, so you can restyle it in Studio too. Keep the element names (CashPanel, ShopButton, ShopPanel, EventBanner, ...); the client script finds them by name.

## Working with Rojo (optional)

If you want to edit the code in VS Code and sync it live into Studio:

```bash
rojo serve
```

Then connect with the Rojo Studio plugin. To rebuild the place file:

```bash
rojo build default.project.json -o StealTheAuraEgg.rbxlx
```

Lint with [selene](https://github.com/Kampfkarren/selene): `selene src`.
