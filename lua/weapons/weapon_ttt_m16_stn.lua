-- NLL created by https://steamcommunity.com/profiles/76561198813867340

include("autorun/nl_library.lua")

if SERVER then
    AddCSLuaFile()
end

DEFINE_BASECLASS("weapon_tttbase")

SWEP.HoldType = "ar2"

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

SWEP.Base = "weapon_tttbase"

SWEP.Kind = WEAPON_EQUIP
SWEP.WeaponID = AMMO_M16
SWEP.CanBuy = { ROLE_DETECTIVE , ROLE_TRAITOR }
SWEP.LimitedStock = false
SWEP.builtin = true
SWEP.spawnType = WEAPON_TYPE_HEAVY

SWEP.Primary.Delay = 0.19
SWEP.Primary.Recoil = 0.8
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "Pistol"
SWEP.Primary.Damage = 2
SWEP.Primary.NumShots = 0
SWEP.Primary.Cone = 0.018
SWEP.Primary.ClipSize = 20
SWEP.Primary.ClipMax = 60
SWEP.Primary.DefaultClip = 20
SWEP.Primary.Sound = Sound("Weapon_M4A1.Single")

SWEP.AutoSpawnable = false
SWEP.Spawnable = false
SWEP.AmmoEnt = "item_ammo_pistol_ttt"

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/cstrike/c_rif_m4a1.mdl"
SWEP.WorldModel = "models/weapons/w_rif_m4a1.mdl"
SWEP.idleResetFix = true

SWEP.IronSightsPos = Vector(-7.58, -9.2, 0.55)
SWEP.IronSightsAng = Vector(2.599, -1.3, -3.6)

---
-- @ignore
function SWEP:SetZoom(state)
    local owner = self:GetOwner()

    if not IsValid(owner) or not owner:IsPlayer() then
        return
    end

    if state then
        owner:SetFOV(42, 0.5)
    else
        owner:SetFOV(0, 0.2)
    end
end

---
-- Add some zoom to ironsights for this gun
-- @ignore
function SWEP:SecondaryAttack()
    if not self.IronSightsPos or self:GetNextSecondaryFire() > CurTime() then
        return
    end

    local bIronsights = not self:GetIronsights()

    self:SetIronsights(bIronsights)
    self:SetZoom(bIronsights)

    self:SetNextSecondaryFire(CurTime() + 0.3)
end

---
-- @ignore
function SWEP:PrimaryAttack(worldsnd)

    if self:Clip1() == 0 then return end
    local bullet = {}
    bullet.Num = 1
    bullet.Src = self:GetOwner():GetShootPos()
    bullet.Dir = self:GetOwner():GetAimVector()
    bullet.Spread = Vector(0.036, 0.036, 0)
    bullet.Tracer = 4
    bullet.Force = 2
    bullet.Damage = 2
    bullet.Callback = function(att, tr, dmginfo)
        if SERVER then
            local ent = tr.Entity
            if (not tr.HitWorld) and IsValid(ent) and ent:IsPlayer() then
                if tr.HitGroup == 1 then
		    NLL.PlayerZZZ(ent,Vector(0,0,0),"STN",62,15)
		    return
                end
		NLL.PlayerZZZ(ent,Vector(0,0,0),"STN",23,10)
            end
        end
    end

    self:GetOwner():FireBullets(bullet)
    self:SetNextSecondaryFire(CurTime() + 0.1)
    BaseClass.PrimaryAttack(self, worldsnd)
end

---
-- @ignore
function SWEP:PreDrop()
    self:SetIronsights(false)
    self:SetZoom(false)

    return BaseClass.PreDrop(self)
end

---
-- @ignore
function SWEP:Reload()
    if
        self:Clip1() == self.Primary.ClipSize
        or self:GetOwner():GetAmmoCount(self.Primary.Ammo) <= 0
    then
        return
    end

    self:DefaultReload(ACT_VM_RELOAD)

    self:SetIronsights(false)
    self:SetZoom(false)
end

---
-- @ignore
function SWEP:Holster()
    self:SetIronsights(false)
    self:SetZoom(false)

    return true
end