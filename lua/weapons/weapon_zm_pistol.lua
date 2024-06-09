if SERVER then
	AddCSLuaFile()
end

SWEP.HoldType = "revolver"

if CLIENT then
	SWEP.PrintName = "pistol_name"
	SWEP.Slot = 1

	SWEP.ViewModelFlip = false
	SWEP.ViewModelFOV = 54

	SWEP.Icon = "vgui/ttt/icon_pistol"
	SWEP.IconLetter = "u"
end

SWEP.Base = "weapon_tttbase"

SWEP.Kind = WEAPON_PISTOL
SWEP.WeaponID = AMMO_PISTOL
SWEP.builtin = true
SWEP.spawnType = WEAPON_TYPE_PISTOL

SWEP.Primary.Recoil = 1.5
SWEP.Primary.Damage = 25
SWEP.Primary.Delay = 0.38
SWEP.Primary.Cone = 0.02
SWEP.Primary.ClipSize = 20
SWEP.Primary.Automatic = true
SWEP.Primary.DefaultClip = 20
SWEP.Primary.ClipMax = 60
SWEP.Primary.Ammo = "Pistol"
SWEP.Primary.Sound = Sound("Weapon_P228.Single")

SWEP.AutoSpawnable = true
SWEP.AmmoEnt = "item_ammo_pistol_ttt"

SWEP.UseHands = true
SWEP.ViewModelFlip = false
SWEP.ViewModelFOV = 54
SWEP.ViewModel = Model("models/weapons/cstrike/c_pist_p228.mdl")
SWEP.WorldModel = Model("models/weapons/w_pist_p228.mdl")

SWEP.IronSightsPos = Vector(-5.961, -9.214, 2.839)
SWEP.IronSightsAng = Vector(0, 0, 0)
