# WU (武)

WU is a 2d action roguelike game that focuses on 1v1 combats. 
* core highlights: satisfying sekiro-like combat, diverse build with great replayability, great unique art style.
* It has a pixel art style. Inspirations: Dead Cells, Blasphemous 2, Katana ZERO, Celeste, Artis Impact.
* It has smooth animations.
* The background is set in acient China, and is mostly Wuxia vibes but also some Xianxia vibes.
* Single-player PvE.
* The player choose a character and starts a run. 
* Each run is in a format similar to Slay the Spire: 3 maps, each map is a graph that ends at a boss. Before the boss there are differnt nodes such as normal enemies, elite enemies, treasures, shops, events, and so on.
* Each combat is a 1v1 combat, 2d scroll perspective like in Dead Cells and Blasphemous, but the combat resembles more like Sekiro, that the interactions between the enemy and the player is highly dynamic.
* The character has initial movesets, but during the run, the character can replace or enhence the set. New moves are rewarded after a combat victory or events.
* During the combat, the character has resources: posture, rage.
    * posture works like in Sekiro.
    * Rage increase when making damage or got damaged, and can be used to cast powers. Powers are a kind of rewards during the run.

## Roadmap

* first demo: a playable run
    * Create a detailed art style doc. Making sure all art assets follow it.
    * Design the combat system
        * one init character, with init moveset.
        * Relics and potions
        * Movesets and powers from differnt LIU (流派)
        * enemy design
* out-of-run system
    * Differnt initial unlockable characters, each with differnt movesets
    * unlockable events, enemies, relics, LIUs.
* narritives

## Tech choices

* Monogames
* Steam first, but mobile is also great.

## Demo (MonoGame)

A minimal 2D 1v1 combat prototype is included using MonoGame DesktopGL.

Run locally:

1. Ensure .NET SDK is installed (9.0+).
2. If you're behind a local proxy, export it first:
   
   ```bash
   export ALL_PROXY=http://127.0.0.1:8234
   ```
3. Launch the demo:
   
   ```bash
   dotnet run --project WUDemo -c Debug
   ```

Controls:
- A / D: move
- J: light attack
- K: block / quick-tap to parry during enemy red flash
- Space: dash
- R: restart
- Esc: quit

Mechanics (prototype):
- Health, Posture, Rage bars for both sides.
- Blocking reduces HP damage but raises posture damage.
- Parry (tap K just before the hit) stuns the attacker and damages posture.
- Simple enemy AI telegraphs attacks with a red flash.