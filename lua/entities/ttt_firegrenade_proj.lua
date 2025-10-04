if SERVER then
	AddCSLuaFile()
end

DEFINE_BASECLASS("ttt_basegrenade_proj")

ENT.Model = Model("models/weapons/w_eq_flashbang_thrown.mdl")

AccessorFunc(ENT, "radius", "Radius", FORCE_NUMBER)
AccessorFunc(ENT, "dmg", "Dmg", FORCE_NUMBER)

local fireRadius = 120
local innerRadius = 48
local innerLifeSpan = 30
local innerHull = Vector(3, 3, 3)

function ENT:Initialize()
	if not self:GetRadius() then
		self:SetRadius(256)
	end
	if not self:GetDmg() then
		self:SetDmg(25)
	end

	return BaseClass.Initialize(self)
end

function ENT:Explode(tr)
	self:SetDetonateExact(0)

	if CLIENT then return end

	self:SetNoDraw(true)
	self:SetSolid(SOLID_NONE)

	local traceCut = tr.Fraction != 1

	-- Pull out of the surface
	if traceCut then
		self:SetPos(tr.HitPos + tr.HitNormal * 0.6)
	end

	local pos = self:GetPos()

	if util.PointContents(pos) == CONTENTS_WATER then
		self:Remove()
		return
	end

	local damage = self:GetDmg()
	local radius = self:GetRadius()
	local thrower = self:GetThrower()

	local effect = EffectData()
	effect:SetStart(pos)
	effect:SetOrigin(pos)
	effect:SetScale(radius * 0.3)
	effect:SetRadius(radius)
	effect:SetMagnitude(damage)

	if traceCut then
		effect:SetNormal(tr.HitNormal)
	end

	util.Effect("Explosion", effect, true, true)
	util.Effect("ThumperDust", effect, true, true)
	util.PaintDown(pos, "Scorch", self)
	util.BlastDamage(self, thrower, pos, radius, damage)

	sound.Play("ambient/fire/ignite.wav", pos, 75, math.random(85, 100), 1)

	local liftedPos = pos + (tr.HitNormal * 24)
	local innerDieTime = CurTime() + innerLifeSpan
	local throwerIsValid = IsValid(thrower) and thrower:IsPlayer()

	for i = 1, 3 do
		local ang = tr.HitNormal:Angle()
		local tracePos = liftedPos
			+ (ang:Right() * math.Rand(-innerRadius, innerRadius))
			+ (ang:Up() * math.Rand(-innerRadius, innerRadius))

		local trHull = util.TraceHull({
			start = liftedPos,
			endpos = tracePos,
			mask = MASK_SOLID_BRUSHONLY,
			mins = -innerHull,
			maxs = innerHull
		})

		local flame = ents.Create("ttt_flame")
		flame:SetPos(trHull.HitPos)
		flame:SetFlameSize(fireRadius)
		flame:SetImmobile(false)
		flame:SetLifeSpan(innerLifeSpan)
		flame:SetDieTime(innerDieTime)

		if throwerIsValid then
			flame:SetDamageParent(thrower)
			flame:SetOwner(thrower)
		end

		flame:Spawn()
		flame:DropToFloor()

		local phys = flame:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetMass(2)
		end

		flame:StartFire()
	end

	gameEffects.StartFires(pos, tr, 18, 24, false, thrower, 512, false, fireRadius, 4)

	self:Remove()
end