# Evil headcrabs

> Headcrabs for Garry's Mod.

## Needs

- [Syhgma's Evil API](https://steamcommunity.com/sharedfiles/filedetails/?id=3823740816) ([source](https://github.com/xandwrp/gmod-evil-api))

## Spawning

Entities > Syhgma's Evil Entities > Evil headcrab or Evil barnacle. The barnacle goes on the ceiling above wherever you aim.

## What it does

- Wanders around and idles, using the navmesh if the map has one
- Leaps onto NPCs' heads
- Whoever it lands on panics, runs around blind and tries to pry it off
- If it can sense an evil barnacle it steers their running toward it, until they stumble in under the tongue
- Hold out long enough and they pry it off, throw it, and run
- The barnacle hauls them up, eats the headcrab at the mouth and keeps them. They claw at it and kick for a while, then go limp
- The barnacle can't be hurt while it's wearing someone. Kill the body and the barnacle dies and drops it
- Shoot the headcrab off before it gets them to a barnacle to let them go
- With players turned on it goes for them too. They get run around the same way and have to mash jump to pry it off, even on the tongue. Make it to the mouth with it still on and the barnacle eats it and keeps them, like anyone else

Otherwise the evil barnacle is a normal barnacle.

## Settings

Spawn menu > Utilities > Syhgma's Evil Entities > Evil headcrabs (superadmins), or the convars. They all start with `evil_headcrab_`.

- Targets NPCs
- Targets players, off by default
- Jump presses to escape, roughly how many it takes a player to pry it off
- Hold time, how many seconds it hangs on before an NPC pries it off
- Barnacle sense range, how far it can sense an evil barnacle to steer toward, 0 for never
