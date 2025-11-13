AddCSLuaFile()

if CLIENT then
	SWEP.PrintName = "Silenced M4A1"
	SWEP.Slot = 6

	SWEP.ViewModelFlip = false
	SWEP.ViewModelFOV = 64

	SWEP.Icon = "vgui/ttt/icon_m16"
	SWEP.IconLetter = "w"

	SWEP.EquipMenuData = {
		type = "item_weapon",
		desc = "A modified M4A1 carbine with a suppressor.\n\nVictims will not scream when killed."
	}
end

DEFINE_BASECLASS("weapon_tttbase")

SWEP.HoldType = "ar2"

SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Delay = 0.12
SWEP.Primary.Recoil = 1.2
SWEP.Primary.Cone = 0.018
SWEP.Primary.Damage = 18
SWEP.Primary.Automatic = true
SWEP.Primary.ClipSize = 30
SWEP.Primary.ClipMax = 60
SWEP.Primary.DefaultClip = 30
SWEP.Primary.Sound = ")weapons/m4a1/m4a1-1.wav"
SWEP.Primary.SoundLevel = 65

SWEP.HeadshotMultiplier = 2.4

SWEP.UseHands = true
SWEP.ViewModel = Model("models/weapons/cstrike/c_rif_m4a1.mdl")
SWEP.WorldModel = Model("models/weapons/w_rif_m4a1_silencer.mdl")
SWEP.idleResetFix = true

SWEP.IronSightsPos = Vector(-7.58, -9.2, 0.55)
SWEP.IronSightsAng = Vector(2.599, -1.3, -3.6)

SWEP.Kind = WEAPON_EQUIP1
SWEP.CanBuy = { ROLE_TRAITOR }
SWEP.AmmoEnt = "item_ammo_smg1_ttt"
SWEP.LimitedStock = true
SWEP.AllowDrop = true

SWEP.IsSilent = true

SWEP.PrimaryAnim = ACT_VM_PRIMARYATTACK_SILENCED
SWEP.ReloadAnim = ACT_VM_RELOAD_SILENCED
SWEP.IdleAnim = ACT_VM_IDLE_SILENCED

function SWEP:Deploy()
	self:SendWeaponAnim(ACT_VM_DRAW_SILENCED)

	return self.BaseClass.Deploy(self)
end