-- Server MetaTables for Garry's Royale

local _ply = FindMetaTable("Player")

_ply:GetWins()
	if(not self.wins) then self.wins = 0 end
	return self.wins
end
_ply:ResetWins()
	self.wins = 0
end
_ply:Win()
	self.wins = self.wins + 1
end

_ply:GetCash()
	if(not self.cash) then self.cash = 0 end
	return self.cash
end
_ply:SetCash( cash )
	if(not isnumber(cash)) then return end
	self.cash = cash
end