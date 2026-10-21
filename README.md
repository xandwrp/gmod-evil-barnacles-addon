# Evil headcrabs

> Headcrabs for Garry's Mod.

## Needs

- [Syhgma's Evil API](https://steamcommunity.com/sharedfiles/filedetails/?id=3823740816) ([source](https://github.com/xandwrp/gmod-evil-api))

## Spawning

Entities > Syhgma's Evil Entities > Evil headcrab or Evil barnacle. The barnacle goes on the ceiling above wherever you aim.

## What it does

- Wanders around and idles, using the navmesh if the map has one
- Leaps onto NPCs' heads
- Whoever it lands on panics, runs around blind and tries to pry it off, then slowly loses it
- Once it has them they stand there zoned out, slightly hunched with their mouth hanging open and eyes rolled back
- If there's an evil barnacle nearby they shamble over to it and walk right under it
- It pulls them up and sockets their head in, eating the headcrab. There's no getting them back after that
- The barnacle can't be hurt while it's wearing someone. Kill the body and the barnacle dies with it
- Shoot the headcrab off before it gets them to a barnacle to let them go

Otherwise the evil barnacle is a normal barnacle.

## Settings

Spawn menu > Utilities > Syhgma's Evil Entities > Evil headcrabs (superadmins), or the convars. They all start with `evil_headcrab_`.

- Targets NPCs
- Capture time, how many seconds a victim struggles before it has them
- Instantly capture victims, skips the struggle and greys out capture time
- Barnacle lure range, how far captured victims walk to find an evil barnacle, 0 to stay put
