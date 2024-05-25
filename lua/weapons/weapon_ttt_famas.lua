AddCSLuaFile()

local BaseClass = baseclass.Get("weapon_tttbase")

if CLIENT then
    SWEP.PrintName = "FAMAS"
    SWEP.Slot = 2
    SWEP.Icon = "vgui/ttt/icon_famas"
    SWEP.IconLetter = "t"
else
    resource.AddFile("materials/vgui/ttt/icon_famas.vmt")
end

SWEP.Base = "weapon_tttbase"
SWEP.HoldType = "ar2"

SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Delay = 0.075
SWEP.Primary.Recoil = 0.8
SWEP.Primary.Cone = 0.02
SWEP.Primary.Damage = 19
SWEP.Primary.Automatic = true
SWEP.Primary.ClipSize = 30
SWEP.Primary.ClipMax = 60
SWEP.Primary.DefaultClip = 30
SWEP.Primary.Sound = Sound("Weapon_FAMAS.Single")
SWEP.Primary.BurstCount = 3
SWEP.Primary.BurstCooldown = 0.25

SWEP.UseHands = true
SWEP.ViewModelFlip = false
SWEP.ViewModelFOV = 64
SWEP.ViewModel = Model("models/weapons/cstrike/c_rif_famas.mdl")
SWEP.WorldModel = Model("models/weapons/w_rif_famas.mdl")

SWEP.IronSightsPos = Vector(-6.24, -2.757, 1.36)

SWEP.Kind = WEAPON_HEAVY
SWEP.AutoSpawnable = true
SWEP.AmmoEnt = "item_ammo_smg1_ttt"
SWEP.InLoadoutFor = {}
SWEP.AllowDrop = true
SWEP.IsSilent = false
SWEP.NoSights = false

SWEP.PrimaryAttack_Shoot = BaseClass.PrimaryAttack

function SWEP:SetupDataTables()
    self:NetworkVar("Float", "NextManualFire")
    self:NetworkVar("Int", "BurstsLeft")

    return BaseClass.SetupDataTables(self)
end

function SWEP:Initialize()
    self:SetBurstsLeft(0)
    self:SetNextManualFire(0)

    return BaseClass.Initialize(self)
end

function SWEP:Think()
    if self:GetBurstsLeft() > 0 then
        if self:CanPrimaryAttack() then
            if self:GetNextPrimaryFire() <= CurTime() then
                self:SetBurstsLeft(self:GetBurstsLeft() - 1)
                self:PrimaryAttack_Shoot()
            end
        else
            self:SetBurstsLeft(0)
            self:SetNextManualFire(CurTime() + 0.1)
        end
    end

    return BaseClass.Think(self)
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() or self:GetNextManualFire() > CurTime() then return end

    self:SetNextManualFire(CurTime() + self.Primary.Delay * self.Primary.BurstCount + self.Primary.BurstCooldown)
    self:SetBurstsLeft(self.Primary.BurstCount)
end
