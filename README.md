# Garry's Royale
*aka* **gRoyale** or **GBR**
Garry's Royale is a heavily WIP gamemode intending to emulate the primary gameplay loop of games like Fortnite or PubG,
with some original elements to help give server owners more control.

Garry's Royale was built from a "customization-first" perspective. The entire mod is built to play with other mods and be configured
like you want, and the gamemode is extendable such that any mod authors can integrate ways to allow their mods to play with the existing systems.

Garry's Royale will in the future, use STools and GUIs to make the configuration process easier, but for now, the process involves editing JSON files.
The JSON Schema is documented below:

## Spawnlist Schema
```json
{
	"weapons": {
		"items": {
			"weapon_pistol": {
				"accompanying_groups": [],
				"rarity": "Common",
				"spawn_with": [
					["item_ammo_pistol", 1.0]
				]
			},
			"weapon_shotgun": {
				"accompanying_groups": [],
				"rarity": "Uncommon",
				"spawn_with": [
					["item_box_buckshot", 1.0]
				]
			},
			"weapon_crossbow": {
				"accompanying_groups": [],
				"rarity": "Rare",
				"spawn_with": [
					["item_ammo_crossbow", 1.0]
				]
			},
			"weapon_rpg": {
				"accompanying_groups": [],
				"rarity": "Legendary",
				"spawn_with": [
					["item_rpg_round", 0.75]
				]
			}
		},
		"rarities": [
			["Common", 0.4],
			["Uncommon", 0.3],
			["Rare", 0.2],
			["Legendary", 0.1]
		]
	},
	"ammo": {
		"items": {
			"item_box_buckshot": {
				"accompanying_groups": [],
				"rarity": "Commodity",
				"spawn_with": []
			},
			"item_ammo_pistol": {
				"accompanying_groups": [],
				"rarity": "Commodity",
				"spawn_with": []
			},
			"item_rpg_round": {
				"accompanying_groups": [],
				"rarity": "Unique",
				"spawn_with": []
			},
			"item_ammo_crossbow": {
				"accompanying_groups": [],
				"rarity": "Rarity",
				"spawn_with": []
			}
		},
		"rarities": [
			["Commodity", 0.7],
			["Rarity", 0.2],
			["Unique", 0.1]
		]
	},
	"vehicles_commercial": {
		"items": {
			"sim_fphys_charger": {
				"override_spawn_function": "GBRSpawnSimfphys",
				"spawn_modifiers": {
					"RandomizedColor": "vehicleVibrant",
					"RandomizeBodygroups": ""
				}
			},
			"sim_fphys_dukes": {
				"override_spawn_function": "GBRSpawnSimfphys",
				"spawn_modifiers": {
					"RandomizedColor": "vehicleVibrant",
					"RandomizeBodygroups": ""
				}
			},
			"sim_fphys_cod_st_wagon": {
				"override_spawn_function": "GBRSpawnSimfphys",
				"spawn_modifiers": {
					"RandomizedColor": "vehicleDull"
				}
			},
			"sim_fphys_madmax_interceptor_falcon": {
				"override_spawn_function": "GBRSpawnSimfphys"
			},
			"sim_fphys_hp_izhkomby": {
				"override_spawn_function": "GBRSpawnSimfphys",
				"spawn_modifiers": {
					"RandomizedColor": "vehicleDull"
				}
			},
			"sim_fphys_bms_jcv": {
				"override_spawn_function": "GBRSpawnSimfphys",
				"spawn_modifiers": {
					"RandomizedColor": "vehicleDull"
				}
			},
			"sim_fphys_opel_blitz": {
				"override_spawn_function": "GBRSpawnSimfphys",
				"spawn_modifiers": {
					"RandomizedColor": "vehicleDull"
				}
			},
			"sim_fphys_zil_130": {
				"override_spawn_function": "GBRSpawnSimfphys",
				"spawn_modifiers": {
					"RandomizedColor": "vehicleDull"
				}
			}
		}
	} 
}
```
A "spawn list" describes a collection of "spawn groups". Each spawn group is unique, and can have it's own set of rarities. Spawn groups define a set of entities
that should be able to spawn in the same place. For instance, inside a garage, you may wish to have a spawn for `"vehicles_commercial"`, whereas in a military
compound, you may want to reference one called `"vehicles_military"`. There is also no rule against spawn groups overlapping, so you could create a 3rd group 
called `"vehicles"` that contains everything.

