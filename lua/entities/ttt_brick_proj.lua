local effectNetworkTag = "TTTBrickImpactEffect"

if SERVER then
	AddCSLuaFile()

	resource.AddSingleFile("sound/weapons/tw1stal1cky/brick/impact1.mp3")
	resource.AddSingleFile("sound/weapons/tw1stal1cky/brick/impact2.mp3")
	resource.AddSingleFile("sound/weapons/tw1stal1cky/brick/impact3.mp3")
	resource.AddSingleFile("sound/weapons/tw1stal1cky/brick/hitbody1.mp3")
	resource.AddSingleFile("sound/weapons/tw1stal1cky/brick/hitbody2.mp3")
	resource.AddSingleFile("sound/weapons/tw1stal1cky/brick/hitbody3.mp3")
	resource.AddSingleFile("sound/weapons/tw1stal1cky/brick/bonk.mp3")

	util.AddNetworkString(effectNetworkTag)
end

ENT.Type = "anim"
ENT.Projectile = true

ENT.Model = "models/weapons/tbrick01.mdl"

-- Magneto-stick isn't allowed to pick this up
ENT.CanPickup = false

AccessorFunc(ENT, "thrower", "Thrower")

function ENT:Initialize()
    self:SetModel(self.Model)

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:AddGameFlag(FVPHYSICS_NO_IMPACT_DMG)
		phys:SetMass(3)
	end
end

if SERVER then
	local weaponClassName = "weapon_ttt_brick"

	ENT.DamageMin = 2
	ENT.DamageMax = 40

	ENT.SpeedScaleMin = 300
	ENT.SpeedScaleMax = 1900

	ENT.ImpactSound = ")weapons/tw1stal1cky/brick/impact%s.mp3"
	ENT.ImpactSoftSound = ")physics/concrete/rock_impact_soft%s.wav"
	ENT.BodyHitSound = ")weapons/tw1stal1cky/brick/hitbody%s.mp3"
	ENT.HeadshotSound = ")weapons/tw1stal1cky/brick/bonk.mp3"

	function ENT:PhysicsCollide(data, phys)
		if data.DeltaTime < 0.1 then return end

		local accurateSpeed = data.OurOldVelocity:Length()
		local speedScale

		if accurateSpeed >= self.SpeedScaleMin then
			speedScale = math.Clamp((accurateSpeed - self.SpeedScaleMin) / (self.SpeedScaleMax - self.SpeedScaleMin), 0, 1)

			local ent = data.HitEntity
			local isPerson = false

			if IsValid(ent) then
				isPerson = ent:IsPlayer() or ent:IsNPC()

				local isHeadshot = false

				local velocityNormal = data.OurOldVelocity:GetNormalized()

				if isPerson then
					local pos = data.HitPos

					local tr = util.TraceLine({
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

				local dmg = DamageInfo()
				dmg:SetAttacker(IsValid(thrower) and thrower or self)
				dmg:SetInflictor(self)
				dmg:SetDamage(math.ceil((self.DamageMin + (self.DamageMax - self.DamageMin) * speedScale) * (self.damageScaling or 1)))
				dmg:SetDamageType(DMG_GENERIC)
				dmg:SetDamagePosition(data.HitPos)
				dmg:SetDamageForce(velocityNormal * (64 + (1024 * speedScale)))

				local matType = isPerson and MAT_FLESH or ent:GetMaterialType()
				local isFlesh = matType == MAT_FLESH or matType == MAT_BLOODYFLESH

				if isHeadshot then
					dmg:ScaleDamage(2)
					ent:EmitSound(self.HeadshotSound, 100)
				elseif isFlesh then
					self:EmitSound(string.format(self.BodyHitSound, math.random(1,3)), 85, math.random(97, 103), 0.25 + (0.75 * speedScale))
				end

				if isFlesh then
					local ef = EffectData()
					ef:SetOrigin(data.HitPos)

					util.Effect("BloodImpact", ef, false, true)
				end

				ent:TakeDamageInfo(dmg)
			end

			local pitchMin = 140 - (40 * speedScale)

			self:EmitSound(string.format(self.ImpactSound, math.random(1,3)), 80, math.random(pitchMin, pitchMin + 5), 0.5 + (0.5 * speedScale))

			net.Start(effectNetworkTag)
			net.WriteEntity(self)
			net.WriteVector(data.HitPos - (data.HitNormal * 2))
			net.SendPVS(self:GetPos())
		else
			speedScale = math.Clamp(accurateSpeed / self.SpeedScaleMin, 0, 1)

			self:EmitSound(string.format(self.ImpactSoftSound, math.random(1,3)), 75, math.random(60, 120), 0.6 * speedScale)
		end
	end

	function ENT:PhysicsUpdate(phys)
		if phys:GetVelocity():LengthSqr() < 4 then
			-- Replace ent with the weapon version of the ent so it can be picked up
			local wep = ents.Create(weaponClassName)

			wep:SetPos(self:GetPos())
			wep:SetAngles(self:GetAngles())

			-- Disable auto-pickup using this and the below PlayerCanPickupWeapon hook
			wep.IsDropped = true

			wep:Spawn()

			local wepPhys = wep:GetPhysicsObject()
			if IsValid(wepPhys) then
				wepPhys:Wake()
				wepPhys:SetAngleVelocityInstantaneous(phys:GetAngleVelocity())
			end

			self:Remove()
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
else
	local particleFleck = Material("effects/fleck_cement2")
	local particleDust = Material("particle/particle_noisesphere")
	local particleFleckColor = Color(255, 155, 100)
	local particleDustColor = Color(128, 64, 30)
	local particleFleckGravity = Vector(0, 0, -400)
	local particleDustGravity = Vector(0, 0, -120)

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
				p:SetColor(particleFleckColor.r, particleFleckColor.g, particleFleckColor.b)
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
				p:SetColor(particleDustColor.r, particleDustColor.g, particleDustColor.b)
				p:SetLighting(true)

				p:SetGravity(particleDustGravity)
				p:SetVelocity(VectorRand() * 200)
				p:SetAirResistance(800)
				p:SetCollide(true)
			end
		end
	end

	net.Receive(effectNetworkTag, function()
		local ent = net.ReadEntity()
		if not IsValid(ent) then return end

		local pos = net.ReadVector()

		ent:ImpactEffect(pos)
	end)
end