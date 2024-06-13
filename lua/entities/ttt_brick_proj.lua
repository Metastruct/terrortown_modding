local className = "ttt_brick_proj"
local effectNetworkTag = "TTTBrickImpactEffect"

if SERVER then
	AddCSLuaFile()

	resource.AddFile("materials/tbrick/shuffle.vmt")
	resource.AddSingleFile("sound/weapons/tw1stal1cky/brick/impact1.mp3")
	resource.AddSingleFile("sound/weapons/tw1stal1cky/brick/impact2.mp3")
	resource.AddSingleFile("sound/weapons/tw1stal1cky/brick/impact3.mp3")
	resource.AddSingleFile("sound/weapons/tw1stal1cky/brick/hitbody1.mp3")
	resource.AddSingleFile("sound/weapons/tw1stal1cky/brick/hitbody2.mp3")
	resource.AddSingleFile("sound/weapons/tw1stal1cky/brick/hitbody3.mp3")
	resource.AddSingleFile("sound/weapons/tw1stal1cky/brick/bonk.mp3")
	resource.AddSingleFile("sound/weapons/tw1stal1cky/brick/evil_bonk.mp3")
	resource.AddSingleFile("sound/weapons/tw1stal1cky/brick/evil_hitbody.mp3")

	util.AddNetworkString(effectNetworkTag)
end

ENT.Type = "anim"
ENT.ClassName = className

ENT.Model = "models/weapons/tbrick01.mdl"

-- Magneto-stick isn't allowed to pick this up
ENT.CanPickup = false
ENT.Projectile = true

AccessorFunc(ENT, "thrower", "Thrower")

