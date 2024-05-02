if SERVER then
	AddCSLuaFile()
	resource.AddFile("materials/vgui/ttt/icon_gay_brick.vmt")
end

DEFINE_BASECLASS("weapon_ttt_brick")

SWEP.Kind = WEAPON_EQUIP
SWEP.CanBuy = { ROLE_TRAITOR }
SWEP.LimitedStock = true
SWEP.AutoSpawnable = false

if CLIENT then
	SWEP.PrintName = "Gay Brick"

	SWEP.EquipMenuData = {
		name = "Gay Brick",
		desc = "A brick imbued with the power of the rainbow!",
		type = "item_weapon"
	}

	SWEP.Icon = "vgui/ttt/icon_gay_brick"
end

if SERVER then
	function SWEP:CreateGrenade(src, ang, vel, angimp, pl)
		local gren = ents.Create("ttt_brick_proj")

		if not IsValid(gren) then return end

		gren:SetPos(src)
		gren:SetAngles(ang)
		gren:SetSkin(self:GetSkin())
		gren:SetOwner(pl)
		gren:SetThrower(pl)
		gren:SetElasticity(0.15)

		gren.damageScaling = self.damageScaling

		gren:Spawn()
		gren:PhysWake()

		local gren_phys = gren:GetPhysicsObject()
		if IsValid(gren_phys) then
			gren_phys:SetVelocity(vel)
			gren_phys:AddAngleVelocity(angimp)
		end

		-- Clear the owner after a short delay so it can collide with them again
		timer.Simple(0.2, function()
			if IsValid(gren) then
				gren:SetOwner(NULL)
			end
		end)

		function gren:PhysicsUpdate(phys)
			if phys:GetVelocity():LengthSqr() < 4 then
				timer.Simple(0, function()
					if not IsValid(self) then return end

					local brick = ents.Create("ttt_gay_brick")
					brick:SetPos(self:GetPos() + Vector(0, 0, 5))
					brick:SetAngles(self:GetAngles())
					brick:Spawn()
					brick:PhysWake()
					brick.Owner = pl

					self:Remove()
				end)
			end
		end

		return gren
	end
end