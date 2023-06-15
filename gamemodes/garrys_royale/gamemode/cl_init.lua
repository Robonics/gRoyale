include( "shared.lua" )

net.Start("gbr.ply_requestsync")
net.SendToServer()

local show_weapon_info = CreateClientConVar("cl_gbr_showweaponinfo", "1", FCVAR_ARCHIVE, "A HUD Draw to show a readout of what's in a weapon")

-- Please note that the returned object is immutable
function GetStorm()
	return gmod.GetGamemode().Storm
end
net.Receive("gbr.sync_storm", function()
	local nmeta = net.ReadTable()
	gmod.GetGamemode().Storm.meta = nmeta
end)

local storm_opacity = 0.9
local storm_mat = Material("garrys_royale/storm")
local storm_wait = Material("garrys_royale/storm_waiting")
local storm_move = Material("garrys_royale/storm_moving")
local storm_matrix = Matrix()
local texture_matrix = Matrix()
surface.CreateFont("gRoyaleBasic", {
	font = "Arial",
	extended = false,
	size = 20,
	weight = 1000,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
})

function calculateSphereVertices(r)
    local circumference = 2 * math.pi * r
    local numVertices = math.floor(circumference / 2) -- Assuming each vertex represents a horizontal step

    return numVertices
end

function calculateSphereVertices(r)
    local circumference = 2 * math.pi * r
    local numVertices = math.floor(circumference / 2) -- Assuming each vertex represents a horizontal step

    return numVertices
end

local render_storm = true

local scale = 50
local x_rescale = 2
local storm_speed = 0.2
local storm_scale = Vector( 1, 1, 100 )
local mat_matrix = Matrix()

--[[
	#TODO: The storm looks very flat
	#TODO: Fog?
	#TODO: Screen effects
	#TODO: Outside of storm?
	#FIXME: Skybox issues
	#FIXME: Flickering of models and brushes when outside of storm
	#FIXME: When storm closes, it is still visible, disable rending when storm closes
		#TODO: Maybe also multiply VScale? Illusion becomes broken when storm gets smaller. Maybe make VScale increase as radius shrinks
]]
function GBRLegacyStormRender()
	if(not render_storm) then return end
	local storm = GetStorm()
	-- local res = math.Clamp(math.ceil(storm.meta.radius/512), 64, 256) #TODO: Come up with a reliable method for determining the res of the sphere

	cam.Start3D()

		render.SetLightingMode( 1 )

		storm_matrix:SetScale( storm_scale )
		-- #FIXME: Broken
		storm_matrix:SetTranslation( Vector() ) -- We have to change where we are rotating from
		storm_matrix:Rotate( Angle( 0, FrameTime() * 0.1, 0 ) ) -- Cause the storm to slowly rotate, the best way to do this is to actually rotate the sphere visually
		storm_matrix:SetTranslation( storm.meta.pos ) -- But we also need to move back after we're done
		cam.PushModelMatrix( storm_matrix )
		storm_mat:SetFloat( "$alpha", storm.meta.formed * storm_opacity )
		mat_matrix:SetScale( Vector( x_rescale * scale, storm_scale.z * scale ) )
		storm_mat:SetMatrix("$basetexturetransform", mat_matrix)
		storm_mat:SetVector("$detailscale", Vector(x_rescale * scale, storm_scale.z * scale))
		render.SetMaterial( storm_mat )
		render.DrawSphere(Vector(), storm.meta.radius, 256 , 50 )

		cam.PopModelMatrix()
		render.SetLightingMode( 0 )
	cam.End3D()
end

hook.Add( "PostDrawTranslucentRenderables", "gm_draw_storm", GBRLegacyStormRender)

hook.Add("PreDrawHUD", "gm_storm_effect", function()

	local storm = GetStorm()
	if( not storm:IsInStorm( LocalPlayer():GetPos() )) then return end
	
	cam.Start2D() -- If you don't call this the drawing will not work properly.

		surface.SetDrawColor( 255, 100, 255, 20 )
		surface.DrawRect( 0, 0, ScrW(), ScrH() )

	cam.End2D()
end)

local map_texture

-- @see https://steamcommunity.com/sharedfiles/filedetails/?id=452774754&searchtext=minimap
-- This NEEDS to work before players can drop in
	-- Unless maybe a drop-pod steering system is implemented
	-- Even still, this is pretty important for communicating the state of the storm
