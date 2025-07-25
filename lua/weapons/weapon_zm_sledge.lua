if SERVER then
	AddCSLuaFile()
end

SWEP.HoldType = "crossbow"

if CLIENT then
	SWEP.PrintName = "H.U.G.E-249"
	SWEP.Slot = 2

	SWEP.ViewModelFlip = false
	SWEP.ViewModelFOV = 54

	SWEP.Icon = "vgui/ttt/icon_m249"
	SWEP.IconLetter = "z"
end

SWEP.Base = "weapon_tttbase"

SWEP.Spawnable = true
SWEP.AutoSpawnable = true

SWEP.Kind = WEAPON_HEAVY
SWEP.WeaponID = AMMO_M249
SWEP.builtin = true
SWEP.spawnType = WEAPON_TYPE_HEAVY

SWEP.Primary.Damage = 10
SWEP.Primary.Delay = 0.05
SWEP.Primary.Cone = 0.066
SWEP.Primary.ClipSize = 150
SWEP.Primary.ClipMax = 150
SWEP.Primary.DefaultClip = 150
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "AirboatGun"
SWEP.Primary.Recoil = 2
SWEP.Primary.Sound = Sound("Weapon_m249.Single")

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/cstrike/c_mach_m249para.mdl"
SWEP.WorldModel = "models/weapons/w_mach_m249para.mdl"
SWEP.idleResetFix = true

SWEP.HeadshotMultiplier = 2.2
SWEP.DoorDamageMultiplier = 1.5

SWEP.IronSightsPos = Vector(-5.96, -5.119, 2.349)
SWEP.IronSightsAng = Vector(0, 0, 0)
