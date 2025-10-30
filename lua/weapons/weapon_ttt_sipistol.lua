AddCSLuaFile()

DEFINE_BASECLASS("weapon_tttbase")

if CLIENT then
	SWEP.PrintName = "sipistol_name"
	SWEP.Slot = 6

	SWEP.ViewModelFlip = false
	SWEP.ViewModelFOV = 54

	SWEP.Icon = "vgui/ttt/icon_silenced"
	SWEP.IconLetter = "a"

	SWEP.EquipMenuData = {
		type = "item_weapon",
		desc = LANG.TryTranslation("sipistol_desc") .. "\n\nShoot victims in the back of the head for critical damage.",
	}
end

SWEP.HoldType = "revolver"

SWEP.Primary.Ammo = "Pistol"
SWEP.Primary.Delay = 0.3
SWEP.Primary.Recoil = 1.35
SWEP.Primary.Cone = 0.0125
SWEP.Primary.Damage = 26
SWEP.Primary.Automatic = true
SWEP.Primary.ClipSize = 20
SWEP.Primary.ClipMax = 60
SWEP.Primary.DefaultClip = 20
SWEP.Primary.Sound = ")weapons/usp/usp1.wav"
SWEP.Primary.SoundLevel = 60

SWEP.HeadshotMultiplier = 2.25

SWEP.Kind = WEAPON_EQUIP
SWEP.CanBuy = { ROLE_TRAITOR } -- only traitors can buy
SWEP.WeaponID = AMMO_SIPISTOL
SWEP.AmmoEnt = "item_ammo_pistol_ttt"
SWEP.builtin = true

SWEP.IsSilent = true

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/cstrike/c_pist_usp.mdl"
SWEP.WorldModel = "models/weapons/w_pist_usp_silencer.mdl"
SWEP.idleResetFix = true

SWEP.IronSightsPos = Vector(-5.91, -4, 2.84)
SWEP.IronSightsAng = Vector(-0.5, 0, 0)

SWEP.PrimaryAnim = ACT_VM_PRIMARYATTACK_SILENCED
SWEP.ReloadAnim = ACT_VM_RELOAD_SILENCED
SWEP.IdleAnim = ACT_VM_IDLE_SILENCED

function SWEP:Deploy()
	self:SendWeaponAnim(ACT_VM_DRAW_SILENCED)

	return BaseClass.Deploy(self)
end

-- We were bought as special equipment, and we have an extra to give
function SWEP:WasBought(buyer)
	if IsValid(buyer) then
		buyer:GiveAmmo(20, self.Primary.Ammo)
	end
end

-- Assassination headshots
local pistolClass = "weapon_ttt_sipistol"
local maxCritDistSqr = 512 ^ 2

local function canCrit(owner, target)
	return owner:GetPos():DistToSqr(target:GetPos()) <= maxCritDistSqr and util.IsBehindAndFacingTarget(owner, target)
end

hook.Add("ScalePlayerDamage", pistolClass, function(target, hitGroup, dmgInfo)
	if hitGroup != HITGROUP_HEAD then return end

	local attacker = dmgInfo:GetAttacker()
	if not IsValid(attacker) or not attacker:IsPlayer() then return end

	local inflictor = dmgInfo:GetInflictor()
	if inflictor == attacker then
		inflictor = attacker:GetActiveWeapon()
	end

	if IsValid(inflictor)
		and inflictor:GetClass() == pistolClass
		and canCrit(attacker, target)
	then
		dmgInfo:ScaleDamage(2.5)
	end
end)

if CLIENT then
	local critText = "CRIT DAMAGE!"

	local outer = 20
	local inner = 10

	hook.Add("TTTRenderEntityInfo", "HUDDrawTargetIDSilencedPistol", function(tData)
		local pl = LocalPlayer()
		if not IsValid(pl) or not pl:IsTerror() then return end

		local wep = pl:GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() != pistolClass then return end

		local ent = tData:GetEntity()
		if not ent:IsPlayer()
			or pl:GetEyeTraceNoCursor().HitGroup != HITGROUP_HEAD
			or not canCrit(pl, ent)
		then return end

		local roleColor = pl:GetRoleColor()

		-- Enable targetID rendering
		tData:EnableOutline()
		tData:SetOutlineColor(roleColor)

		tData:AddDescriptionLine(critText, roleColor)

		-- Draw crit damage marker
		local x, y = ScrW() * 0.5, ScrH() * 0.5

		surface.SetDrawColor(roleColor.r, roleColor.g, roleColor.b)

		surface.DrawLine(x - outer, y - outer, x - inner, y - inner)
		surface.DrawLine(x + outer, y + outer, x + inner, y + inner)

		surface.DrawLine(x - outer, y + outer, x - inner, y + inner)
		surface.DrawLine(x + outer, y - outer, x + inner, y - inner)
	end)
end