local function GenerateMap( x, y, w, h )

	local min, max = game.GetWorld():GetModelBounds()
	render_storm = false

	render.SuppressEngineLighting( true )

	render.RenderView({
		origin = Vector(0, 0, max.z * 0.8 ),
		angles = Angle(90, 0, 0),
		x = x, y = y,
		w = w, h = h,
		bloomtone = false,
		drawviewmodel = false,
		ortho={
			left = math.abs(min.x),
			right = max.x,
			top = max.y,
			bottom =  math.abs(min.y)
		}
	})

	render.SuppressEngineLighting( false )

	render_storm = true
end

hook.Add("HUDPaint", "gbr_storm_info", function()

	local storm = GetStorm()

	local size = 128
	local x = ScrW() - size - 5
	local y = 5

	surface.SetDrawColor( 45, 45, 45 )
	surface.DrawRect( x, y, size, size )

	local w = 90
	local h = 30
	x = ScrW() - w - 5
	y = y + size + 5
	padding = 2

	draw.RoundedBox(math.min(w, h)/4, x, y, w, h, Color(45, 45, 45, 255))
	if( storm.meta.should_shrink ) then
		surface.SetMaterial(storm_move)
	else
		surface.SetMaterial(storm_wait)
	end
	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawTexturedRect(x+padding, y+padding, math.min(w, h) - padding*2, math.min(w, h)-padding*2)

	draw.SimpleText( string.ToMinutesSeconds(storm.meta.timer/1000), "gRoyaleBasic", x + w - padding, y+h-padding, Color(255,255,255,255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
end)

hook.Add("HUDPaint", "gbr_weapon_info", function()

	local storm = GetStorm()
	if( LocalPlayer():GetPos():Distance( Vector(storm.meta.pos.x, storm.meta.pos.y, LocalPlayer():GetPos().z) ) > storm.meta.radius ) then
		draw.SimpleText("In the Storm " .. LocalPlayer():GetPos():Distance( Vector(storm.meta.pos.x, storm.meta.pos.y, LocalPlayer():GetPos().z) ) .. "hu", "DermaDefault", 0, 0, Color(255,50,50,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	if( not show_weapon_info:GetBool() ) then return end
	local ent = LocalPlayer():GetEyeTrace().Entity

	if( not IsValid(ent) ) then return end
	if( not ent:IsWeapon() ) then return end
	local dist = EyePos():Distance( ent:GetPos() )
	if( dist > 200 ) then return end

	local pos = (ent:GetPos() + Vector(0, 0, 10) + ent:OBBCenter()):ToScreen()

	surface.SetFont("DermaDefault")
	local w1 = surface.GetTextSize( ent:GetPrintName() )
	local w2 = 0
	if( ent:Clip1() ~= -1 ) then
		w2 = surface.GetTextSize( ent:Clip1() .. " /" .. ent:GetMaxClip1() .. " - " .. game.GetAmmoName( ent:GetPrimaryAmmoType() ) )
	end
	
	local w = math.max( w1 ) + 10
	local h = 50

	local alpha = 180
	if( dist > 150 ) then
		alpha = (1 - math.min( ( dist - 150) / 50, 1 )) * 180
	end

	draw.RoundedBox(0, pos.x - (w / 2), pos.y - h, w, h, Color(70, 70, 70, alpha))
	draw.SimpleText(ent:GetPrintName(), "DermaDefault", pos.x, pos.y - h + 5, Color(255,255,255,alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	if( ent:Clip1() ~= -1 ) then
		draw.SimpleText(ent:Clip1() .. " /" .. ent:GetMaxClip1() .. " - " .. game.GetAmmoName( ent:GetPrimaryAmmoType() ), "DermaDefault", pos.x, pos.y - h + 20, Color(255,255,255,alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end)

if( StormFox2 ) then
	hook.Add("Think", "gbr.sf2.weather_override", function()
		local storm = GetStorm()
		if( storm:IsInStorm( LocalPlayer():GetPos() ) ) then
			StormFox2.Weather.SetLocal("Rain", 1, 0, math.max(3, StormFox2.Temperature.Get()))
		else
			StormFox2.Weather.RemoveLocal()
		end
	end)
end

net.Receive("gbr.update_weapon_clip", function(_)
	local ent = net.ReadEntity()
	if( ent:Clip1() ~= -1 ) then
		ent:SetClip1( net.ReadInt(32) )
	end
	if( ent:Clip2() ~= -1 ) then
		ent:SetClip2( net.ReadInt(32) )
	end
end)