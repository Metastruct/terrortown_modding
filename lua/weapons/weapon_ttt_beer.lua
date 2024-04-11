if SERVER then
    AddCSLuaFile()
    resource.AddFile("materials/vgui/ttt/icon_beer.vmt")
end

--#region CVars

local cvarDrunkenness = CreateConVar("ttt_beer_drunkenness", 75, { FCVAR_ARCHIVE, FCVAR_NOTIFY })
local cvarDamageReduction = CreateConVar("ttt_beer_damagereduction", 10, { FCVAR_ARCHIVE, FCVAR_NOTIFY })
local cvarInitialCount = CreateConVar("ttt_beer_initialcount", 6, { FCVAR_ARCHIVE, FCVAR_NOTIFY })

--#endregion

DEFINE_BASECLASS("weapon_tttbase")
SWEP.Base = "weapon_tttbase"

if CLIENT then
    SWEP.PrintName = "ttt_beer_name"
    SWEP.Author = "Lixquid"
    SWEP.Slot = 6

    SWEP.ViewModelFlip = false
    SWEP.ViewModelFOV = 54
    SWEP.UseHands = true

    SWEP.EquipMenuData = {
        type = "item_weapon",
        desc = "ttt_beer_desc"
    }

    SWEP.Icon = "vgui/ttt/icon_beer"
    SWEP.IconLetter = "h"

    LANG.AddToLanguage("en", "ttt_beer_name", "Beer")
    LANG.AddToLanguage("en", "ttt_beer_desc",
        "Drink to increase drunkenness, which reduces damage taken.\n" ..
        "Buying a pack gives you multiple beers, to be shared with friends... "
        .. "or slammed all at once.")

    LANG.AddToLanguage("en", "ttt_beer_drunkenness_name", "Drunkenness")
    LANG.AddToLanguage("en", "ttt_beer_drunkenness_help", "The additional drunkenness level a beer applies.")
    LANG.AddToLanguage("en", "ttt_beer_damagereduction_name", "Damage Reduction")
    LANG.AddToLanguage("en", "ttt_beer_damagereduction_help",
        "The amount of damage reduction to apply per 100 drunkenness, in percent.\n" ..
        "Caps at 80%.")
    LANG.AddToLanguage("en", "ttt_beer_initialcount_name", "Initial Count")
    LANG.AddToLanguage("en", "ttt_beer_initialcount_help",
        "The initial count of beers a player gains when they purchase a pack.")

    LANG.AddToLanguage("en", "ttt_beer_action_drink", "Drink a cold one")
    LANG.AddToLanguage("en", "ttt_beer_action_give", "Generously put down a beer")
end

SWEP.HoldType = "pistol"

-- TODO: Modify to be holding a beer bottle
SWEP.ViewModel = "models/weapons/cstrike/c_eq_flashbang.mdl"
SWEP.WorldModel = "models/props_junk/glassbottle01a.mdl"

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Primary.Sound = Sound("npc/barnacle/barnacle_gulp2.wav")

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Kind = WEAPON_EQUIP
SWEP.CanBuy = { ROLE_TRAITOR, ROLE_DETECTIVE }
SWEP.DeploySpeed = 2
SWEP.NoSights = true

--#region Util
local function refreshHelp(swep)
    if SERVER then return end
    if swep:Clip1() < 2 then
        swep:AddTTT2HUDHelp("ttt_beer_action_drink")
    else
        swep:AddTTT2HUDHelp("ttt_beer_action_drink", "ttt_beer_action_give")
    end
end
--#endregion

