if SERVER then
	AddCSLuaFile()
	resource.AddFile("materials/vgui/ttt/icon_knife.vmt")
end

SWEP.HoldType = "knife"

if CLIENT then
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

SWEP.Base = "weapon_tttbase"

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/cstrike/c_knife_t.mdl"
SWEP.WorldModel = "models/weapons/w_knife_t.mdl"

SWEP.Primary.Damage = 40
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Delay = 0.6
SWEP.Primary.Ammo = "none"
SWEP.Primary.HitRange = 80

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Delay = 1.4

SWEP.Kind = WEAPON_EQUIP
SWEP.CanBuy = {}
SWEP.LimitedStock = true

SWEP.IsSilent = true

-- Pull out faster than standard guns
SWEP.DeploySpeed = 2

function SWEP:PrimaryAttack()
	local owner = self:GetOwner()

	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
	self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)

	if not IsValid(owner) then return end

	owner:LagCompensation(true)

	local tr = self:TraceStab()

	local hitEnt = tr.Entity

	-- effects
	if IsValid(hitEnt) then
		local isPlayer = hitEnt:IsPlayer()
		local isBackstab = isPlayer and self:IsBackstab(hitEnt)

		self:SendWeaponAnim(isBackstab and ACT_VM_SECONDARYATTACK or ACT_VM_PRIMARYATTACK)

		if isPlayer or hitEnt:GetClass() == "prop_ragdoll" then
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
		dmg:SetAttacker(owner)
		dmg:SetInflictor(self)
		dmg:SetDamageForce(aimVector * 12)
		dmg:SetDamagePosition(owner:GetPos())
		dmg:SetDamageType(DMG_SLASH)

		hitEnt:DispatchTraceAttack(dmg, tr.StartPos + (aimVector * 3), tr.EndPos)
	end

	owner:LagCompensation(false)
end

function SWEP:TraceStab()
	local owner = self:GetOwner()

	local spos = owner:GetShootPos()
	local sdest = spos + owner:GetAimVector() * self.Primary.HitRange

	local kmins = Vector(-5, -5, -5)
	local kmaxs = Vector(5, 5, 5)

	local tr = util.TraceHull({
		start = spos,
		endpos = sdest,
		filter = owner,
		mask = MASK_SHOT_HULL,
		mins = kmins,
		maxs = kmaxs
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
	local owner = self:GetOwner()

	local angle = owner:GetAngles().y - target:GetAngles().y

    if angle < -180 then
        angle = 360 + angle
	end

    return angle <= 90 and angle >= -90
end

function SWEP:SecondaryAttack() end

if SERVER then
	function SWEP:Equip()
		self:SetNextPrimaryFire(CurTime() + self.Primary.Delay * 1.5)
		self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay * 1.5)
	end

	function SWEP:PreDrop()
		-- for consistency, dropped knife should not have DNA/prints
		self.fingerprints = {}
	end
end

function SWEP:OnRemove()
	if SERVER then return end

	local owner = self:GetOwner()

	if IsValid(owner) and owner == LocalPlayer() and owner:Alive() then
		RunConsoleCommand("lastinv")
	end
end

if CLIENT then
	local TryT = LANG.TryTranslation

	hook.Add("TTTRenderEntityInfo", "HUDDrawTargetIDShankKnife", function(tData)
		local client = LocalPlayer()

		if not IsValid(client) or not client:IsTerror() or not client:Alive() then return end

		local c_wep = client:GetActiveWeapon()

		if not IsValid(c_wep) or c_wep:GetClass() ~= "weapon_ttt_shankknife" or tData:GetEntityDistance() > c_wep.Primary.HitRange then return end

		local ent = tData:GetEntity()

		if not ent:IsPlayer() or not c_wep:IsBackstab(ent) then return end

		local role_color = client:GetRoleColor()

		-- enable targetID rendering
		tData:EnableOutline()
		tData:SetOutlineColor(role_color)

		tData:AddDescriptionLine(
			TryT("knife_instant"),
			role_color
		)

		-- draw instant-kill maker
		local x = ScrW() * 0.5
		local y = ScrH() * 0.5

		surface.SetDrawColor(clr(role_color))

		local outer = 20
		local inner = 10

		surface.DrawLine(x - outer, y - outer, x - inner, y - inner)
		surface.DrawLine(x + outer, y + outer, x + inner, y + inner)

		surface.DrawLine(x - outer, y + outer, x - inner, y + inner)
		surface.DrawLine(x + outer, y - outer, x + inner, y - inner)
	end)
end