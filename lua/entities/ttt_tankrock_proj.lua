local className = "ttt_tankrock_proj"
local effectNetworkTag = "TTTL4DTankRockImpactEffect"

local tankHitSlowNwTag = "TTTL4DTankHitSlow"

if SERVER then
	AddCSLuaFile()

	resource.AddSingleFile("sound/infected/tank_rock_hit.ogg")

	util.AddNetworkString(effectNetworkTag)
end

ENT.Type = "anim"
ENT.ClassName = className

ENT.Model = "models/props_debris/concrete_chunk01a.mdl"

ENT.Damage = 50

-- Magneto-stick isn't allowed to pick this up
ENT.CanPickup = false
ENT.Projectile = true

function ENT:Initialize()
	self:SetModel(self.Model)

	self:PhysicsInitBox(Vector(-16, -16, -3), Vector(16, 16, 3), "concrete")
	self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)

	self:AddEFlags(EFL_NO_DAMAGE_FORCES)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:AddGameFlag(FVPHYSICS_NO_IMPACT_DMG)

		phys:EnableDrag(false)
		phys:SetMass(3)
	end

	if SERVER then
		self.ThrownTime = CurTime()
	end
end

if SERVER then
	local funcBreakableClassName = "func_breakable"
	local funcBreakableSurfClassName = "func_breakable_surf"

	local breakableFuncEnts = {
		[funcBreakableClassName] = true,
		[funcBreakableSurfClassName] = true
	}

	local utilTraceLine = util.TraceLine

	ENT.ImpactSound = ")infected/tank_rock_hit.ogg"

	function ENT:PhysicsCollide(data, phys)
		if self.Collided or data.DeltaTime < 0.1 then return end

		local hitPos = self:GetPos()

		local owner = self:GetOwner()
		local attacker = IsValid(owner) and owner or self

		local forceVel

		local trTab = {
			filter = self,
			mask = MASK_SOLID_BRUSHONLY
		}

		local hitList = ents.FindInSphere(hitPos, 32)

		if IsValid(data.HitEntity) then
			local hasHitEnt = false

			for k, v in ipairs(hitList) do
				if v == data.HitEntity then
					hasHitEnt = true
					break
				end
			end

			if not hasHitEnt then
				hitList[#hitList + 1] = data.HitEntity
			end
		end

		for k, v in ipairs(hitList) do
			if v != self
				and v != owner
				and v:IsValid()
				and (not v:IsPlayer() or v:IsTerror())
			then
				if not forceVel then
					forceVel = data.OurOldVelocity:GetNormalized() * 25000
				end

				trTab.start = hitPos
				trTab.endpos = v:WorldSpaceCenter()

				-- Try to make sure we're not hitting something through walls or floors
				local tr = util.TraceLine(trTab)

				if not tr.Hit or tr.Entity == v then
					local dmg = DamageInfo()

					dmg:SetInflictor(self)
					dmg:SetAttacker(attacker)
					dmg:SetDamage(self.Damage)
					dmg:SetDamageType(DMG_CLUB)
					dmg:SetDamagePosition(hitPos)
					dmg:SetDamageForce(forceVel)

					v:DispatchTraceAttack(dmg, hitPos, data.HitNormal)

					if v:IsPlayer() then
						v:SetNWBool(tankHitSlowNwTag, true)

						timer.Create(tankHitSlowNwTag .. tostring(v:EntIndex()), 2, 1, function()
							if IsValid(v) then
								v:SetNWBool(tankHitSlowNwTag, false)
							end
						end)

						v:EmitSound("physics/body/body_medium_break3.wav", 75, math.random(72, 78))
					end
				end
			end
		end

		sound.Play(self.ImpactSound, hitPos, 90, math.random(94, 102))

		util.ScreenShake(hitPos, 60, 20, 1.25, 360, true)

		net.Start(effectNetworkTag)
		net.WriteEntity(self)
		net.WriteVector(hitPos)
		net.WriteVector(data.OurOldVelocity * 0.5)
		net.SendPVS(hitPos)

		self:SetNoDraw(true)

		self.Collided = true

		timer.Simple(0, function()
			if IsValid(self) then
				self:SetSolid(SOLID_NONE)
				self:SetMoveType(MOVETYPE_NONE)
			end
		end)

		SafeRemoveEntityDelayed(self, 0.2)
	end

	function ENT:PhysicsUpdate(phys)
		local vel = phys:GetVelocity()

		if vel:LengthSqr() > 4 then
			local pos = phys:GetPos()
			local velNormal = vel:GetNormalized()

			local tr = utilTraceLine({
				start = pos,
				endpos = pos + (velNormal * math.max(vel:Length() * FrameTime() * 1.3, 64)),
				filter = self,
				mask = MASK_SOLID
			})

			if IsValid(tr.Entity) then
				local entClassName = tr.Entity:GetClass()

				-- If this is a breakable GLASS brush (eg. a window), we need to break through it
				if breakableFuncEnts[entClassName] and (entClassName != funcBreakableClassName or tr.Entity:GetInternalVariable("material") == 0) then
					local dmg = DamageInfo()

					dmg:SetInflictor(self)
					dmg:SetAttacker(self)
					dmg:SetDamage(20)
					dmg:SetDamageType(DMG_CLUB)

					tr.Entity:DispatchTraceAttack(dmg, tr, velNormal)
				end
			end
		end
	end
else
	local particleFleck = Material("effects/fleck_cement2")
	local particleDust = Material("particle/particle_noisesphere")
	local particleFleckGravity = Vector(0, 0, -420)
	local particleDustGravity = Vector(0, 0, -80)
	local particleColor = Color(200, 200, 200)

	local gibModel = "models/props_debris/concrete_chunk03a.mdl"
	local gibLifeTime, gibFadeTime = 9, 3

	local emitter

	function ENT:OnRemove()
		-- Try cleaning up the shared emitter - a new one will get made if it's still in use anyway
		if IsValid(emitter) then
			emitter:Finish()
			emitter = nil
		end
	end

	function ENT:ImpactEffect(pos, gibVelocity)
		pos = pos or self:GetPos()
		gibVelocity = gibVelocity or self:GetVelocity()

		if not IsValid(emitter) then
			emitter = ParticleEmitter(pos)
		end

		emitter:SetPos(pos)

		for i = 1, 40 do
			local p = emitter:Add(particleFleck, pos + VectorRand(-3, 3))

			if p then
				p:SetDieTime(3)
				p:SetRoll(math.random(0, 360))

				p:SetStartSize(3)
				p:SetEndSize(3)
				p:SetStartAlpha(255)
				p:SetEndAlpha(0)
				p:SetColor(particleColor.r, particleColor.g, particleColor.b)
				p:SetLighting(true)

				p:SetGravity(particleFleckGravity)
				p:SetVelocity(VectorRand(-300, 300))
				p:SetAirResistance(1)
				p:SetBounce(0.333)
				p:SetCollide(true)
			end
		end

		for i = 1, 10 do
			local p = emitter:Add(particleDust, pos)

			if p then
				p:SetDieTime(6)
				p:SetRoll(math.random(0, 360))
				p:SetRollDelta(math.Rand(-0.5, 0.5))

				p:SetStartSize(40)
				p:SetEndSize(60)
				p:SetStartAlpha(160)
				p:SetEndAlpha(0)
				p:SetColor(particleColor.r, particleColor.g, particleColor.b)
				p:SetLighting(true)

				p:SetGravity(particleDustGravity)
				p:SetVelocity(VectorRand(-500, 500))
				p:SetAirResistance(400)
				p:SetCollide(true)
				p:SetBounce(0.75)
			end
		end

		local mins, maxs = self:GetCollisionBounds()

		for i = 1, 6 do
			local gib = ents.CreateClientProp(gibModel)

			gib:SetPos(pos + Vector(math.Rand(mins.x, maxs.x), math.Rand(mins.y, maxs.y), 4))
			gib:SetAngles(AngleRand())

			gib:Spawn()

			local phys = gib:GetPhysicsObject()
			if phys:IsValid() then
				phys:SetMaterial("concrete")
				phys:AddVelocity(gibVelocity)
				phys:AddAngleVelocity(VectorRand(-100, 100))
			end

			gib.StartTime = RealTime()

			gib.RenderOverride = function()
				local fade = 1 - math.max(RealTime() - gib.StartTime - (gibLifeTime - gibFadeTime), 0)

				render.SetBlend(fade)
				gib:DrawModel()
				render.SetBlend(1)
			end

			SafeRemoveEntityDelayed(gib, gibLifeTime)
		end
	end

	net.Receive(effectNetworkTag, function()
		local ent = net.ReadEntity()
		if not IsValid(ent) or ent:GetClass() != className or not ent.ImpactEffect then return end

		local pos = net.ReadVector()
		local vel = net.ReadVector()

		ent:ImpactEffect(pos, vel)
	end)
end