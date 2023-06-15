ENT.Type = "anim"
ENT.Base = "base_entity"

ENT.PrintName = "Drop Pod"
ENT.Author = "Rad Poseidon"

ENT.Spawnable = false

function ENT:Drop()
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetCollisionGroup( COLLISION_GROUP_DEBRIS )

	if( IsValid(self:GetPhysicsObject() )) then
		self:GetPhysicsObject():Wake()
	end
end

ENT.AutomaticFrameAdvance = true
function ENT:Think()
	local ply = self:GetNWEntity("Player")

	-- Manage player
	if( IsValid( ply ) ) then
		if( not ply:Alive() ) then
			if( SERVER ) then
				self:ReleasePlayer()
			end
		else
			ply:SetPos( self:GetPos() )
			if( ply:GetMoveType() ~= MOVETYPE_NONE ) then
				ply:SetMoveType( MOVETYPE_NONE )
			end
			if( ply:IsFlagSet(FL_DUCKING) ) then
				ply:RemoveFlags( FL_DUCKING )
			end
		end
	end

	self:NextThink( CurTime() )
	return true
end