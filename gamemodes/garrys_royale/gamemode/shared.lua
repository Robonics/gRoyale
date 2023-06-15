CreateConVar( "gbr_activespawngroup", "default.json", FCVAR_ARCHIVE, "The spawn group list to use" )
CreateConVar( "gbr_noallowduplicates", "1", FCVAR_ARCHIVE, "If 1, will prevent the player from picking up weapons they already have and will instead simply strip the weapon of it's ammo" )

GM.Name = "Garry's Royale"
GM.Author = "Rad Poseidon"
GM.Email = "N/A"
GM.Website = "N/A"

DEFINE_BASECLASS( "player_default" ) -- We load this in shared because there is only one

local PLAYER = {} 

--
-- See gamemodes/base/player_class/player_default.lua for all overridable variables
--
PLAYER.WalkSpeed = 200
PLAYER.RunSpeed  = 400

function PLAYER:Loadout()
	self.Player:RemoveAllAmmo()
	for _, class in ipairs( self.Player.last_weps ) do
		self.Player:Give( class )
	end
end
function PLAYER:Death()
	self.Player.last_weps = {}
	for i, wep in ipairs( self.Player:GetWeapons() ) do
		self.Player.last_weps[i] = wep:GetClass()
	end
end

player_manager.RegisterClass( "player_gbr_base", PLAYER, "player_default" )

function GM:PlayerSpawn( ply )
	self.BaseClass.PlayerSpawn( self, ply )
	player_manager.SetPlayerClass(ply, "player_gbr_base")
end

function GM:PlayerSetModel( ply )
	if( SERVER ) then
		ply:SetModel( player_manager.TranslatePlayerModel( ply:GetInfo( "cl_playermodel" ) ) )
	end
end

function GM:LoadAvailableLists()
	self.SpawnGroupLists = file.Find("garrys_royale/spawn_groups/*.json", "DATA")
end
function GM:Initialize()
	self:LoadAvailableLists()
end

function GM:PlayerCanPickupWeapon( ply, wep )
	if( ply:HasWeapon( wep:GetClass() ) and GetConVar("gbr_noallowduplicates"):GetBool() ) then
		return false
	else
		return self.BaseClass.PlayerCanPickupWeapon( self, ply, wep )
	end
end

-- #TODO: Needs refinement
function GM:PlayerUse(ply, wep)
	if( ply:HasWeapon( wep:GetClass() ) and GetConVar("gbr_noallowduplicates"):GetBool() and wep:IsWeapon() ) then
		local ammo1
		local ammo2
		if( wep:GetPrimaryAmmoType() ~= -1 and wep:Clip1() > 0 ) then -- It has ammo to take
			ammo1 = math.min( wep:Clip1(), math.max( game.GetAmmoMax( wep:GetPrimaryAmmoType() ), GetConVar("gmod_maxammo"):GetInt() ) - ply:GetAmmoCount( wep:GetPrimaryAmmoType() ) )
			ply:GiveAmmo( ammo1, wep:GetPrimaryAmmoType() )
			wep:SetClip1( wep:Clip1() - ammo1 )
		end
		if( wep:GetSecondaryAmmoType() ~= -1 and wep:Clip2() > 0 ) then -- It has ammo to take
			ammo2 = math.min( wep:Clip2(), math.max( game.GetAmmoMax( wep:GetSecondaryAmmoType() ), GetConVar("gmod_maxammo"):GetInt() ) - ply:GetAmmoCount( wep:GetSecondaryAmmoType() ) )
			ply:GiveAmmo( ammo2, wep:GetSecondaryAmmoType() )
			wep:SetClip2( wep:Clip2() - ammo2 )
		end
		if( (ammo1 ~= 0 and ammo1 ~= nil) or (ammo2 ~= 0 and ammo2 ~= nil) ) then
			EmitSound( "items/ammo_pickup.wav", wep:GetPos(), wep:EntIndex() )
			net.Start("gbr.update_weapon_clip") -- Tell all the clients that this entity has changed
			net.WriteEntity(wep)
			if( wep:Clip1() ~= -1 ) then
				net.WriteInt(wep:Clip1(), 32)
			end
			if( wep:Clip2() ~= -1 ) then
				net.WriteInt(wep:Clip2(), 32)
			end
			net.Broadcast()
		end
		return false
	else
		return self.BaseClass.PlayerUse( self, ply, wep )
	end
