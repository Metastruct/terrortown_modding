if SERVER then
    AddCSLuaFile()
    resource.AddFile("materials/vgui/ttt/icon_laggrenade.vmt")
else
    SWEP.PrintName = "ttt_laggrenade_name"
    SWEP.Author = "Lixquid"
    SWEP.Slot = 3

    SWEP.ViewModelFlip = false
    SWEP.ViewModelFOV = 54

    SWEP.Icon = "vgui/ttt/icon_laggrenade"
    SWEP.IconLetter = "h"

    LANG.AddToLanguage("en", "ttt_laggrenade_name", "Lag Grenade")

    LANG.AddToLanguage("en", "ttt_laggrenade_radius_name", "Effect Radius")
    LANG.AddToLanguage("en", "ttt_laggrenade_radius_help", "The radius a lag grenade affects, in units.")
    LANG.AddToLanguage("en", "ttt_laggrenade_duration_name", "Effect Duration")
    LANG.AddToLanguage("en", "ttt_laggrenade_duration_help", "The duration a lag grenade applies for, in seconds.")
    LANG.AddToLanguage("en", "ttt_laggrenade_fps_name", "FPS Limit")
    LANG.AddToLanguage("en", "ttt_laggrenade_fps_help",
        "The FPS player within the radius of an active lag grenade will be limited to.")
end

SWEP.HoldType = "grenade"

SWEP.Base = "weapon_tttbasegrenade"

SWEP.Kind = WEAPON_NADE
SWEP.spawnType = WEAPON_TYPE_NADE

SWEP.Spawnable = true
SWEP.AutoSpawnable = true

SWEP.UseHands = true
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
    return "ttt_laggrenade_proj"
end

if CLIENT then
    function SWEP:AddToSettingsMenu(parent)
        local form = vgui.CreateTTT2Form(parent, "header_equipment_additional")

        form:MakeHelp({
            label = "ttt_laggrenade_radius_help"
        })
        form:MakeSlider({
            serverConvar = "ttt_laggrenade_radius",
            label = "ttt_laggrenade_radius_name",
            min = 0,
            max = 1000,
            decimal = 0
        })
        form:MakeHelp({
            label = "ttt_laggrenade_duration_help"
        })
        form:MakeSlider({
            serverConvar = "ttt_laggrenade_duration",
            label = "ttt_laggrenade_duration_name",
            min = 0,
            max = 60,
            decimal = 0
        })
        form:MakeHelp({
            label = "ttt_laggrenade_fps_help"
        })
        form:MakeSlider({
            serverConvar = "ttt_laggrenade_fps",
            label = "ttt_laggrenade_fps_name",
            min = 1,
            max = 30,
            decimal = 1
        })
    end
end
