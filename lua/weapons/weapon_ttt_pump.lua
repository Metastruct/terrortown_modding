if SERVER then
	AddCSLuaFile()
end

-- Derive from the built-in shotgun since how it works should be exactly the same
-- If you want to make this shotgun work differently from the built-in one, change this back to weapon_tttbase
DEFINE_BASECLASS("weapon_zm_shotgun")

if CLIENT then
    SWEP.PrintName = "Pump Shotgun"
    SWEP.Slot = 2

    SWEP.ViewModelFlip = false
    SWEP.ViewModelFOV = 58

    SWEP.Icon = "vgui/ttt/icon_pump"
    SWEP.IconLetter = "k"
else
    resource.AddFile("materials/vgui/ttt/icon_pump.vmt")
end

SWEP.HoldType = "shotgun"

SWEP.Kind = WEAPON_HEAVY
SWEP.spawnType = WEAPON_TYPE_SHOTGUN

SWEP.Primary.Ammo = "Buckshot"
SWEP.Primary.Damage = 11
SWEP.Primary.Cone = 0.08
SWEP.Primary.Delay = 1.2
SWEP.Primary.ClipSize = 8
SWEP.Primary.ClipMax = 24
SWEP.Primary.DefaultClip = 8
SWEP.Primary.Automatic = true
SWEP.Primary.NumShots = 9
SWEP.Primary.Sound = Sound("Weapon_M3.Single")
SWEP.Primary.Recoil = 6.8

SWEP.AutoSpawnable = true
SWEP.AmmoEnt = "item_box_buckshot_ttt"

SWEP.UseHands = true
SWEP.ViewModel = Model("models/weapons/cstrike/c_shot_m3super90.mdl")
SWEP.WorldModel = Model("models/weapons/w_shot_m3super90.mdl")
SWEP.idleResetFix = true

SWEP.IronSightsPos = Vector(-7.67, -12.86, 3.371)
SWEP.IronSightsAng = Vector(0.637, 0.01, -1.458)