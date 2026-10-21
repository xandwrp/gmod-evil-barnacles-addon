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
- The barnacle hauls them up, eats the headcrab at the mouth and keeps them. They keep fighting until it takes their wrists, then the rest of them follows
- The barnacle can't be hurt while it's wearing someone. Kill the body and the barnacle dies and drops it
- Shoot the headcrab off before it gets them to a barnacle to let them go

Otherwise the evil barnacle is a normal barnacle.

## Settings

Spawn menu > Utilities > Syhgma's Evil Entities > Evil headcrabs (superadmins), or the convars. They all start with `evil_headcrab_`.

- Targets NPCs
- Hold time, how many seconds it hangs on before the victim pries it off
- Barnacle sense range, how far it can sense an evil barnacle to steer toward, 0 for never