end
GM.Settings = {}
GM.GameActive = false -- Is the game active? Default to false. True means the round is in progress, false means it is lobby time
GM.Storm = { --TODO: Use metatables instead of .meta attribute
	meta={
		pos = Vector(0, 0, 0), -- This is the pos for the center of the storm, the z coord is ignored unless sphere mode is enabled
		sphere_mode = false, -- This will turn the storm from a cylinder into a sphere, good for crowded maps but can be confusing
		radius = 20000, -- The radius (in HU) of the storm from the center
		damage = 2, -- This is the damage to do per tick while in the storm
		should_shrink = false, -- This controls if the storm is shrinking or waiting
		timer = 120000, -- This is the time before should_shrink will invert itself (in ms)
		timer_started_at=120000, -- This is the time the timer started at

		last_pos=Vector(0, 0, 0),
		nex_pos = Vector(0, 0, 0), -- This is the next position that the storm will try to go to
		last_radius=100000,
		next_radius = 1000, -- This is the next radius the storm will shrink to

		valid_bounds = { -- This is the valid map bounds, the storm will never set it's pos outside of this. Use gbr_storm_padding to prevent the storm from getting too close to this edge
			min = Vector(0, 0, 0),
			max = Vector(0, 0, 0)
		},
		phase=0, -- This is how many cycles the storm has gone through. This counts shrinking and waiting phases seperately
		started=CurTime(),
		formed=0.0, -- % formed, will be used to Lerp Alpha
		paused=false -- Should the storm think, should be true during intermission/lobby time
	}
}
function GM.Storm:MaxRadius() -- Calculates the smallest radius that will so that both bounds will be tanget or inside the circle
	return math.max( self.meta.pos:Distance( self.meta.valid_bounds.min ), self.meta.pos:Distance( self.meta.valid_bounds.max ) )
end
function GM.Storm:IsInStorm( vec )
	if( self.meta.sphere_mode ) then
		return self.meta.pos:Distance( vec ) > self.meta.radius
	else
		return math.sqrt( math.pow( self.meta.pos.x - vec.x, 2 ) + math.pow( self.meta.pos.y - vec.y, 2) ) > self.meta.radius
	end