function ENT:Initialize()
	self:SetModel(self.Model)

	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)

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
	local weaponClassName = "weapon_ttt_brick"
	local funcBreakableClassName = "func_breakable"
	local funcBreakableSurfClassName = "func_breakable_surf"

	local breakableFuncEnts = {
		[funcBreakableClassName] = true,
		[funcBreakableSurfClassName] = true
	}

	local utilTraceLine = util.TraceLine

	ENT.DamageMin = 2
	ENT.DamageMax = 45

	-- The amount of time the brick projectile has to exist before dealing full speed-scaled damage
	ENT.DamageGraceTime = 0.09

	ENT.SpeedScaleMin = 300
	ENT.SpeedScaleMax = 1800

	ENT.ImpactSound = ")weapons/tw1stal1cky/brick/impact%s.mp3"
	ENT.ImpactSoftSound = ")physics/concrete/rock_impact_soft%s.wav"
	ENT.BodyHitSound = ")weapons/tw1stal1cky/brick/hitbody%s.mp3"
	ENT.HeadshotSound = ")weapons/tw1stal1cky/brick/bonk.mp3"

	ENT.BstrdBodyHitSound = ")weapons/tw1stal1cky/brick/evil_hitbody.mp3"
	ENT.BstrdHeadshotSound = ")weapons/tw1stal1cky/brick/evil_bonk.mp3"

	local function CalculateDamage(self, speedScale, throwTimeScale)
		return math.ceil((self.DamageMin + (self.DamageMax - self.DamageMin) * speedScale * throwTimeScale) * (self.damageScaling or 1))
	end

	function ENT:PhysicsCollide(data, phys)
		if data.DeltaTime < 0.1 then return end

		local accurateSpeed = data.OurOldVelocity:Length()
		local speedScale

		if accurateSpeed >= self.SpeedScaleMin then
			speedScale = math.Clamp((accurateSpeed - self.SpeedScaleMin) / (self.SpeedScaleMax - self.SpeedScaleMin), 0, 1)

			local ent = data.HitEntity
			local isPerson = false
			local isHeadshot = false
			local isBstrd = self:GetSkin() == 1

			if IsValid(ent) then
				local velocityNormal = data.OurOldVelocity:GetNormalized()

				isPerson = ent:IsPlayer() or ent:IsNPC()

				if isPerson then
					local pos = data.HitPos

					local tr = utilTraceLine({
						start = pos,
						endpos = pos + (velocityNormal * 32),
						mask = MASK_SHOT
					})

					isHeadshot = tr.Entity == ent and tr.HitGroup == HITGROUP_HEAD

					if not isHeadshot then
						for i = 1, ent:GetHitBoxCount(0) do
							if ent:GetHitBoxHitGroup(i - 1, 0) == HITGROUP_HEAD then
								local boneId = ent:GetHitBoxBone(i - 1, 0)

								if boneId then
									pos = pos + (velocityNormal * 4)

									local matrix = ent:GetBoneMatrix(boneId)
									if matrix then
										local bonePos = matrix:GetTranslation()

										-- Getting the correct rotated head hitbox mins/maxs is a pain, sooooo
										isHeadshot = pos.z > bonePos.z

										break
									end
								end
							end
						end
					end
				end

				local thrower = self:GetThrower()
				local isThrowerValid = IsValid(thrower)

				local dmg

				if isThrowerValid then
					dmg = DamageInfo()

					local now = CurTime()
					local throwTimeScale = math.Clamp((now - self.ThrownTime) / self.DamageGraceTime, 0.1, 1)

					dmg:SetAttacker(thrower)
					dmg:SetInflictor(IsValid(self.WeaponEnt) and self.WeaponEnt or self)
					dmg:SetDamage(CalculateDamage(self, speedScale, throwTimeScale))
					dmg:SetDamageType(DMG_CLUB)
					dmg:SetDamagePosition(data.HitPos)
					dmg:SetDamageForce(velocityNormal * (64 + (1024 * speedScale)))
				end

				local matType = isPerson and MAT_FLESH or ent:GetMaterialType()
				local isFlesh = matType == MAT_FLESH or matType == MAT_BLOODYFLESH

				if isHeadshot then
					if isThrowerValid then
						dmg:ScaleDamage(2)

						-- Mute the death scream
						ent.was_headshot = true

						-- Var to flag they were hit with a brick headshot to pass onto the corpse
						ent.was_brick_headshot = true

						-- Don't let these flags linger for other sources of damage
						timer.Simple(0, function()
							if IsValid(ent) then
								ent.was_headshot = false
								ent.was_brick_headshot = nil
							end
						end)
					end

					ent:EmitSound(isBstrd and self.BstrdHeadshotSound or self.HeadshotSound, 100)
				elseif isFlesh then
					if isBstrd then
						self:EmitSound(self.BstrdBodyHitSound, 85, math.random(90, 110), 0.6 + (0.3 * speedScale))
					else
						self:EmitSound(string.format(self.BodyHitSound, math.random(1,3)), 85, math.random(97, 103), 0.25 + (0.75 * speedScale))
					end
				end

				if isFlesh then
					local ef = EffectData()
					ef:SetOrigin(data.HitPos)
					ef:SetNormal(-velocityNormal)

					util.Effect("BloodImpact", ef, false, true)
				end

				if isThrowerValid then
					ent:TakeDamageInfo(dmg)
				end
			end

			local pitchMin = 140 - (40 * speedScale)
			local volume = isBstrd and isPerson and 0.4 or 0.5 + (0.5 * speedScale)

			self:EmitSound(string.format(self.ImpactSound, math.random(1,3)), 80, math.random(pitchMin, pitchMin + 5), volume)

			net.Start(effectNetworkTag)
			net.WriteEntity(self)
			net.WriteVector(data.HitPos - (data.HitNormal * 2))
			net.WriteBool(isPerson)
			net.SendPVS(self:GetPos())
		else
			speedScale = math.Clamp(accurateSpeed / self.SpeedScaleMin, 0, 1)

			self:EmitSound(string.format(self.ImpactSoftSound, math.random(1,3)), 75, math.random(60, 120), 0.6 * speedScale)
		end
	end

	function ENT:PhysicsUpdate(phys)
		local velocitySqr = phys:GetVelocity():LengthSqr()

		if velocitySqr < 4 then
			local pos = self:GetPos()

			-- Only continue if we're resting on something, not still in the air
			local tr = utilTraceLine({
				start = pos,
				endpos = pos - (vector_up * 10),
				filter = self,
				mask = MASK_SOLID
			})

			if not tr.Hit then return end

			-- Replace ent with the weapon version of the ent so it can be picked up
			local wep

			if IsValid(self.WeaponEnt) then
				wep = self.WeaponEnt

				wep:SetParent()
				wep:SetCollisionGroup(COLLISION_GROUP_WEAPON)
				wep:DrawShadow(true)

				wep:SetPos(pos)
				wep:SetAngles(self:GetAngles())

				wep:SetInFlight(false)

				wep.was_thrown = nil
			else
				wep = ents.Create(weaponClassName)

				wep:SetPos(pos)
				wep:SetAngles(self:GetAngles())
				wep:SetSkin(self:GetSkin())

				wep:Spawn()
			end

			self:Remove()

			-- Disable auto-pickup using this and the below PlayerCanPickupWeapon hook
			wep.IsDropped = true

			-- Ensure the stored fingerprints are transferred to the weapon entity
			wep.fingerprints = self.fingerprints

			local wepPhys = wep:GetPhysicsObject()
			if IsValid(wepPhys) then
				wepPhys:Wake()
				wepPhys:SetVelocityInstantaneous(phys:GetVelocity())
				wepPhys:SetAngleVelocityInstantaneous(phys:GetAngleVelocity())
			end
		elseif velocitySqr >= self.SpeedScaleMin * self.SpeedScaleMin then
			local pos = phys:GetPos()
			local velocity = phys:GetVelocity()
			local velocityNormal = velocity:GetNormalized()

			local tr = utilTraceLine({
				start = pos,
				endpos = pos + (velocityNormal * math.max(velocity:Length() * FrameTime() * 1.2, 12)),
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

					tr.Entity:DispatchTraceAttack(dmg, tr, velocityNormal)
				end
			end
		end
	end

	hook.Add("PlayerCanPickupWeapon", "TTTBrickWeapon", function(pl, wep, dropBlockingWeapon, isPickupProbe)
		if wep:GetClass() == weaponClassName
			and wep.IsDropped
			and not isPickupProbe
		then
			return false, 5
		end
	end)

	hook.Add("TTTOnCorpseCreated", "TTTBrickWeapon", function(rag, pl)
		if pl.was_brick_headshot then
			rag.was_headshot = true
		end
	end)
else
	local particleFleck = Material("effects/fleck_cement2")
	local particleDust = Material("particle/particle_noisesphere")
	local particleFleckGravity = Vector(0, 0, -400)
	local particleDustGravity = Vector(0, 0, -120)
	local particleFleckColor = Color(255, 155, 100)
	local particleDustColor = Color(128, 64, 30)

	local bstrdParticle = Material("tbrick/shuffle")
	local bstrdGravity = Vector(0, 0, 25)
	local bstrdFleckColor = Color(255, 0, 102)
	local bstrdDustColor = Color(174, 0, 69)

	local emitter

	function ENT:OnRemove()
		-- Try cleaning up the shared emitter - a new one will get made if it's still in use anyway
		if IsValid(emitter) then
			emitter:Finish()
			emitter = nil
		end
	end

	function ENT:ImpactEffect(pos)
		pos = pos or self:GetPos()

		if not IsValid(emitter) then
			emitter = ParticleEmitter(pos)
		end

		local isBstrd = self:GetSkin() == 1
		local fleckColor = isBstrd and bstrdFleckColor or particleFleckColor
		local dustColor = isBstrd and bstrdDustColor or particleDustColor

		emitter:SetPos(pos)

		for i = 1, 25 do
			local p = emitter:Add(particleFleck, pos + (VectorRand() * 3))

			if p then
				p:SetDieTime(3)
				p:SetRoll(math.random(0, 360))

				p:SetStartSize(1.5)
				p:SetEndSize(1.5)
				p:SetStartAlpha(255)
				p:SetEndAlpha(0)
				p:SetColor(fleckColor.r, fleckColor.g, fleckColor.b)
				p:SetLighting(true)

				p:SetGravity(particleFleckGravity)
				p:SetVelocity(VectorRand() * 128)
				p:SetBounce(0.333)
				p:SetCollide(true)
			end
		end

		for i = 1, 4 do
			local p = emitter:Add(particleDust, pos)

			if p then
				p:SetDieTime(2)
				p:SetRollDelta(math.Rand(-1, 1))

				p:SetStartSize(8)
				p:SetEndSize(40)
				p:SetStartAlpha(150)
				p:SetEndAlpha(0)
				p:SetColor(dustColor.r, dustColor.g, dustColor.b)
				p:SetLighting(true)

				p:SetGravity(particleDustGravity)
				p:SetVelocity(VectorRand() * 200)
				p:SetAirResistance(800)
				p:SetCollide(true)
			end
		end
	end

	function ENT:BstrdImpactEffect(pos)
		if self:GetSkin() != 1 then return end

		pos = pos or self:GetPos()

		if not IsValid(emitter) then
			emitter = ParticleEmitter(pos)
		end

		emitter:SetPos(pos)

		for i = 1, 12 do
			local p = emitter:Add(bstrdParticle, pos + (VectorRand() * 3))

			if p then
				p:SetDieTime(2)
				p:SetRollDelta(math.Rand(-10, 10))

				p:SetStartSize(3)
				p:SetEndSize(3)
				p:SetStartAlpha(255)
				p:SetEndAlpha(0)

				p:SetGravity(bstrdGravity)
				p:SetVelocity(VectorRand() * 100)
				p:SetAirResistance(200)
				p:SetBounce(1)
				p:SetCollide(true)
			end
		end
	end

	net.Receive(effectNetworkTag, function()
		local ent = net.ReadEntity()
		if not IsValid(ent) or ent:GetClass() != className or not ent.ImpactEffect then return end

		local pos = net.ReadVector()
		local isPerson = net.ReadBool()

		ent:ImpactEffect(pos)

		if isPerson then
			ent:BstrdImpactEffect(pos)
		end
	end)
end