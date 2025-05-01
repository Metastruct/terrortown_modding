local className = "weapon_ttt_dancenade"

if SERVER then
	AddCSLuaFile()
else
	SWEP.PrintName = "Dancenade"
	SWEP.Author = "Earu"
	SWEP.Slot = 3

	SWEP.ShowDefaultViewModel = false
	SWEP.ViewModelFlip = false
	SWEP.ViewModelFOV = 54
	SWEP.IconLetter = "h"

	SWEP.EquipMenuData = {
		type = "item_weapon",
		desc = "You're out of touch."
	}
end

SWEP.HoldType = "grenade"
SWEP.Base = "weapon_tttbasegrenade"
SWEP.ClassName = className
SWEP.UseHands = true
SWEP.Kind = WEAPON_NADE
SWEP.ViewModel = "models/weapons/cstrike/c_eq_flashbang.mdl"
SWEP.WorldModel = "models/weapons/w_eq_flashbang.mdl"
SWEP.Weight = 5

function SWEP:Initialize()
	-- Differentiate from rifle ammo
	self:SetColor(Color(255, 0, 0, 255))

	if BaseClass then
		return BaseClass.Initialize(self)
	end
end

function SWEP:GetGrenadeName()
	return "ttt_dancenade_proj"
end