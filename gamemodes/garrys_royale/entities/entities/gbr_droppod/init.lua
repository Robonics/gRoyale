AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:Initialize()

	self:SetModel("models/props_combine/eli_pod.mdl")
	-- self:PhysicsInit( SOLID_VPHYSICS )
	-- self:SetMoveType( MOVETYPE_VPHYSICS )
	-- self:SetSolid( SOLID_VPHYSICS )

	-- self:GetPhysicsObject():Wake()
end

function ENT:SetPlayer( ply )
	if(not IsValid(ply)) then
		ErrorNoHaltWithStack( "Expected Player got NULL or nil" )
		return
	end
	if(not ply:IsPlayer()) then
		ErrorNoHaltWithStack( "Expected player, got different Entity" )
		return 
	end
	self:SetNWEntity( "Player", ply ) -- Set which player we should keep track of
	-- This is Networked so that the player can correctly predict movement
	ply:SetMoveType( MOVETYPE_FLY )
	ply:SetCollisionGroup( COLLISION_GROUP_NONE )
end

function ENT:ReleasePlayer( vel )
	vel = vel or 200
	local ply = self:GetNWEntity("Player", NULL)
	if( not IsValid(ply) ) then return end

	ply:SetMoveType( MOVETYPE_WALK )
	ply:SetVelocity( self:GetAngles():Forward() * vel )
	ply:SetCollisionGroup( COLLISION_GROUP_PLAYER  )
	self:SetNWEntity("Player", NULL)
end
function ENT:OnRemove()
	self:ReleasePlayer()
end