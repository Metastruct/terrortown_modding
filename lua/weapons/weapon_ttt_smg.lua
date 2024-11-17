AddCSLuaFile()

if CLIENT then
    SWEP.PrintName = "MP7"
    SWEP.Slot = 2
    SWEP.Icon = "vgui/ttt/icon_smg"
    SWEP.IconLetter = "d"
else
    resource.AddFile("materials/vgui/ttt/icon_smg.vmt")
end

DEFINE_BASECLASS("weapon_tttbase")

SWEP.HoldType = "smg"

SWEP.Primary.Ammo = "Pistol"
SWEP.Primary.Delay = 0.075
SWEP.Primary.Recoil = 0.5
SWEP.Primary.Cone = 0.026
SWEP.Primary.Damage = 15
SWEP.Primary.Automatic = true
SWEP.Primary.ClipSize = 30
SWEP.Primary.ClipMax = 60
SWEP.Primary.DefaultClip = 30
SWEP.Primary.Sound = Sound("Weapon_SMG1.Single")

SWEP.UseHands = true
SWEP.ViewModelFlip = false
SWEP.ViewModelFOV = 56
SWEP.ViewModel = Model("models/weapons/c_smg1.mdl")
SWEP.WorldModel = Model("models/weapons/w_smg1.mdl")

SWEP.IronSightsPos = Vector(-6.39, -3.32, 1.05)

SWEP.Kind = WEAPON_HEAVY
SWEP.AutoSpawnable = true
SWEP.AmmoEnt = "item_ammo_pistol_ttt"
SWEP.InLoadoutFor = { nil }
SWEP.AllowDrop = true
SWEP.IsSilent = false
SWEP.NoSights = false

SWEP.HeadshotMultiplier = 2.4

-- Replace Reload to make a sound. The return statement at the top needs to be replicated.
function SWEP:Reload()
    if
        self:Clip1() == self.Primary.ClipSize
        or self:GetOwner():GetAmmoCount(self.Primary.Ammo) <= 0
    then
        return
    end

    BaseClass.Reload(self)

    self:EmitSound("Weapon_SMG1.Reload")
end
