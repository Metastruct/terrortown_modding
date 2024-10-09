-- Enables corpses to become solid when moving so they have the chance to kill players with physics!
-- Don't worry, the corpse needs to be moving quite fast for it to deal serious damage.

local tag = "TTTLethalRagdolls"

local ragStopSpeedSqr, ragDropStartSpeedSqr, ragNaturalStartSpeedSqr = 100 ^ 2, 125 ^ 2, 250 ^ 2
local minRagSpeedForDamage = 220

local function disableRagdollCollisions(rag)
	local physData = rag._frOldRagdollPhysicsData

	if physData then
		for i = 0, rag:GetPhysicsObjectCount() - 1 do
			local physNum = rag:GetPhysicsObjectNum(i)
			local physDataNum = physData[i]

			physNum:SetMass(physDataNum.mass)
			physNum:EnableDrag(physDataNum.drag)
		end
	end

	rag:SetCollisionGroup(rag._frOldCollisionGroup or COLLISION_GROUP_WEAPON)

	if rag._frCallbackId then
		rag:RemoveCallback("PhysicsCollide", rag._frCallbackId)
	end

	rag._fr = nil
	rag._frOldCollisionGroup = nil
	rag._frOldRagdollPhysicsData = nil
	rag._frCallbackId = nil
end

local function enableRagdollCollisions(rag)
	if rag._fr then return end

	local physData = {}

	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum(i)
		local mass = phys:GetMass()

		physData[i] = {
			mass = mass,
			drag = phys:IsDragEnabled()
		}

		phys:SetMass(math.max(mass, 15))
		phys:EnableDrag(false)
	end

	rag._fr = true
	rag._frOldCollisionGroup = rag:GetCollisionGroup()
	rag._frOldRagdollPhysicsData = physData

	rag:SetCollisionGroup(COLLISION_GROUP_NONE)

	if rag._frCallbackId then
		rag:RemoveCallback("PhysicsCollide", rag._frCallbackId)
	end

	if rag._frTimerName then
		timer.Remove(rag._frTimerName)
	end

	rag._frCallbackId = rag:AddCallback("PhysicsCollide", function(ent, dt)
		local hitEnt = dt.HitEntity

		if IsValid(hitEnt)
			and hitEnt:IsPlayer()
			and hitEnt:IsTerror()
			and (not hitEnt._frNextHit or CurTime() >= hitEnt._frNextHit)
		then
			local ourVel = dt.OurOldVelocity
			local ourSpeed = ourVel:Length()

			-- Try to get root PhysObj of the ragdoll's speed, use whichever is slower (ie. what's slower)
			local phys = ent:GetPhysicsObject()
			if IsValid(phys) then
				local bodyVel = phys:GetVelocity()
				local bodySpeed = bodyVel:Length()

				if ourSpeed > bodySpeed then
					ourVel = bodyVel
					ourSpeed = bodySpeed
				end
			end

			local hitSpeed = (dt.TheirOldVelocity - ourVel):Length()

			-- Use whichever is slower, the resulting speed of the collision or the speed of the ragdoll
			if hitSpeed > ourSpeed then
				hitSpeed = ourSpeed
			end

			-- Mmmmmm specific damage curve
			local dmgAmount = math.floor(((hitSpeed - minRagSpeedForDamage) * 0.01) ^ 2.13)

			if dmgAmount >= 1 then
				local physAttacker = ent:GetPhysicsAttacker()

				-- If there's no physics attacker (player who recently picked up the corpse), try getting the player who killed them
				if not IsValid(physAttacker) then
					physAttacker = ent.scene and ent.scene.damageInfoData and IsValid(ent.scene.damageInfoData.attacker) and ent.scene.damageInfoData.attacker or ent
				end

				local dmg = DamageInfo()

				dmg:SetInflictor(ent)
				dmg:SetAttacker(physAttacker)
				dmg:SetDamage(dmgAmount)
				dmg:SetDamageType(DMG_CRUSH + DMG_PHYSGUN)
				dmg:SetDamagePosition(dt.HitPos)
				dmg:SetDamageForce(dt.HitNormal * dt.OurOldVelocity:Length() * -0.2)

				hitEnt:TakeDamageInfo(dmg)

				-- If the damage is high enough (factoring in karma's damage multiplier), play a crunch sound
				if dmgAmount * (physAttacker.GetDamageFactor and physAttacker:GetDamageFactor() or 1) >= 20 then
					hitEnt:EmitSound(")physics/body/body_medium_break2.wav", 80, math.random(95, 115))
				end

				hitEnt._frNextHit = CurTime() + 0.2
			end
		end
	end)

	timer.Simple(0.33, function()
		if not IsValid(rag) then return end

		local timerName = tag .. tostring(rag:EntIndex())

		rag._frTimerName = timerName

		-- Check what the ragdoll is doing every interval - we want to dynamically enable and disable collisions based on certain factors
		timer.Create(timerName, 0.1, 0, function()
			if IsValid(rag) then
				local phys = rag:GetPhysicsObject()

				if rag._fr then
					if rag:IsPlayerHolding() or phys:GetVelocity():LengthSqr() < ragStopSpeedSqr then
						disableRagdollCollisions(rag)
					end
				elseif not rag:IsPlayerHolding() then
					-- Re-enable collisions easier if there is a recent physics attacker (typically meaning someone recently dropped the corpse)
					local requiredVelSqr = IsValid(rag:GetPhysicsAttacker()) and ragDropStartSpeedSqr or ragNaturalStartSpeedSqr

					if phys:GetVelocity():LengthSqr() > requiredVelSqr then
						enableRagdollCollisions(rag)
					end
				end

				return
			end

			timer.Remove(timerName)
		end)
	end)
end

hook.Add("TTTOnCorpseCreated", tag, function(rag)
	if rag.scene and rag.scene.damageInfoData and IsValid(rag.scene.damageInfoData.attacker) then
		rag:SetPhysicsAttacker(rag.scene.damageInfoData.attacker)
	end

	enableRagdollCollisions(rag)
end)