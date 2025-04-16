local className = "weapon_ttt_shankknife"

if SERVER then
	AddCSLuaFile()

	resource.AddFile("materials/vgui/ttt/icon_knife.vmt")
else
	SWEP.PrintName = "Shanker's Knife"
	SWEP.Slot = 8
	SWEP.SlotPos = 1
	SWEP.ViewModelFlip = false
	SWEP.ViewModelFOV = 54
	SWEP.DrawCrosshair = false

	SWEP.EquipMenuData = {
		type = "item_weapon",
		desc = "Shank them in the back for an instant kill."
	}

	SWEP.Icon = "vgui/ttt/icon_knife"
	SWEP.IconLetter = "c"
end

DEFINE_BASECLASS("weapon_tttbase")

SWEP.HoldType = "knife"
SWEP.ClassName = className

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/cstrike/c_knife_t.mdl"
SWEP.WorldModel = "models/weapons/w_knife_t.mdl"

SWEP.Primary.Damage = 40
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Delay = 0.5
SWEP.Primary.Ammo = "none"
SWEP.Primary.HitRange = 72

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Delay = 1.4

SWEP.Kind = WEAPON_EQUIP
SWEP.CanBuy = {}
SWEP.LimitedStock = true

SWEP.IsSilent = true
SWEP.NoSights = true

-- Pull out faster than standard guns
SWEP.DeploySpeed = 2.25

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	owner:LagCompensation(true)

	local tr = self:TraceStab()
	local hitEnt = tr.Entity

	-- effects
	if IsValid(hitEnt) then
		local isPlayer = hitEnt:IsPlayer()
		local isBackstab = isPlayer and self:IsBackstab(hitEnt)

		self:SendWeaponAnim(isBackstab and ACT_VM_SECONDARYATTACK or ACT_VM_PRIMARYATTACK)

		if isPlayer or hitEnt:IsRagdoll() then
			local edata = EffectData()
			edata:SetStart(tr.StartPos)
			edata:SetOrigin(tr.HitPos)
			edata:SetNormal(tr.Normal)
			edata:SetEntity(hitEnt)

			util.Effect("BloodImpact", edata)
		end
	else
		self:SendWeaponAnim(ACT_VM_MISSCENTER)
	end

	owner:SetAnimation(PLAYER_ATTACK1)

	if SERVER and tr.Hit and tr.HitNonWorld and IsValid(hitEnt) then
		local aimVector = owner:GetAimVector()
		local dmgInt = self.Primary.Damage

		if hitEnt:IsPlayer() and self:IsBackstab(hitEnt) then
			dmgInt = 999
		end

		local dmg = DamageInfo()
		dmg:SetDamage(dmgInt)
		dmg:SetDamageType(DMG_SLASH)
		dmg:SetDamageForce(aimVector * 12)
		dmg:SetDamagePosition(owner:GetPos())
		dmg:SetAttacker(owner)
		dmg:SetInflictor(self)

		hitEnt:DispatchTraceAttack(dmg, tr.StartPos + (aimVector * 3), tr.EndPos)
	end

	owner:LagCompensation(false)
end

local hullMins, hullMaxs = Vector(-4, -4, -4), Vector(4, 4, 4)

function SWEP:TraceStab()
	local owner = self:GetOwner()
	local spos = owner:GetShootPos()
	local sdest = spos + owner:GetAimVector() * self.Primary.HitRange

	local tr = util.TraceHull({
		start = spos,
		endpos = sdest,
		filter = owner,
		mask = MASK_SHOT_HULL,
		mins = hullMins,
		maxs = hullMaxs
	})

	-- Hull might hit environment stuff that line does not hit
	if not IsValid(tr.Entity) then
		tr = util.TraceLine({
			start = spos,
			endpos = sdest,
			filter = owner,
			mask = MASK_SHOT_HULL
		})
	end

	-- Provide an extra field that holds the max range position
	tr.EndPos = sdest

	return tr
end

function SWEP:IsBackstab(target)
	return util.IsBehindAndFacingTarget(self:GetOwner(), target)
end

function SWEP:SecondaryAttack() end

if CLIENT then
	local TryT = LANG.TryTranslation

	local outer = 20
	local inner = 10

	hook.Add("TTTRenderEntityInfo", "HUDDrawTargetIDShankKnife", function(tData)
		local pl = LocalPlayer()
		if not IsValid(pl) or not pl:IsTerror() then return end

		local wep = pl:GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() != className or tData:GetEntityDistance() > wep.Primary.HitRange then return end

		local ent = tData:GetEntity()
		if not ent:IsPlayer() or not wep:IsBackstab(ent) then return end

		local roleColor = pl:GetRoleColor()

		-- Enable targetID rendering
		tData:EnableOutline()
		tData:SetOutlineColor(roleColor)

		tData:AddDescriptionLine(TryT("knife_instant"), roleColor)

		-- Draw instant-kill marker
		local x, y = ScrW() * 0.5, ScrH() * 0.5

		surface.SetDrawColor(roleColor.r, roleColor.g, roleColor.b)

		surface.DrawLine(x - outer, y - outer, x - inner, y - inner)
		surface.DrawLine(x + outer, y + outer, x + inner, y + inner)

		surface.DrawLine(x - outer, y + outer, x - inner, y + inner)
		surface.DrawLine(x + outer, y - outer, x + inner, y - inner)
	end)
end