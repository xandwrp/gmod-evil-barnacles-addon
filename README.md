# Evil barnacles

> Barnacles for Garry's Mod that keep what they catch.

On the [Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3825026975).

## Needs

- [Syhgma's Evil API](https://steamcommunity.com/sharedfiles/filedetails/?id=3823740816) ([source](https://github.com/xandwrp/gmod-evil-api))

Optional:

- [Evil Fungus](https://steamcommunity.com/sharedfiles/filedetails/?id=3821991353), barnacles grow a patch of it around themselves

## Spawning

Entities > Syhgma's Evil Entities > Evil barnacle. It goes on the ceiling above wherever you aim.

## What it does

- Catches and hauls people up like a normal barnacle
- Players mash jump on the way up to struggle off the tongue
- Reach the mouth and it kills them, no gibs, no bones. It keeps the body hanging from its mouth, and they watch from there until they press jump to give up
- NPCs get kept the same way. They claw at it and kick for a while, then go limp
- Once a body goes still it stays put. With fungus close by, it gets wired in and slowly turns to fungus, all but the head
- It can't be hurt while it's wearing someone. Shoot the body enough and the barnacle dies and drops it
- If it catches someone new it drops the old body for the new one
- With Evil Fungus installed, it grows a patch of fungus on the ceiling around itself. The patch stays put and stops growing at a set size, until other fungus grows into it and they join up
- With Evil Fungus, a body that's been in the fungus a while gets dropped, still on the tongue. It gets up and paces a circle under the barnacle, still on the tongue. Whoever it grabs gets the tongue instead and dragged back under to be caught, and the old body bursts into fungus
- Kill the barnacle and the leash snaps, the body wanders off to burst somewhere high. Players dragged on it can mash jump to get loose

## Settings

Spawn menu > Utilities > Syhgma's Evil Entities > Evil barnacles (superadmins), or the convars. They all start with `evil_barnacle_`.

- Jump presses to escape, roughly how many it takes a player to struggle off the tongue
- Fungus, how many strands of Evil Fungus a new barnacle grows around itself. 0 for none
- Fungus takeover, seconds the fungus takes to turn a kept body, all but the head
- Leash, how far a body let down on the tongue can walk out from under the barnacle. 0 keeps them hanging
- Let down after, seconds a body hangs in the fungus before it gets let down
