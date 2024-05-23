if SERVER then
	AddCSLuaFile()
	resource.AddFile("materials/vgui/ttt/icon_dartgun.vmt")
end

if CLIENT then
	SWEP.PrintName = "Dart Gun"

	SWEP.EquipMenuData = {
		type = "item_weapon",
		desc = "A dart gun. Fire it at players to track them for 90 seconds."
	}

	SWEP.Icon = "vgui/ttt/icon_dartgun"
end

DEFINE_BASECLASS("weapon_tttbase")
SWEP.ClassName = "weapon_ttt_dartgun"
SWEP.ShootSound = Sound("Metal.SawbladeStick")

-- This has to be manually set so ammo entities can see it
SWEP.AmmoEnt = 1
SWEP.ViewModel = "models/weapons/v_crossbow.mdl"
SWEP.WorldModel = "models/weapons/w_crossbow.mdl"
SWEP.Primary.ClipSize = 3
SWEP.Primary.DefaultClip = 3
SWEP.Primary.Automatic = false

SWEP.Kind = WEAPON_EQUIP
SWEP.CanBuy = {ROLE_DETECTIVE}
SWEP.LimitedStock = true

function SWEP:PrimaryAttack()
	if not self:HasAmmo() then return end
	if not self:CanPrimaryAttack() then return end

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	self:EmitSound(self.ShootSound)

	if SERVER then
		local tr = owner:GetEyeTrace()
		if IsValid(tr.Entity) and tr.Entity:IsPlayer() then
			tr.Entity:SetNWBool("TTTDartGunTracked", true)
			local timer_name = ("dartgun_tracking_[%s]"):format(tr.Entity:SteamID())
			timer.Create(timer_name, 90, 1, function()
				tr.Entity:SetNWBool("TTTDartGunTracked", false)
			end)

			self:TakePrimaryAmmo(1)
		end
	end

	self:SetNextPrimaryFire(CurTime() + 2)
end

if SERVER then
	hook.Add("PlayerDeath", "weapon_ttt_dartgun", function(ply)
		ply:SetNWBool("TTTDartGunTracked", false)
	end)
end

if CLIENT then
	surface.CreateFont("weapon_ttt_dartgun", {
		font = "Arial",
		size = 18,
		extended = true,
		weight = 1000,
		outline = true
	})

	local WARN_COLOR = Color(255, 200, 0, 255)
	local OFFSET = Vector(0, 0, 10)
	hook.Add("HUDPaint", "weapon_ttt_dartgun", function()
		for _, ply in ipairs(player.GetAll()) do
			if not ply:GetNWBool("TTTDartGunTracked", false) then continue end
			if ply == LocalPlayer() then continue end
			if not ply:Alive() then continue end

			cam.Start3D(EyePos(), EyeAngles())
			cam.IgnoreZ(true)
			render.SuppressEngineLighting(true)

			if pac then
				pac.ForceRendering(true)
				pac.ShowEntityParts(ply)
				pac.RenderOverride(ply, "opaque")
			end

			ply:DrawModel()

			local wep = ply:GetActiveWeapon()
			if IsValid(wep) then
				wep:DrawModel()
			end

			if pac then
				pac.ForceRendering(false)
			end

			render.SuppressEngineLighting(false)
			cam.IgnoreZ(false)
			cam.End3D()

			surface.SetTextColor(WARN_COLOR)
			surface.SetFont("weapon_ttt_dartgun")

			local text = "[TRACKED]"
			local tw, _ = surface.GetTextSize(text)
			local pos = (ply:GetPos() - OFFSET):ToScreen()

			surface.SetTextPos(pos.x - tw / 2, pos.y)
			surface.DrawText(text)
		end
	end)

	hook.Add("PreDrawHalos", "weapon_ttt_dartgun", function()
		local tracked_players = {}
		for _, ply in ipairs(player.GetAll()) do
			if not ply:GetNWBool("TTTDartGunTracked", false) then continue end
			if ply == LocalPlayer() then continue end
			if not ply:Alive() then continue end

			table.insert(tracked_players, ply)
		end

		halo.Add(tracked_players, WARN_COLOR, 0, 0, 2, true, true)
	end)
end