AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )

util.AddNetworkString("gbr.update_weapon_clip") -- This is a helper NWS that will help to sync the ammo count between client and server for when the ammo is extracted via interacting
util.AddNetworkString("gbr.sync_storm")
util.AddNetworkString("gbr.ply_requestsync")

-- Fix for Simfphys cars
hook.Add( "PlayerButtonUp", "simfphys_fixnumpads", function(ply, btn) numpad.Deactivate( ply, btn ) end)
hook.Add( "PlayerButtonDown", "simfphys_fixnumpads", function(ply, btn) numpad.Activate( ply, btn ) end)

CreateConVar("gbr_spawnweightprecision", "10", FCVAR_ARCHIVE, "The precision used when calculating spawn weights, this is really only nessecary if you are using decimal values. Higher numbers mean more required processing power")

net.Receive("gbr.ply_requestsync", function(_len, ply)
	GBRSyncStorm(ply)
end)

-- Higher precision will be more intensive
local function GetWeightedIndex( weights, precision ) -- Modified https://zliu.org/post/weighted-random/
	precision = precision or 10
	if(not istable(weights)) then return 1 end
	if (#weights == 0) then return 1 end
	local choices = {}
	for i,w in ipairs( weights) do
		local wi = w * precision
		for j=1,wi do
			choices[#choices+1] = i
		end
	end
	return choices[math.random(1, #choices)]
end

--[[
	Here are some predefined compatability functions for use with "override_spawn_function"
	These should all return entities, and should be global. Someone can easily add more just by defining those functions serverside
]]
function GBRSpawnSimfphys( classname, pos, angle ) -- Most of this is from the Simfphys source code simfphys.SpawnVehicle, but is has been modified to work with just a simple classname argument and avoid doing unnesssecary things

	if( not simfphys ) then
		MsgC(Color(181, 144, 51), "override_spawn_function > GBRSpawnSimfphys > ", Color(255, 100, 100), "Can't spawn a Simfphys vehicle, Simfphys is not installed!")
		return NULL
	end
	
	local VehicleList = list.Get( "simfphys_vehicles" )
	local vehicle = VehicleList[ classname ]

	if not vehicle then
		MsgC(Color(181, 144, 51), "override_spawn_function > GBRSpawnSimfphys > ", Color(255, 100, 100), "Cannot create a vehicle named ", classname, " because it is not a registed simfphys vehicle")
		return NULL
	end

	local ent = ents.Create( "gmod_sent_vehicle_fphysics_base" )
	if not ent then return NULL end
	ent:SetModel( vehicle.Model )
	ent:SetPos( pos + (vehicle.SpawnOffset or Vector(0,0,0)) )
	ent:SetAngles( angle + Angle( 0, (vehicle.SpawnAngleOffset and vehicle.SpawnAngleOffset or 0), 0) )
	ent:Spawn()
	ent:Activate()
	ent.VehicleName = classname
	ent.VehicleTable = vehicle
	ent:SetSpawn_List( classname )

	if( vehicle.Members ) then
		table.Merge( ent, vehicle.Members )

		-- Visual model stuffs
		if( ent.ModelInfo ) then
			if( ent.ModelInfo.Bodygroups ) then
				for i=1,table.Count(Ent.ModelInfo.Bodygroups) do
					ent:SetBodygroup(i, ent.ModelInfo.Bodygroups[i])
				end
			end

			if( ent.ModelInfo.Skin ) then
				ent:SetSkin( ent.ModelInfo.Skin )
			end

			if( ent.ModelInfo.Color ) then
				ent:SetColor( ent.ModelInfo.Color )
				
				local Color = ent.ModelInfo.Color
				local dot = Color.r * Color.g * Color.b * Color.a
				ent.OldColor = dot
				
				local data = {
					Color = Color,
					RenderMode = 0,
					RenderFX = 0
				}
				duplicator.StoreEntityModifier( ent, "colour", data )
			end
		end

		ent:SetTireSmokeColor(Vector(180,180,180) / 255)
		
		ent.Turbocharged = ent.Turbocharged or false
		ent.Supercharged = ent.Supercharged or false
		
		ent:SetEngineSoundPreset( ent.EngineSoundPreset )
		ent:SetMaxTorque( ent.PeakTorque )

		ent:SetDifferentialGear( ent.DifferentialGear )
		
		ent:SetSteerSpeed( ent.TurnSpeed )
		ent:SetFastSteerConeFadeSpeed( ent.SteeringFadeFastSpeed )
		ent:SetFastSteerAngle( ent.FastSteeringAngle )
		
		ent:SetEfficiency( ent.Efficiency )
		ent:SetMaxTraction( ent.MaxGrip )
		ent:SetTractionBias( ent.GripOffset / ent.MaxGrip )
		ent:SetPowerDistribution( ent.PowerBias )
		
		ent:SetBackFire( ent.Backfire or false )
		ent:SetDoNotStall( ent.DoNotStall or false )
		
		ent:SetIdleRPM( ent.IdleRPM )
		ent:SetLimitRPM( ent.LimitRPM )
		ent:SetRevlimiter( ent.Revlimiter or false )
		ent:SetPowerBandEnd( ent.PowerbandEnd )
		ent:SetPowerBandStart( ent.PowerbandStart )
		
		ent:SetTurboCharged( ent.Turbocharged )
		ent:SetSuperCharged( ent.Supercharged )
		ent:SetBrakePower( ent.BrakePower )
		
		ent:SetLights_List( ent.LightsTable or "no_lights" )
		
		ent:SetBulletProofTires( ent.BulletProofTires or false )
		
		ent:SetBackfireSound( ent.snd_backfire or "" )

		if not simfphys.WeaponSystemRegister then
			if simfphys.ManagedVehicles then
				print("[SIMFPHYS ARMED] IS OUT OF DATE")
			end
		else
			timer.Simple( 0.2, function()
				simfphys.WeaponSystemRegister( ent )
			end )
			
			if (simfphys.armedAutoRegister and not simfphys.armedAutoRegister()) or simfphys.RegisterEquipment then
				print("[SIMFPHYS ARMED]: ONE OF YOUR ADDITIONAL SIMFPHYS-ARMED PACKS IS CAUSING CONFLICTS!!!")
				print("[SIMFPHYS ARMED]: PRECAUTIONARY RESTORING FUNCTION:")
				print("[SIMFPHYS ARMED]: simfphys.FireHitScan")
				print("[SIMFPHYS ARMED]: simfphys.FirePhysProjectile")
				print("[SIMFPHYS ARMED]: simfphys.RegisterCrosshair")
				print("[SIMFPHYS ARMED]: simfphys.RegisterCamera")
				print("[SIMFPHYS ARMED]: simfphys.armedAutoRegister")
				print("[SIMFPHYS ARMED]: REMOVING FUNCTION:")
				print("[SIMFPHYS ARMED]: simfphys.RegisterEquipment")
				print("[SIMFPHYS ARMED]: CLEARING OUTDATED ''RegisterEquipment'' HOOK")
				print("[SIMFPHYS ARMED]: !!!FUNCTIONALITY IS NOT GUARANTEED!!!")
			
				simfphys.FireHitScan = function( data ) simfphys.FireBullet( data ) end
				simfphys.FirePhysProjectile = function( data ) simfphys.FirePhysBullet( data ) end
				simfphys.RegisterCrosshair = function( ent, data ) simfphys.xhairRegister( ent, data ) end
				simfphys.RegisterCamera = 
					function( ent, offset_firstperson, offset_thirdperson, bLocalAng, attachment )
						simfphys.CameraRegister( ent, offset_firstperson, offset_thirdperson, bLocalAng, attachment )
					end
				
				hook.Remove( "PlayerSpawnedVehicle","simfphys_armedvehicles" )
				simfphys.RegisterEquipment = nil
				simfphys.armedAutoRegister = function( vehicle ) simfphys.WeaponSystemRegister( vehicle ) return true end
			end
		end
		
		duplicator.StoreEntityModifier( ent, "VehicleMemDupe", vehicle.Members )

	end
	return ent
end
function GBRSpawnProp( modelname, pos, angle )
	local ent = ents.Create("prop_physics")
	if(not IsValid(ent)) then return NULL end
	ent:SetModel(modelname)
	ent:SetPos( pos )
	ent:SetAngles( angle )
	ent:Spawn()
end

local GBRSpawnModifiers = {
	RandomizedColor=function( ent, args )
		if( args[1] == "vehicleVibrant") then
			local colors = {
				{150, 27, 23}, -- Dark Red
				{255, 35, 28}, -- Bright Red
				{255, 107, 28}, -- Dukes of Hazzard Orange
				{191, 67, 0}, -- Orange
				{45, 87, 24}, -- Puke Green
				{24, 53, 87}, -- Dark Blueish
				{11, 24, 99}, -- Dark Blue
				{217, 217, 217}, -- White
				{138, 138, 138}, -- Gray
				{20, 20, 20} -- Black
			}
			local color = Color( unpack( colors[math.random(1, #colors)] ) )
			ent:SetColor( color )
			if( ent:IsSimfphyscar() ) then
				local data = {
					Color = color,
					RenderMode = 0,
					RenderFX = 0
				}
				duplicator.StoreEntityModifier( Ent, "colour", data )
			end
		elseif( args[1] == "vehicleDull") then
			local colors = {
				{87, 36, 36}, -- Maroon
				{82, 31, 41}, -- Ugly Dark Pink-Red
				{36, 38, 36}, -- Puke Orange
				{110, 55, 23}, -- Dark Greenish
				{55, 64, 53}, -- Greenish
				{36, 46, 56}, -- Faded Dark Blueish
				{24, 26, 36}, -- Dark Blue
				{171, 171, 171}, -- Light Gray
				{66, 66, 66}, -- Dark Gray
				{16, 16, 16} -- Black
			}
			local color = Color( unpack( colors[math.random(1, #colors)] ) )
			ent:SetColor( color )
			if( ent:IsSimfphyscar() ) then
				local data = {
					Color = color,
					RenderMode = 0,
					RenderFX = 0
				}
				duplicator.StoreEntityModifier( Ent, "colour", data )
			end
		else -- Default to full random
			ent:SetColor( Color(math.random(0, 255), math.random(0, 255), math.random(0, 255)) )
		end
	end,
	RandomizeBodygroups=function( ent, args )
		if(args[1] == "") then -- No body groups were specified, randomize them all
			for i=0,ent:GetNumBodyGroups()-1 do
				ent:SetBodygroup(i, math.random(0,ent:GetBodygroupCount(i)-1))
			end
		else
			for _,name in ipairs( args ) do -- For all of the listed bodygroups, ex: {"glasses","shoes","soul"}
				local bg = ent:FindBodygroupByName(name)
				if( bg ) then
					ent:SetBodygroup( bg, math.random(0,ent:GetBodygroupCount(bg)-1) ) -- Set this bodygroup to a random value
				end
			end
		end
	end
}

function GBRNewSpawnModifier( self, identifier, func )
	if(not isstring(identifier)) then
		MsgC( Color(25, 181, 49), "[gRoyale] ", Color(255, 100, 100), "Not adding '" .. identifier .. "' as a SpawnModifier, identifier must be a string")
		return
	end
	if(not isfunction(func)) then
		MsgC( Color(25, 181, 49), "[gRoyale] ", Color(255, 100, 100), "Not adding '" .. identifier .. "' as a SpawnModifier, 'func' is not a valid function")
		return
	end
	GBRSpawnModifiers[indentifier] = func
end
function GBRSetupMap( lobby ) -- Sets up the current map, should be called each round
	GM = GM or gmod.GetGamemode()
	if( not GBRSpawnEntity ) then
		MsgC( Color(255, 100, 100), "Server has not finished init phase or GBRSpawnEntity is missing" )
		return
	end
	game.CleanUpMap() -- Get rid of everything
	
	-- Then lets get an active preset, if there is one
	local setting = ""
	if( not file.Exists("garrys_royale/active_settings.txt", "DATA") ) then
		file.Write("garrys_royale/active_settings.txt", game.GetMap() .. "\tdefault.json")
		setting = "default.json"
	else
		local content = file.Read("garrys_royale/active_settings.txt") -- Read the settings file
		for _,line in ipairs( string.Split(content, "\n") ) do
			if( string.StartWith(line, game.GetMap() .. "\t")) then -- Find the line that starts with our map name
				setting = string.sub( line, string.len(game.GetMap()) + 2, string.len( line ) -1)
				if( not file.Exists("garrys_royale/map_settings/" .. game.GetMap() .. "/" .. setting, "DATA")) then
					MsgC(Color(181, 144, 51), "The set config, '" .. setting .. "', could not be found. Reverting to default.json\n")
					setting = "default.json"
				end
				break
			end
		end
		if( setting == "" ) then -- If we didn't find any setting for our map, we'll just use the default.json
			MsgC(Color(181, 144, 51), "No setting for " .. game.GetMap() .. ", reverting to default.json\n")
			setting = "default.json"
		end
	end

	-- Now make sure that preset exists
	if( not file.Exists("garrys_royale/map_settings/" .. game.GetMap() .. "/" .. setting, "DATA" ) ) then
		if( setting == "default.json" ) then
			chat.AddText(Color(255, 100, 100), "There is no valid default.json config for this map, and if a config file was given, it did not exist. The map will not have any features. Please go into sandbox and use the gRoyale Configurator tool to create a valid config")
			return
		end
	end

	-- Finally, we can do things with the settings
	local config = util.JSONToTable( file.Read("garrys_royale/map_settings/" .. game.GetMap() .. "/" .. setting, "DATA") )
	if( config == nil ) then
		chat.AddText(Color(255, 100, 100), "The config provided for this map \"" .. setting .. "\", was not a valid JSON file. If you did not use the configurator tool, there is a chance you made a mistake. The map will not be setup. You can type \"gbr_setmapconfig new_config.json\" in the console, followed by \"gbr_restart\" to try again")
		return
	end
	GM.Settings = config

	-- Setup spawn points
	if( istable(config.lobby.player_spawns) and #config.lobby.player_spawns > 0 ) then
		-- The player wants to override the spawns (as they probably should), delete the regular spawns
		for _,spawn in ipairs( ents.FindByClass("info_player_start") ) do
			spawn:Remove()
		end
		for _,location in ipairs( config.lobby.player_spawns ) do
			local spawn = ents.Create("info_player_start")
			spawn:SetPos(Vector( unpack(location.pos) ))
			spawn:SetAngles(Angle( unpack(location.angle) ))
			spawn:Spawn()
		end
	end

	for _,v in ipairs( config.create ) do -- Entities we should create. They can specify an override_spawn_function and spawn_modifiers
		v.pos = Vector( unpack(v.pos) )
		v.angle = Angle( unpack(v.angle) )
		local ent = NULL
		if( not v.override_spawn_function ) then
			ent = ents.Create( v.classname )
			if( not IsValid( ent ) ) then
				MsgC(Color(255, 100, 100), "Failed to spawn new entity at ", v.pos, ", but the entity may not be a valid one\n")
				continue
			end
			ent:SetPos( v.pos )
			ent:SetAngles(v.angle or Angle(0, 0, 0) )
			ent:Spawn()
		else
			if( not isfunction(_G[v.override_spawn_function])) then
				MsgC(Color(255, 100, 100), "Tried to spawn a new entity at ", v.pos, " but the spawn function was overriden to ", v.override_spawn_function, " which isn't a valid lua function in the global scope\n")
				return
			end
			ent = _G[v.override_spawn_function]( v.classname, v.pos, v.angle or Angle(0,0,0) )
		end
	end
	for _,id in ipairs( config.remove ) do -- These are IDs for map entities that we want to delete before the round starts
		local ent = ents.GetMapCreatedEntity( id )
		if( IsValid(ent) ) then
			ent:Remove()
		end
	end
	for _,v in ipairs( config.spawn_locations ) do
		-- First, see if we should even spawn
		if( math.random() <= v.spawn_chance ) then
			local weights = {}
			for _,l in ipairs( v.spawn_groups ) do
				weights[#weights+1] = l[2]
			end
			local group = v.spawn_groups[GetWeightedIndex( weights )][1]
			GBRSpawnEntity( group, Vector( unpack(v.pos) ), Angle( unpack( v.angle ) ) )
		end
	end

	-- Now we can setup the storm
end

-- Syncronize the server's view of the storm with all clients
function GBRSyncStorm( ply )
	net.Start("gbr.sync_storm")
	net.WriteTable(gmod.GetGamemode().Storm.meta)
	if( IsValid(ply) ) then
		if( ply:IsPlayer() ) then net.Send(ply) end
	else
		net.Broadcast()
	end
end

function GBRLoadActiveList()
	local name = GetConVar("gbr_activespawngroup"):GetString()
	if( not file.Exists("garrys_royale/spawn_lists/" .. name, "DATA") ) then
		MsgC( Color(255, 100, 100), "No spawn group found at %steamdir%/GarrysMod/garrysmod/data/garrys_royale/spawn_lists/" .. name )
	else
		local json_raw = file.Read("garrys_royale/spawn_lists/" .. name, "DATA")
		gmod.GetGamemode().SpawnGroups = util.JSONToTable(json_raw)
	end
end

-- Depreciated in favor of _G[name]()
-- GARRYS_ROYALE_OVERRIDE_SPAWN_FUNCTION_ENTITY = NULL -- This is a global variable we can access when interpreting and running the function 
function GBRSpawnEntity( spawn_list, pos )
	if(not isvector(pos)) then
		MsgC(Color(255, 100, 100), "Tried to spawn a new entity, but the provided position was not valid")
		return
	end
	-- Validate the current loaded list
	if( not istable(gmod.GetGamemode().SpawnGroups) ) then
		MsgC(Color(255, 100, 100), "Tried to spawn a new entity at ", pos, " but the currently loaded collection of SpawnGroups is not valid (not a table)")
		return
	end
	local groups = gmod.GetGamemode().SpawnGroups
	if( not groups[spawn_list] ) then
		MsgC(Color(255, 100, 100), "Tried to spawn a new entity at ", pos, " but the currently loaded collection of SpawnGroups does not have a spawn group named '" .. spawn_list .. "'")
		return
	end
	local class_name
	if( groups[spawn_list].rarities ) then
		-- Get all the weights
		local weights = {}
		for _, l in ipairs(groups[spawn_list].rarities) do
			weights[#weights+1] = l[2] -- Second item of the sublist is the weight
		end
		local weighted_index = GetWeightedIndex( weights )
		local rarity = groups[spawn_list].rarities[weighted_index][1]
		local valid_ents = {}
		for k,v in pairs(groups[spawn_list].items) do
			if( v.rarity == rarity ) then valid_ents[#valid_ents+1] = k end
		end
		if( #valid_ents == 0 ) then
			MsgC(Color(255, 100, 100), "Tried to spawn a new entity at ", pos, " but the spawn group ", spawn_list, " has the rarity ", rarity, " which goes unused!")
			return
		end
		class_name = valid_ents[math.random(1,#valid_ents)]

	else -- Assume equal rarity
		_, class_name = table.Random( groups[spawn_list].items )
	end

	local item = groups[spawn_list].items[class_name]
	-- Finally, spawn the item
	if( not item.override_spawn_function ) then
		ent = ents.Create( class_name )
		ent:SetPos( pos )
		ent:SetAngles( Angle(0,0,0) )
		ent:Spawn()
	else
		if( not isfunction(_G[item.override_spawn_function])) then
			MsgC(Color(255, 100, 100), "Tried to spawn a new entity at ", pos, " but the spawn function was overriden to ", item.override_spawn_function, " which isn't a valid lua function in the global scope")
			return
		end
		ent = _G[item.override_spawn_function]( class_name, pos, Angle(0,0,0) )
	end
	if( not IsValid(ent) ) then
		MsgC(Color(255, 100, 100), "Failed to spawn a new entity at ", pos, ". NULL Entity")
		return
	end
	if( istable(item.spawn_with) ) then -- Spawn the items that should come with the entity
		for _,v in ipairs( item.spawn_with ) do
			if( math.random() <= v[2] ) then
				local ent2 = ents.Create( v[1] )
				ent2:SetPos( pos )
				ent2:Spawn()
			end
		end
	end
	if( istable(item.spawn_modifiers) ) then
		for fname,fargs in pairs( item.spawn_modifiers ) do
			if( GM.SpawnModifiers[fname] ) then
				GM.SpawnModifiers[fname]( ent, string.Split(fargs, ',') )
			end
		end
	end
end

concommand.Add("gbr_reloadspawnlist", GBRLoadActiveList)

-- Check for the base data folder, and make it if it doesn't exist
if( not file.Exists("garrys_royale", "DATA") ) then
	file.CreateDir( "garrys_royale" )
end