end
function GM.Storm:DoTick()
	if( self.meta.should_shrink ) then
		-- Calculate what our radius should be this frame
		self.meta.radius = self.meta.next_radius + (self.meta.last_radius - self.meta.next_radius) * (self.meta.timer / self.meta.timer_started_at)
		self.meta.pos = self.meta.next_pos + (self.meta.last_pos - self.meta.next_pos) * (self.meta.timer / self.meta.timer_started_at)
	elseif( self.meta.phase == 0 ) then
		self.meta.formed = 1 - self.meta.timer / self.meta.timer_started_at -- Form over the course of the timer
	end
	self.meta.timer = math.max(self.meta.timer - FrameTime()*1000, 0)
	if( self.meta.timer <= 0 ) then
		self.meta.should_shrink = not self.meta.should_shrink
		self.meta.timer = math.max(150000 - (CurTime() - self.meta.started)/5*1000, 20000) -- For every 15 seconds since this match started, 1 less second passes for the timer, minumum of 25 seconds
		self.meta.timer_started_at=self.meta.timer
		self.meta.last_radius = self.meta.radius
		self.meta.last_pos = self.meta.pos
		self.meta.phase = self.meta.phase + 1

		-- Generate new parameters for the next circle
		
		if( CLIENT ) then --#TODO: Fix bug where sound will not always play on client, this is because the client can lag slightly behind.
			-- Make should shrink not change client side? Then could test in net.Recieve("gbr.sync_storm") to see if it changed. Also maybe pick a less harsh sound
			surface.PlaySound("garrys_royale/storm_phase_over.wav")
		end
		if( SERVER ) then
			self.meta.next_radius = math.max(math.random( self.meta.radius/3, self.meta.radius-self.meta.radius/3 ), 700) -- Random value between 1/3 and 2/3 of our current, min of 700hu
			if( self.meta.radius <= 701 and self.meta.phase >= 10) then
				self.meta.next_radius = 0
				self.meta.timer = 10000
				if( self.meta.radius <= 1 ) then
					self.meta.timer = 3600000 -- 1 hour
					-- #TODO: Make it pause storm instead, make client render a custom symbol for paused storm and a custom timer icon, storm should stop ticking all together when it closes
					-- #FIXME: Closing phase is too fast and also causes the circle to snap
				end
			end
			if( self.meta.sphere_mode ) then
				local theta = Angle():Random() -- This will give us a way to create a simple normalized vector on a unit sphere
				local magnitude = math.random(0, math.max(self.meta.radius/4, 700)) -- Only move 1/4 of the circle in sphere mode
				self.meta.next_pos = self.meta.pos + theta:Forward()*magnitude
			else
				local theta = math.random(0, 2*math.pi)
				local magnitude = math.random(0, math.max(self.meta.radius/2, 700)) -- we never move more than half a circle, will always have the chance to move at least 700hu
				self.meta.next_pos = self.meta.pos + Vector( math.cos(theta)*magnitude, math.sin(theta)*magnitude )
				self.meta.next_pos.x = math.Clamp( self.meta.next_pos.x, self.meta.valid_bounds.min.x, self.meta.valid_bounds.max.x )
				self.meta.next_pos.y = math.Clamp( self.meta.next_pos.y, self.meta.valid_bounds.min.y, self.meta.valid_bounds.max.y )
				self.meta.next_pos.z = math.Clamp( self.meta.next_pos.z, self.meta.valid_bounds.min.z, self.meta.valid_bounds.max.z )
				-- We generate a random angle and distance from our current point to move from, this ensures our new point will stay within half of our existing circle
			end
			GBRSyncStorm() -- Sync the storm when should_shrink flips. While all of this should be predicted, this will sync every circle
		end
	end
end

hook.Add("Think", "gm_storm_think", function()
	local GM = gmod.GetGamemode() or GM
	if( not GM.Storm.meta.paused ) then
		GM.Storm:DoTick()
	end
end)

hook.Add("Think", "gm_dmg_ply_storm", function()
	local GM = gmod.GetGamemode() or GM
	if(SERVER) then
		for _, v in ipairs( player.GetAll() ) do
			if( GM.Storm:IsInStorm( v:GetPos() ) and not timer.Exists( v:SteamID() .. "_storm_dmg" ) ) then
				timer.Create( v:SteamID() .. "_storm_dmg", 1.0, 0, function()
					local dmg = DamageInfo()
					dmg:SetDamage( GM.Storm.meta.damage )
					dmg:SetDamageType( DMG_SHOCK )
					dmg:SetAttacker( game.GetWorld() )
					dmg:SetInflictor( game.GetWorld() )
					v:TakeDamageInfo( dmg )
				end)
			elseif( not GM.Storm:IsInStorm( v:GetPos() ) and timer.Exists( v:SteamID() .. "_storm_dmg" )) then
				timer.Remove(  v:SteamID() .. "_storm_dmg"  )
			end
		end
	else
		if( GM.Storm:IsInStorm( LocalPlayer():GetPos() ) and not timer.Exists( "gbr.storm_tick_sound" ) ) then
				timer.Create( "gbr.storm_tick_sound", 1.0, 0, function()
					surface.PlaySound("common/wpn_moveselect.wav")
				end)
			elseif( not GM.Storm:IsInStorm( LocalPlayer():GetPos() ) and timer.Exists( "gbr.storm_tick_sound" )) then
				timer.Remove(  "gbr.storm_tick_sound"  )
		end
	end
end)