Rarity is an optional list of arrays, the first part of the array is the name of the rarity, where the second part is it's spawn weight.
Span weight can be a decimal or an integer, and it does not have to add up to 1. Very small decimal values, as well as very large numbers are highly discouraged,
as with the current way weighted values are calculated big numbers, or numbers with lots of decimal places, will cause performance hits.
Weights work with like this. If `A` has a weight of 5, and `B` has a weight of `1`, then for every 5 `A`s, you can expect 1 `B`. To give an item a rarity, just
add `"rarity"` inside of it's pair of `{}`. If you define a `"rarities"` table for a spawn group, you must also give a rarity to every single item.

The next thing you'll see is the `"items"` field. The key for each entry here should be the internal name of the item. This doesn't mean an entity class name
though, [Simfphys](https://github.com/Blu-x92/simfphys_base) cars all derive from `gmod_sent_vehicle_fphysics_base`, this is where `override_spawn_function`
comes in. Using this, you can tell gRoyale to use a loaded alternative spawn method instead, for instance, `GBRSpawnSimfphys`, which will look for
a Simfphys vehicle with the correct internal name and spawn that. Items can also be given spawn modifiers. Spawn modifiers allow you to change what happens
to an entity after it gets spawned. For instance, `"RandomizedColor"`, is passed the argument `"VehicleDull"`. This tells gRoyale to randomly color the entity
with one of the "Dull Vehicle" colors. The Syntax is `"ModifierName": "Argument1,Argument2"` (It does not remove extra whitespace). If you don't want to pass
any arguments, just use an empty string: `"RandomizeBodyGroups": ""`.

The final two things you'll notice attached to the item are `"accompanying_groups"` and `"spawn_with"`. `"accompanying_groups"` syntax looks like this:
```json
"accompanying_groups": [
	[ "group1_name", group1_chance, group1_max ],
	[ "group2_name", group2_chance, group2_max ]
]
```
`"groupN_name"` is the name of a valid spawn group. This can be a recursive call to the same spawn group, but gRoyale will respact `sv_gbr_maxrecursivecalls`,
which defaults to `6`. `groupN_chance` is the chance for **each individual item** to spawn, and `groupN_max` is how many items gRoyale will try to randomly spawn.
Using accompanying groups allows you to make use of rarities and spawn modifiers on any newly created items, but it is also more complicated and more expensive.

So instead, for simple things, use `"spawn_with"`. `"spawn_with"` is a simple list of entities to spawn. It looks like this:
```json
"spawn_with": [
	["item_buckshot", 1.0],
	["item_buckshot", 0.5]
]
```
This goes over each item and computes it's spawn chance (the second value), then simply spawns it if it spawned. So this config would guarentee the item spawns
with one buckshot box, and a 50% chance of an extra buckshot box. This method is easier to setup, and faster performance wise, but it also doesn't let you 
use any `"override_spawn_function"`s, or apply `"spawn_modifiers"`. This was essentially made for spawning ammunition.

## Map Config Schema
Map configs are all stored under `GarrysMod/garrysmod/data/garrys_royale/map_settings/%map_name%/%config_name%.json`. They contain info about a map, as well as
any spawn points. If a map config tries to use spawn groups that are not defined, this will result in errors, so if you have many spawn lists, you may want to
use a naming scheme that mentions them.
```json
{
	"storm": {
		"bounds": {
			"min": [-5205, -3675, 20],
			"max": [1635, 6180, 310]
		},
		"starting_radius": 100000,
		"spherical": false, 
		"starting_timer": 150,
		"timer_rate": 5, 
		"move_timer_multiply": 1.0, 
		"final_phase": 10,
		"minimum_shrink_amount": 0.333333,
		"maximum_shrink_amount": 0.666666,
		"minimum_storm_size": 700, 
		"maximum_move_ratio": 0.5, 
		"minimum_move_amount": 0, 
		"damage": {
			"0": 2,
			"4": 5,
			"8": 10
		}
	},
	"event_blacklist": [], 
	"create": [
		{
			"classname": "models/props_c17/oildrum001.mdl ",
			"pos": [0, 0, 0],
			"angle": [0, 0, 0],
			"override_spawn_function": "GBRSpawnProp"
		}
	],
	"remove": [
		1389, 1236, 1237, 1238, 1239, 1240
	],
	"spawn_locations": [
		{
			"spawn_groups": [
				["weapons", 1.0]
			],
			"spawn_chance": 1.0,
			"pos": [ 100, 100, -50 ],
			"angle": [ 0, 0, 0]
		}
	],
	"lobby": {
		"pos": [7000, 200, 50],
		"radius": 2500,
		"spherical": false, 
		"spawns": [], 
		"player_spawns": [
			{
				"pos": [ -3947, 4641, 2515 ],
				"angle": [ 0, -45, 0 ]
			}
		],
		"player_damage": "none"
	}
}
```
There is a lot here, so let's try and go over it sucinctly
- The `storm` table defines information about how the storm should behave on this map
	- `bounds` is the min and max location that the center of the storm can move to, it is pretty self explanitory
	- `starting_radius` is the radius that the storm will be when it first forms, this should reach outside of the map bounds idealy. (if left blank, the game will calculate it for you)
	- `spherical` Does not currently work. It will make the storm behave like a sphere instead of a cylinder
	- `starting_timer` is the base time (in seconds) of the storm timer. This timer will grow shorter as the round goes on
	- `timer_rate` For every this many seconds the round has gone on, the storm timer will get shorter by 1 second
	- `move_timer_multiply` During a "move" phase, the storm timer will be multiplied by this. Use it to make the storm move faster or slower,
	- `final_phase` After this many phases (counts both moving and waiting phases), the storm will try to close entirely if it has already shrunk to the minimum size
	- `minimum_shrink_amount` The storm will always shrink by this percentage of it's current radius per circle
	- `maximum_shrink_amount` The storm will never shirnk by more than this percentage of it's current radius per circle
	- `minimum_storm_size` The minimum size the storm can reach before closing entirely
	- `maximum_move_ratio` The storm will at most move by this % of the radius per phase
	- `minimum_move_amount` The storm will always move by at least this many hammer units
	- `damage` is a table of values. At each phase, listed, the damage will change to this value
- `event_blacklist` currently does nothing. It will be a list of event names to prevent from happening on this map.
- `create` a list of always create entities to spawn on map generation. These have a position, an angle, and can accept both `override_spawn_function` and `spawn_modifiers`
- `remove` is a list of entitiy map ids to be removed on map start. If you aren't sure how to get these, you can look at a map entity and type `lua_run_cl print(LocalPlayer():GetEyeTrace().Entity:MapCreationID())`
- `spawn_locations` is a list of locations for spawn groups. These can be a list of spawn groups with weights. You've seen this syntax before. Remeber **only one group will spawn**. The location also has an overall `spawn_chance`
- `lobby` details information about how the game should be setup during the lobby/intermission period between rounds
	- `pos`, `radius`, and `spherical` all describe how the storm should behave during lobby. This is how you can keep players in the lobby area, as the storm will do 25% of their health per second.
	- `spawns` is a list of spawn groups that will only spawn during lobby phase
	- `player_spawns` is a set of locations to change the default map spawns to. If this is not present, gRoyale will not alter the default spawn points
	- `player_damage` This defines what kind of damage players can take. `"none"` means no damage (except storm), `"nodie"` will keep the player at 25% health. `"instantheal"` will keep the player at 1% health and will cause them to heal for 100% health each tick. and `"full"` allows players to take full damage and die.

With all of this, you are ready to write you own gRoyale config