--#region SWEP Hooks
function SWEP:Initialize()
    if not self.UsesSet then
        self.UsesSet = true
        self:SetClip1(cvarInitialCount:GetInt())
    end
    refreshHelp(self)
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end

    local ply = self:GetOwner()

    if not ply.SetDrunkFactor then return end

    self:TakePrimaryAmmo(1)
    self:EmitSound(self.Primary.Sound, 100)
    ply:SetDrunkFactor(ply:GetDrunkFactor() + cvarDrunkenness:GetInt())
    ply:SetNWBool("DrunkDamageReduction", true)

    self:SetNextPrimaryFire(CurTime() + 1)

    refreshHelp(self)

    -- If out of ammo, remove the weapon
    if self:Clip1() == 0 then
        ply:StripWeapon(self:GetClass())
    end
end

function SWEP:SecondaryAttack()
    if self:Clip1() < 2 then return end

    local ply = self:GetOwner()

    self:TakePrimaryAmmo(1)

    -- Make the player play a "give" animation
    ply:AnimPerformGesture(ACT_GMOD_GESTURE_ITEM_GIVE)

    refreshHelp(self)

    if CLIENT then return end

    -- Spawn a beer weapon in front
    local beer = ents.Create("weapon_ttt_beer")
    beer:SetPos(ply:GetShootPos() + ply:GetAimVector() * 10)
    beer:Spawn()
    beer.UsesSet = true
    beer:SetClip1(1)

    -- Apply some slight force to the beer
    local phys = beer:GetPhysicsObject()
    if IsValid(phys) then
        phys:ApplyForceCenter(ply:GetAimVector() * 100)
    end

    self:SetNextSecondaryFire(CurTime() + 1)

    -- If out of ammo, remove the weapon
    if self:Clip1() == 0 then
        ply:StripWeapon(self:GetClass())
    end
end

function SWEP:AddToSettingsMenu(parent)
    local form = vgui.CreateTTT2Form(parent, "header_equipment_additional")

    form:MakeHelp({
        label = "ttt_beer_drunkenness_help"
    })
    form:MakeSlider({
        serverConvar = "ttt_beer_drunkenness",
        label = "ttt_beer_drunkenness_name",
        min = 0,
        max = 500
    })

    form:MakeHelp({
        label = "ttt_beer_damagereduction_help"
    })
    form:MakeSlider({
        serverConvar = "ttt_beer_damagereduction",
        label = "ttt_beer_damagereduction_name",
        min = 0,
        max = 100
    })

    form:MakeHelp({
        label = "ttt_beer_initialcount_help"
    })
    form:MakeSlider({
        serverConvar = "ttt_beer_initialcount",
        label = "ttt_beer_initialcount_name",
        min = 1,
        max = 20,
        decimal = 0
    })
end

function SWEP:RefreshTTT2HUDHelp()
end

--#endregion

--#region Gamemode Hooks
-- Damage reduction
hook.Add("EntityTakeDamage", "ttt_beer", function(target, dmginfo)
    if not target:IsPlayer() then return end
    if not target.GetDrunkFactor then return end
    if not target:GetNWBool("DrunkDamageReduction") then return end

    local ply = target
    local drunkFactor = ply:GetDrunkFactor() / 100
    local damageReduction = cvarDamageReduction:GetInt() / 100

    dmginfo:ScaleDamage(1 - math.min(drunkFactor * damageReduction, 0.8))
end)

-- Reset drunk and damage reduction at round start, end, or death
hook.Add("TTTPrepareRound", "ttt_beer", function()
    for _, ply in ipairs(player.GetAll()) do
        if not ply.SetDrunkFactor then return end
        ply:SetDrunkFactor(0)
        ply:SetNWBool("DrunkDamageReduction", false)
    end
end)
hook.Add("TTTEndRound", "ttt_beer", function()
    for _, ply in ipairs(player.GetAll()) do
        if not ply.SetDrunkFactor then return end
        ply:SetDrunkFactor(0)
        ply:SetNWBool("DrunkDamageReduction", false)
    end
end)
hook.Add("PlayerDeath", "ttt_beer", function(ply)
    if not ply.SetDrunkFactor then return end
    ply:SetDrunkFactor(0)
    ply:SetNWBool("DrunkDamageReduction", false)
end)
--#endregion
