if SERVER then
    AddCSLuaFile()
end

DEFINE_BASECLASS("weapon_tttbase")

SWEP.HoldType = "knife"

if CLIENT then
    SWEP.PrintName = "knife_name"
    SWEP.Slot = 6

    SWEP.ViewModelFlip = false
    SWEP.ViewModelFOV = 54

    SWEP.EquipMenuData = {
        type = "item_weapon",
        desc = "knife_desc",
    }

    SWEP.Icon = "vgui/ttt/icon_knife"
    SWEP.IconLetter = "j"
end

SWEP.Base = "weapon_tttbase"

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/cstrike/c_knife_t.mdl"
SWEP.WorldModel = "models/weapons/w_knife_t.mdl"
SWEP.idleResetFix = true

SWEP.Primary.Damage = 75
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Delay = 0.75
SWEP.Primary.Ammo = "none"
SWEP.Primary.HitRange = 86

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Delay = 1.4

SWEP.Kind = WEAPON_EQUIP
SWEP.CanBuy = { ROLE_TRAITOR } -- only traitors can buy
SWEP.LimitedStock = true -- only buyable once
SWEP.WeaponID = AMMO_KNIFE
SWEP.builtin = true

SWEP.IsSilent = true

-- Pull out faster than standard guns
SWEP.DeploySpeed = 2

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	owner:LagCompensation(true)

	local tr = self:TraceStab()
	local hitEnt = tr.Entity

	-- effects
	if IsValid(hitEnt) then
		self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

		if hitEnt:IsPlayer() or hitEnt:IsRagdoll() then
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
		local dmgInt = self.Primary.Damage * (self.damageScaling or 1)

		local dmg = DamageInfo()
		dmg:SetDamage(dmgInt)
		dmg:SetDamageType(DMG_SLASH)
		dmg:SetDamageForce(aimVector * 12)
		dmg:SetDamagePosition(owner:GetPos())
		dmg:SetAttacker(owner)
		dmg:SetInflictor(self)

		self:PrepareStickingKnife(tr, tr.StartPos, tr.EndPos)

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

function SWEP:PrepareStickingKnife(tr, spos, sdest)
    local owner = self:GetOwner()
    local target = tr.Entity

    -- now that we use a hull trace, our hitpos is guaranteed to be
    -- terrible, so try to make something of it with a separate trace and
    -- hope our effect_fn trace has more luck

    -- first a straight up line trace to see if we aimed nicely
    local retr = util.TraceLine({
        start = spos,
        endpos = sdest,
        filter = owner,
        mask = MASK_SHOT_HULL,
    })

    -- if that fails, just trace to worldcenter so we have SOMETHING
    if retr.Entity ~= target then
        local center = target:LocalToWorld(target:OBBCenter())

        retr = util.TraceLine({
            start = spos,
            endpos = center,
            filter = owner,
            mask = MASK_SHOT_HULL,
        })
    end

    -- create knife effect creation fn
    local bone = retr.PhysicsBone
    local pos = retr.HitPos
    local norm = tr.Normal

	-- Define a function on the target entity that is called by CORPSE.Create
    target.effect_fn = function(rag)
        -- we might find a better location
        local rtr = util.TraceLine({
            start = pos,
            endpos = pos + norm * 40,
            filter = owner,
            mask = MASK_SHOT_HULL,
        })

        if IsValid(rtr.Entity) and rtr.Entity == rag then
            bone = rtr.PhysicsBone
            pos = rtr.HitPos

            ang = Angle(-28, 0, 0) + rtr.Normal:Angle()
            ang:RotateAroundAxis(ang:Right(), -90)

            pos = pos - (norm * 7.5)
        end

        local knife = ents.Create("prop_physics")
        knife:SetModel("models/weapons/w_knife_t.mdl")
        knife:SetPos(pos)
        knife:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
        knife:SetAngles(ang)

        knife.CanPickup = false

        knife:Spawn()

        local phys = knife:GetPhysicsObject()

        if IsValid(phys) then
            phys:EnableCollisions(false)
        end

        constraint.Weld(rag, knife, bone, 0, 0, true)

        -- need to close over knife in order to keep a valid ref to it
        rag:CallOnRemove("ttt_knife_cleanup", function()
            SafeRemoveEntity(knife)
        end)

        SafeRemoveEntity(self)
    end

	-- Clean it up a frame later so nothing else can accidentally trigger it
	timer.Simple(0, function()
		if IsValid(target) and target.effect_fn then
			target.effect_fn = nil
		end
	end)
end

function SWEP:SecondaryAttack()
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)

    self:SendWeaponAnim(ACT_VM_MISSCENTER)

    if CLIENT then
        return
    end

    local ply = self:GetOwner()

    if not IsValid(ply) then
        return
    end

    ply:SetAnimation(PLAYER_ATTACK1)

    local ang = ply:EyeAngles()

    if ang.p < 90 then
        ang.p = -10 + ang.p * ((90 + 10) / 90)
    else
        ang.p = 360 - ang.p
        ang.p = -10 + ang.p * -((90 + 10) / 90)
    end

    local vel = math.Clamp((90 - ang.p) * 5.5, 550, 800)
    local vfw = ang:Forward()
    local vrt = ang:Right()

    local src = ply:GetPos()
        + (ply:Crouching() and ply:GetViewOffsetDucked() or ply:GetViewOffset())
    src = src + (vfw * 1) + (vrt * 3)

    local thr = vfw * vel + ply:GetVelocity()

    local knife_ang = Angle(-28, 0, 0) + ang
    knife_ang:RotateAroundAxis(knife_ang:Right(), -90)

    local knife = ents.Create("ttt_knife_proj")

    if not IsValid(knife) then
        return
    end

    knife:SetPos(src)
    knife:SetAngles(knife_ang)
    knife:Spawn()
    knife:SetOwner(ply)

    knife.Damage = self.Primary.Damage

    local phys = knife:GetPhysicsObject()

    if IsValid(phys) then
        phys:SetVelocity(thr)
        phys:AddAngleVelocity(Vector(0, 1500, 0))
        phys:Wake()
    end

    self:Remove()
end

if SERVER then
    function SWEP:PreDrop()
        -- for consistency, dropped knife should not have DNA/prints
        self.fingerprints = {}
    end
else
    local TryT = LANG.TryTranslation

    function SWEP:Initialize()
        self:AddTTT2HUDHelp("knife_help_primary", "knife_help_secondary")
        return BaseClass.Initialize(self)
    end
end