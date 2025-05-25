if SERVER then
    AddCSLuaFile()

    resource.AddSingleFile("materials/vgui/ttt/icon_lobotomygrenade.png")
else
    SWEP.PrintName = "Lobotomy Grenade"
    SWEP.Author = "TW1STaL1CKY"
    SWEP.Slot = 3

    SWEP.ViewModelFlip = false
    SWEP.ViewModelFOV = 54

    SWEP.Icon = "vgui/ttt/icon_lobotomygrenade.png"
    SWEP.IconLetter = "h"
end

DEFINE_BASECLASS("weapon_tttbasegrenade")

SWEP.Kind = WEAPON_NADE
SWEP.CanBuy = { ROLE_TRAITOR }

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/cstrike/c_eq_flashbang.mdl"
SWEP.WorldModel = "models/weapons/w_eq_flashbang.mdl"

function SWEP:Initialize()
    self:SetColor(Color(175, 225, 255))

    return BaseClass.Initialize(self)
end

function SWEP:GetGrenadeName()
    return "ttt_lobotomygrenade_proj"
end