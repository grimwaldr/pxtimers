# pxtimers

Timer bars for Phoenix XI, an Ashita v4 addon. Four stacks of bars: buffs you cast, debuffs you land, your recasts, and timers of your own.

## Install

1. Download this repo (Code > Download ZIP) and unzip it into your Ashita `addons` folder as a folder named `pxtimers`, so you have `addons/pxtimers/pxtimers.lua`.
2. In game, type `/addon load pxtimers`.
3. To load it every time you play, add `/addon load pxtimers` to your Ashita startup script.

Settings are kept per character in `config/addons/pxtimers`.

## Using it

| Panel | What it shows | Starts at |
|---|---|---|
| Buffs | Buffs you cast, one bar per buff (hover for who has it) | Left, growing up |
| Debuffs | Debuffs you land, per mob | Left, growing down |
| Recasts | Your spell and ability recasts, filling up until ready | Right, growing up |
| Custom | Timers you start with `/pxt custom` | Right, growing down |

Each bar shows the icon, the name and the time left. A panel widens to fit its longest name, so names are never cut short; the Width setting is the narrowest it goes. The colour moves from High to Mid to Low as it runs out (green, gold, red by default; recasts go the other way and turn green when nearly ready). A bar flashes for a few seconds when it ends.

- **Move:** `/pxt move` unlocks every panel and fills it with sample bars. Drag a panel by its bars or its name tab, then `/pxt lock`.
- **Shift-click** a bar to remove it.
- **Ctrl-click** a bar to remove it and stop that action making bars. Undo it on the Blocked tabs in `/pxt`.
- **Hover** a bar for its details.

`/pxt` opens the settings: per panel size, scale, bar count, sort, grow direction, count down or up, colours and their time marks, plus the font, icons and who to track.

## Fonts

| Font | What it is |
|---|---|
| DejaVu Mono | DejaVu Sans Mono, shipped in `lib/fonts/` at every scale. The default |
| Moji | The game's own text font, read from your game files (`ROM/119/51.DAT`, or another region's copy). Nothing from the game ships with pxtimers. It's a 16px bitmap, so it's used at scale 1 and other scales fall back to DejaVu Mono |
| Ashita | Ashita's ImGui font |

If a font can't load, pxtimers says so once in chat and uses the next one.

## Commands

| Command | What it does |
|---|---|
| `/pxt` | Settings |
| `/pxt move` | Unlock the panels to drag them |
| `/pxt lock` | Lock them and save where they are |
| `/pxt custom "Label" 5m [repeat] ["tooltip"]` | A timer of your own: `30s`, `5.5m`, `1h`, or a clock time like `17:13:20` |
| `/pxt stop "Label"` | Remove a custom timer |
| `/pxt font [mono\|moji\|ashita]` | The bar font. Alone, the next one |

## Durations on Phoenix

Durations are worked out the way the Phoenix server works them out, from github.com/phoenixffxi/Phoenix including its era modules. Where the era rules differ from retail, the era value is used:

| What | Phoenix |
|---|---|
| Bar-element spells | 150s, plus 0.8s per Enhancing skill over 180 |
| Bar-status spells | 480s flat |
| Monomi: Ichi | 180s |
| Poison | 30s |
| Dread Spikes | 60s |
| Absorb spells | 90s, no gear bonus |
| Focus, Dodge | 120s |
| Boost | 180s |
| Holy, Arcane, Warding, Ancient Circle | 60s, artifact gear +90s |
| Last Resort | 30s |
| Killer Instinct | 60s |
| Light Shot | 90s |
| Reactor Cool, Plasma Charge, Diamondhide | 120s, 60s, 300s |
| Wasp Sting, Viper Bite, Shockwave, Armor Break, Full Break, Shell Crusher, Vidohunir, Tachi: Gekko | era TP formulas |

Also tracked: enfeebling ninjutsu (Jubaku, Hojo, Kurayami, Dokumori, Yurin), Flash, Bind, Stun, and single-effect blue magic debuffs (Sheep Song, Soporific, Yawn, Dream Flower, Filamented Hold, Cimicine Discharge, Sandspray, Chaotic Eye, and others).

## Limits

- A partial resist shortens a debuff on the server, and the client isn't told by how much. The bar shows the full duration and is cleared when the wear-off message arrives.
- Some durations are random on Phoenix (Sneak, Invisible, Deodorize, Hide, Camouflage, Blind, Paralyze, Silence, Bind, Stun). These show the longest they can last and clear on the wear-off message.
- Buffs on yourself use the timers the server sends. Buffs on other players are worked out from your gear and merits, since the server doesn't send their timers.

## Files

```
pxtimers.lua      settings, commands, events
panel.lua         one stack of bars: sorting, drawing, clicks and dragging
draw.lua          text, icons and colours on ImGui draw lists
config.lua        the /pxt window
blockeditor.lua   the Blocked tabs
trackers/         buff, debuff, recast and custom timers from the game's packets
durations/        how long each spell, ability and weapon skill lasts
actionpacket.lua  reads action packets
buffflags.lua     which buffs overwrite which
helpers.lua       file paths and chat messages
lib/              fonts (DejaVu Mono atlases, the game's font) and text encoding
resources/        recast icons for spells and abilities
```

## Why it works this way

**Everything is drawn with ImGui.** Bars, icons and text go on ImGui draw lists, the same way Ashita draws its own windows. There's no native font DLL, no GDI+ and no D3DX sprite, so it draws the same under Wine or Proton as on Windows.

**Fonts are drawn, not loaded.** Loading a font into ImGui while the game is running can crash it. Both extra fonts are drawn letter by letter as small textured squares, with a dark ring baked in so the text reads on any bar colour.

**Clicks never go through ImGui.** Each panel is a click-through window. The addon checks the mouse against its own bars, so a locked panel never takes a click from the game. Only shift-clicks and ctrl-clicks on a bar, and drags in move mode, are kept from it.

**Paired panels share an edge.** Buffs grow up and debuffs grow down from the same spot, so the two stacks sit together without overlapping however many bars each has. Move mode puts each panel's name tab on its far edge so the pair can still be dragged apart.

**Durations follow the server, not a wiki.** The values come from Phoenix's own scripts and era modules, checked spell by spell and ability by ability against what the server runs. Random durations show their longest value, because a bar that ends early is worse than one cleared by the wear-off message.

**Bad icons don't stop a bar.** Each icon texture is made once. One that fails is remembered and skipped, and the bar is drawn without it.

## License

pxtimers is free software under the [GNU General Public License v3.0](LICENSE). The tracking and duration code is adapted from Thorny's tTimers (MIT); its copyright notice is kept in those files. The DejaVu Sans Mono atlases in `lib/fonts/` are under their own licence ([lib/fonts/LICENSE-DejaVu.txt](lib/fonts/LICENSE-DejaVu.txt)).
