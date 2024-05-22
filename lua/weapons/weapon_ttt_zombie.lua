if SERVER then
	AddCSLuaFile()
	resource.AddFile("models/weapons/c_zombieswep.mdl")
end

DEFINE_BASECLASS("weapon_tttbase")

SWEP.PrintName = "Claws"
SWEP.Author = ""
SWEP.Purpose = "BRAAAAINS!!1!"
SWEP.Slot = 0
SWEP.SlotPos = 4
SWEP.Spawnable = true
SWEP.ViewModel = Model("models/weapons/c_zombieswep.mdl")
SWEP.WorldModel = ""
SWEP.ViewModelFOV = 90
SWEP.UseHands = true
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = "none"
SWEP.DrawAmmo = false
SWEP.HitDistance = 48

local SWING_SOUND = Sound("WeaponFrag.Throw")
local HIT_SOUND = Sound("Flesh.ImpactHard")

function SWEP:Initialize()
	self:SetHoldType("normal")
	self.ActivityTranslate[ACT_MP_STAND_IDLE] = ACT_HL2MP_IDLE_ZOMBIE
	self.ActivityTranslate[ACT_MP_WALK] = ACT_HL2MP_WALK_ZOMBIE_01
	self.ActivityTranslate[ACT_MP_RUN] = ACT_HL2MP_RUN_ZOMBIE
	self.ActivityTranslate[ACT_MP_CROUCH_IDLE] = ACT_HL2MP_IDLE_CROUCH_ZOMBIE
	self.ActivityTranslate[ACT_MP_CROUCHWALK] = ACT_HL2MP_WALK_CROUCH_ZOMBIE_01
	self.ActivityTranslate[ACT_MP_ATTACK_STAND_PRIMARYFIRE] = ACT_GMOD_GESTURE_RANGE_ZOMBIE
	self.ActivityTranslate[ACT_MP_ATTACK_CROUCH_PRIMARYFIRE] = ACT_GMOD_GESTURE_RANGE_ZOMBIE
	self.ActivityTranslate[ACT_MP_JUMP] = ACT_ZOMBIE_LEAPING
	self.ActivityTranslate[ACT_RANGE_ATTACK1] = ACT_GMOD_GESTURE_RANGE_ZOMBIE
end

function SWEP:SetupDataTables()
	self:NetworkVar("Float", 0, "NextMeleeAttack")
	self:NetworkVar("Float", 1, "NextIdle")
	self:NetworkVar("Int", 2, "Combo")
end

function SWEP:UpdateNextIdle()
	local vm = self:GetOwner():GetViewModel()
	self:SetNextIdle(CurTime() + vm:SequenceDuration() / vm:GetPlaybackRate())
end

function SWEP:PrimaryAttack(right)
	self:GetOwner():SetAnimation(PLAYER_ATTACK1)
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self:EmitSound(SWING_SOUND)

	self:DealDamage()

	self:UpdateNextIdle()
	self:SetNextMeleeAttack(CurTime() + 0.2)
	self:SetNextPrimaryFire(CurTime() + 0.2)
end

function SWEP:SecondaryAttack()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end
	if self:GetGroundEntity() == NULL then return end -- in the air

	owner:SetVelocity(ply:GetAimVector() * 1250)
	owner:EmitSound("", 80, math.random(95, 105))

	self:SetNextSecondaryFire(CurTime() + 1)
end

local phys_pushscale = GetConVar("phys_pushscale")
function SWEP:DealDamage()
	local anim = self:GetSequenceName(self:GetOwner():GetViewModel():GetSequence())
	self:GetOwner():LagCompensation(true)

	local tr = util.TraceLine({
		start = self:GetOwner():GetShootPos(),
		endpos = self:GetOwner():GetShootPos() + self:GetOwner():GetAimVector() * self.HitDistance,
		filter = self:GetOwner(),
		mask = MASK_SHOT_HULL
	})

	if not IsValid(tr.Entity) then
		tr = util.TraceHull({
			start = self:GetOwner():GetShootPos(),
			endpos = self:GetOwner():GetShootPos() + self:GetOwner():GetAimVector() * self.HitDistance,
			filter = self:GetOwner(),
			mins = Vector(-10, -10, -8),
			maxs = Vector(10, 10, 8),
			mask = MASK_SHOT_HULL
		})
	end

	-- We need the second part for single player because SWEP:Think is ran shared in SP
	if tr.Hit and not (game.SinglePlayer() and CLIENT) then
		self:EmitSound(HIT_SOUND)
	end

	local hit = false
	local scale = phys_pushscale:GetFloat()

	if SERVER and IsValid(tr.Entity) and (tr.Entity:IsNPC() or tr.Entity:IsPlayer() or tr.Entity:Health() > 0) then
		local dmg_info = DamageInfo()
		local attacker = self:GetOwner()

		if not IsValid(attacker) then
			attacker = self
		end

		dmg_info:SetAttacker(attacker)
		dmg_info:SetInflictor(self)
		dmg_info:SetDamage(15)

		SuppressHostEvents(NULL) -- Let the breakable gibs spawn in multiplayer on client
		tr.Entity:TakeDamageInfo(dmg_info)
		SuppressHostEvents(self:GetOwner())
		hit = true
	end

	if IsValid(tr.Entity) then
		local phys = tr.Entity:GetPhysicsObject()
		if IsValid(phys) then
			phys:ApplyForceOffset(self:GetOwner():GetAimVector() * 80 * phys:GetMass() * scale, tr.HitPos)
		end
	end

	if SERVER then
		if hit and anim ~= "fists_uppercut" then
			self:SetCombo(self:GetCombo() + 1)
		else
			self:SetCombo(0)
		end
	end

	self:GetOwner():LagCompensation(false)
end

function SWEP:OnDrop()
	self:Remove() -- You can't drop fists
end

local SPEED_CV = GetConVar("sv_defaultdeployspeed")

function SWEP:Deploy()
	local speed = SPEED_CV:GetFloat()
	local vm = self:GetOwner():GetViewModel()
	self:SendWeaponAnim(ACT_VM_DRAW)
	self:SetPlaybackRate(speed)
	self:SetNextPrimaryFire(CurTime() + vm:SequenceDuration() / speed)
	self:SetNextSecondaryFire(CurTime() + vm:SequenceDuration() / speed)
	self:UpdateNextIdle()

	if SERVER then
		self:SetCombo(0)
	end

	return true
end

function SWEP:Holster()
	self:SetNextMeleeAttack(0)

	return true
end

function SWEP:Think()
	local idle_time = self:GetNextIdle()
	if idle_time > 0 and CurTime() > idle_time then
		self:SendWeaponAnim(ACT_VM_IDLE)
		self:UpdateNextIdle()
	end

	if SERVER and CurTime() > self:GetNextPrimaryFire() + 0.1 then
		self:SetCombo(0)
	end
end