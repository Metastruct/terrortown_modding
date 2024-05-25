-- NLL created by https://steamcommunity.com/profiles/76561198813867340

include("autorun/nl_library.lua")

if SERVER then
	AddCSLuaFile()
end

DEFINE_BASECLASS("weapon_zm_rifle")

if CLIENT then
	SWEP.PrintName = "Rifle (ZZZ)"
	SWEP.Slot = 6

	SWEP.ViewModelFlip = false
	SWEP.ViewModelFOV = 54
	
	SWEP.EquipMenuData = {
		type = "item_weapon",
		name = "Rifle (ZZZ)",
		desc = "A Non-Lethal Rifle.\n\nHeadshots take 3 seconds to sleep for 30 seconds.\n\nBodyshots take 10 seconds to sleep for 20 seconds."
	}
	
	SWEP.Icon = "vgui/ttt/icon_scout"
	SWEP.IconLetter = "n"
end

SWEP.Base = "weapon_zm_rifle"

SWEP.Kind = WEAPON_EQUIP
SWEP.WeaponID = AMMO_RIFLE
SWEP.CanBuy = { ROLE_DETECTIVE , ROLE_TRAITOR }

SWEP.Primary.NumShots = 0
SWEP.Primary.Sound = Sound("Weapon_USP.SilencedShot")

SWEP.AutoSpawnable = false
SWEP.Spawnable = false

SWEP.ViewModel = Model("models/weapons/nll/v_scout_zzz.mdl")
SWEP.WorldModel = Model("models/weapons/nll/w_scout_zzz.mdl")

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
					NLL.PlayerZZZ(ent,Vector(0,0,0),"ZZZ",3,30) -- tranquilizers don't care about swep's damage
					return
				end
				NLL.PlayerZZZ(ent,Vector(0,0,0),"ZZZ",10,15)
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