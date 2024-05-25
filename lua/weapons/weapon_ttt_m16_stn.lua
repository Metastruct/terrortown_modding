-- NLL created by https://steamcommunity.com/profiles/76561198813867340

include("autorun/nl_library.lua")

if SERVER then
	AddCSLuaFile()
end

DEFINE_BASECLASS("weapon_ttt_m16")

if CLIENT then
	SWEP.PrintName = "M16 (STN)"
	SWEP.Slot = 6

	SWEP.ViewModelFlip = false
	SWEP.ViewModelFOV = 64

	SWEP.EquipMenuData = {
		type = "item_weapon",
		name = "M16 (STN)",
		desc = "A Non-Lethal M16.\n\nHeadshots deal 92 stun for 15 seconds.\n\nBodyshots deal 23 stun for 10 seconds."
	}

	SWEP.Icon = "vgui/ttt/icon_m16"
	SWEP.IconLetter = "w"
end

SWEP.Base = "weapon_ttt_m16"

SWEP.Kind = WEAPON_EQUIP
SWEP.WeaponID = AMMO_M16
SWEP.CanBuy = { ROLE_DETECTIVE , ROLE_TRAITOR }

SWEP.Primary.NumShots = 0
SWEP.Primary.Sound = Sound("Weapon_USP.SilencedShot")

SWEP.AutoSpawnable = false
SWEP.Spawnable = false

SWEP.ViewModel = "models/weapons/cstrike/c_rif_m4a1.mdl"
SWEP.WorldModel = "models/weapons/w_rif_m4a1.mdl"

---
-- @ignore
function SWEP:PrimaryAttack(worldsnd)
	if self:Clip1() == 0 then return end
	self.Primary.Recoil = BaseClass.Primary.Recoil/2 -- We redefine this every time the gun is fired otherwise it errors on initialization
	self.Primary.Cone = BaseClass.Primary.Cone*2
	local bullet = {}
	bullet.Num = 1
	bullet.Src = self:GetOwner():GetShootPos()
	bullet.Dir = self:GetOwner():GetAimVector()
	bullet.Spread = Vector(self.Primary.Cone, self.Primary.Cone, 0)
	bullet.Tracer = 4
	bullet.Force = 5
	bullet.Damage = self.Primary.Damage/10
	bullet.Callback = function(att, tr, dmginfo)
		if SERVER then
			local ent = tr.Entity
			if (not tr.HitWorld) and IsValid(ent) and ent:IsPlayer() then
				if tr.HitGroup == 1 then
					NLL.PlayerZZZ(ent,Vector(0,0,0),"STN",self.Primary.Damage*self.HeadshotMultiplier,15)
					return
				end
				NLL.PlayerZZZ(ent,Vector(0,0,0),"STN",self.Primary.Damage,10)
			end
		end
	end

	self:GetOwner():FireBullets(bullet)
	self:SetNextSecondaryFire(CurTime() + 0.1)
	local KeepDamage = self.Primary.Damage -- We're about to set the damage to 0, fire, then restore the damage, because for some reason I cannot NumShots = 0
	self.Primary.Damage = 0
	BaseClass.PrimaryAttack(self, worldsnd)
	self.Primary.Damage = KeepDamage
end