local physDmgMinSpeed, physDmgMinRampSpeed = 200, 900
local physHitGroupScales = {
	[HITGROUP_HEAD] = 1.2,
	[HITGROUP_LEFTARM] = 0.35,
	[HITGROUP_LEFTLEG] = 0.75
}

physHitGroupScales[HITGROUP_RIGHTARM] = physHitGroupScales[HITGROUP_LEFTARM]
physHitGroupScales[HITGROUP_RIGHTLEG] = physHitGroupScales[HITGROUP_LEFTLEG]

local function physDmgCollisionFunc(ent, data)
	if data.DeltaTime < 0.066 or data.HitEntity == ent then return end

	local pl = ent._RagdollingOwner
	if not IsValid(pl) then return end

	local denyOurVel = false

	local ourImpactVel = data.OurOldVelocity - data.OurNewVelocity
	local theirImpactVel = data.TheirOldVelocity - data.TheirNewVelocity

	local isBeingHeld = ent:IsPlayerHolding()

	if isBeingHeld then
		local carryHack = ent._RagdollingCarryHack

		if not IsValid(carryHack) then
			carryHack = nil

			local welds = constraint.FindConstraints(ent, "Weld")

			for i = 1, #welds do
				local weld = welds[i]
				local otherEnt = weld.Ent1 == ent and weld.Ent2 or weld.Ent1

				local holder = otherEnt:GetOwner()

				if IsValid(holder) and holder:IsPlayer() then
					local holderWep = holder:GetActiveWeapon()

					if IsValid(holderWep) and holderWep.CarryHack == otherEnt then
						-- Very sorry, I NEED to know the last pos of the carryhack entity to calculate deltas, this is the only way
						if not holderWep._LastPosThinkPatched then
							holderWep._originalThinkFunc = holderWep.Think

							function holderWep:Think()
								if IsValid(self.CarryHack) then
									self.CarryHack._LastPos = self.CarryHack:GetPos()
								end

								return self:_originalThinkFunc()
							end

							holderWep._LastPosThinkPatched = true
						end

						carryHack = otherEnt
						ent._RagdollingCarryHack = carryHack
						break
					end
				end
			end
		end

		if carryHack != nil then
			-- If the carryhack ent hasn't traveled enough this frame, then the carrier isn't really moving, flag this up
			denyOurVel = ((carryHack._LastPos or carryHack:GetPos()) - carryHack:GetPos()):LengthSqr() < 3

			if not denyOurVel then
				local holder = carryHack:GetOwner()
				if IsValid(holder) then
					local tr = util.TraceLine({
						start = holder:GetShootPos(),
						endpos = carryHack:GetPos(),
						filter = ent,
						mask = MASK_SOLID_BRUSHONLY
					})

					denyOurVel = tr.Hit
				end
			end

			if denyOurVel then
				ent._RagdollingCarriedStillGrace = CurTime() + 0.2
			end
		end
	else
		-- The ragdoll can still be flailing hard when let go, continue to flag this during the grace period
		denyOurVel = (ent._RagdollingCarriedStillGrace or 0) > CurTime()
	end

	if denyOurVel then
		-- If the carrier isn't moving, deny any ragdoll velocity to prevent the victim being insta-killed via the carrier sticking them in a wall
		ourImpactVel:Zero()
	elseif isBeingHeld then
		-- Reduce ragdoll velocity if being held
		ourImpactVel:Mul(0.5)
	end

	local hitSpeed = (ourImpactVel - theirImpactVel):Length()
	if hitSpeed < physDmgMinSpeed then return end

	local hitGroup = TTTRagdolling.GetHitGroupFromPhysBone(ent, data.PhysObject:GetIndex())
	local hitGroupScale = physHitGroupScales[hitGroup] or 1

	-- Base impact damage
	local dmg = (hitSpeed - physDmgMinSpeed) / 60

	-- Damage ramp up if impact was hard enough
	if hitSpeed >= physDmgMinRampSpeed then
		dmg = dmg + (((hitSpeed - physDmgMinRampSpeed) / 60) ^ 1.8)
	end

	-- Final reduction based on hitgroup and floor
	dmg = math.floor(dmg * hitGroupScale)

	if dmg > 0 then
		local dmgInfo = DamageInfo()
		dmgInfo:SetAttacker(ent)
		dmgInfo:SetInflictor(ent)
		dmgInfo:SetDamage(dmg)
		dmgInfo:SetDamageType(DMG_FALL)
		dmgInfo:SetDamagePosition(data.HitPos)

		pl:TakeDamageInfo(dmgInfo)
	end
end

function TTTRagdolling.Start(pl)
	if not pl:IsTerror() or TTTRagdolling.IsPlayerRagdolling(pl) then return end

	local pos = pl:GetPos()

	local rag = ents.Create("prop_ragdoll")
	if not IsValid(rag) then return end

	rag:SetModel(pl:GetModel())
	rag:SetPos(pos)
	rag:SetAngles(pl:GetAngles())
	rag:SetSkin(pl:GetSkin())
	rag:SetColor(pl:GetColor())

	for k, v in pairs(pl:GetBodyGroups()) do
		rag:SetBodygroup(v.id, pl:GetBodygroup(v.id))
	end

	rag:SetOwner(pl)
	rag:Spawn()
	rag:Activate()

	rag:SetCollisionGroup(COLLISION_GROUP_WEAPON)
   	rag:SetCustomCollisionCheck(true)

	CORPSE.SetPlayerNick(rag, pl)
	rag:SetDTEntity(TTTRagdolling._dtRagdollOwnerId, pl)
	rag._RagdollingOwner = pl

	rag:CallOnRemove(TTTRagdolling._hookName, function(ent)
		TTTRagdolling.Stop(ent)
	end)

	rag._RagdollingCallbackId = rag:AddCallback("PhysicsCollide", physDmgCollisionFunc)

	pl:SelectWeapon("weapon_ttt_unarmed")
	pl:SetNWEntity(TTTRagdolling._nwRagdoll, rag)

	pl._RagdollingData = {
		Ragdoll = rag,
		ColGroup = pl:GetCollisionGroup(),
		ViewStand = pl:GetViewOffset(),
		ViewDucked = pl:GetViewOffsetDucked()
	}

	if pac and pac.TogglePartDrawing then
		pac.TogglePartDrawing(pl, false)
	end

	if IsValid(pl.hat) and isfunction(pl.hat.Drop) then
		pl.hat:Drop()
	end

	local plVel = pl:GetVelocity()

	pl:SetVelocity(-plVel)

	local boneCount = rag:GetPhysicsObjectCount() - 1
	for i = 0, boneCount do
		local bone = rag:GetPhysicsObjectNum(i)

		if IsValid(bone) then
			local bp, ba = pl:GetBonePosition(rag:TranslatePhysBoneToBone(i))

			if bp and ba then
				bone:SetPos(bp)
				bone:SetAngles(ba)
			end

			bone:SetVelocity(plVel)
		end
	end

	pl:SetNoDraw(true)
	pl:DrawShadow(false)
	pl:Flashlight(false)
	pl:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)

	pl:SetViewOffset(vector_origin)
	pl:SetViewOffsetDucked(vector_origin)

	pl:SetParent(rag)
	pl:SetLocalPos(vector_origin)
	pl:SetMoveType(MOVETYPE_NONE)

	return rag
end

function TTTRagdolling.Stop(plOrRag, dontRemoveRagdoll)
	local pl

	if plOrRag:IsPlayer() then
		pl = plOrRag
	else
		pl = TTTRagdolling.GetRagdollOwner(plOrRag)
	end
	if not IsValid(pl) then return end

	local data = pl._RagdollingData
	if not istable(data) then return end

	pl:SetParent()
	pl:SetNWEntity(TTTRagdolling._nwRagdoll, NULL)

	local pos, vel
	local rag = data.Ragdoll

	if IsValid(rag) then
		pos = rag:GetPos()
		pos.z = pos.z + data.ViewDucked.z

		vel = rag:GetVelocity()

		rag:RemoveCallOnRemove(TTTRagdolling._hookName)

		rag._RagdollingOwner = nil
		rag:SetOwner(NULL)
		rag:SetDTEntity(TTTRagdolling._dtRagdollOwnerId, NULL)

		if rag._RagdollingCallbackId then
			rag:RemoveCallback("PhysicsCollide", rag._RagdollingCallbackId)
		end

		if not dontRemoveRagdoll then
			-- For some reason, if we remove the ragdoll on the same frame as we unparent,
			-- clients THINK the player entity is at 0,0,0 before interp'ing to their real position.
			-- To stop this render bug, the ragdoll has to continue existing for a frame.
			rag:SetNoDraw(true)
			rag:SetSolid(SOLID_NONE)
			rag:DrawShadow(false)

			timer.Simple(0, function()
				if IsValid(rag) then
					rag:Remove()
				end
			end)
		end
	else
		pos = pl:EyePos()
	end

	pos = util.FindBestRestorePos(pl, pos, data.ViewStand.z)

	pl:SetPos(pos)

	pl:SetViewOffset(data.ViewStand)
	pl:SetViewOffsetDucked(data.ViewDucked)
	pl:SetCurrentViewOffset(data.ViewDucked)

	timer.Simple(0, function()
		if not IsValid(pl) then return end

		pl:SetCollisionGroup(data.ColGroup or COLLISION_GROUP_PLAYER)

		if pl:Alive() then
			-- Kindaaaa let people rocket the ragdolled player into orbit by swinging them around as they get up, it's funny
			if IsValid(rag) and rag:IsPlayerHolding() then
				vel:Mul(0.5)
			end

			pl:SetMoveType(MOVETYPE_WALK)
			pl:SetVelocity(-pl:GetVelocity() + (vel or vector_origin))

			if util.TraceLine({
				start = pos,
				endpos = pl:GetPos(),
				mask = MASK_PLAYERSOLID_BRUSHONLY,
				filter = pl
			}).HitWorld then
				-- Some absolute source engine DOGSHIT just happened where the player got teleported through the floor, bring them back
				pl:SetPos(pos)
			end
		end
	end)

	if pac and pac.TogglePartDrawing then
		pac.TogglePartDrawing(pl, true)
	end

	pl:SetNoDraw(false)
	pl:DrawShadow(true)

	pl._RagdollingData = nil
end

function TTTRagdolling.GetHitGroupFromPhysBone(rag, physBoneId)
	local cache = rag._RagdollingHitGroupCache

	-- Build the hitbox bone cache if it hasn't been built yet
	if not istable(cache) then
		cache = {}

		local hitBoxCount = rag:GetHitBoxCount(0)

		for i = 0, hitBoxCount - 1 do
			local hitBoxBoneId = rag:GetHitBoxBone(i, 0)
			if not hitBoxBoneId then continue end

			local physBoneId = rag:TranslateBoneToPhysBone(hitBoxBoneId)
			if physBoneId == -1 then continue end

			cache[physBoneId] = rag:GetHitBoxHitGroup(i, 0)
		end

		rag._RagdollingHitGroupCache = cache
	end

	return cache[physBoneId]
end

hook.Add("PostEntityFireBullets", TTTRagdolling._hookName, function(ent, data)
	local tr = data.Trace
	if not tr.HitNonWorld then return end

	local rag = tr.Entity
	local pl = TTTRagdolling.GetRagdollOwner(rag)
	if not IsValid(pl) then return end

	-- tr.HitGroup isn't populated when shooting ragdolls, so we need to use tr.PhysicsBone
	rag._RagdollingHitGroup = TTTRagdolling.GetHitGroupFromPhysBone(rag, tr.PhysicsBone)
end)

hook.Add("EntityTakeDamage", TTTRagdolling._hookName, function(ent, dmg)
	local pl = TTTRagdolling.GetRagdollOwner(ent)
	if not IsValid(pl) then return end

	-- Don't transfer damage to the player if:
	--   Explosion damage - the player already takes explosion damage even when ragdolled
	--   Physics damage - that is already handled in a custom callback for a better damage range
	if dmg:IsDamageType(DMG_BLAST) or dmg:IsDamageType(DMG_CRUSH) then return end

	local wouldHeadsplat = false
	local hitGroup = ent._RagdollingHitGroup

	if hitGroup then
		hook.Run("ScalePlayerDamage", pl, hitGroup, dmg)

		-- Headsplat support
		if TTTHeadSplats then
			wouldHeadsplat = TTTHeadSplats.ShouldHeadExplode(pl, dmg:GetAttacker(), dmg)

			-- Don't pop the head of the obsolete corpse
			pl._ignoreHeadExplode = true
			pl._shouldHeadExplode = nil
		end
	end

	ent._RagdollingHitGroup = nil

	pl:TakeDamageInfo(dmg)

	pl._ignoreHeadExplode = nil

	if wouldHeadsplat and not pl:Alive() then
		TTTHeadSplats.ExplodeHead(ent, pl)
	end
end)

local function transferCorpseData(oldRag, rag)
	rag.player_ragdoll = oldRag.player_ragdoll
	rag.sid = oldRag.sid
	rag.sid64 = oldRag.sid64
	rag.uqid = oldRag.uqid

	CORPSE.SetPlayerNick(rag, oldRag:GetDTEntity(CORPSE.dti.ENT_PLAYER))
	CORPSE.SetFound(rag, oldRag:GetDTBool(CORPSE.dti.BOOL_FOUND))
	CORPSE.SetCredits(rag, oldRag:GetDTInt(CORPSE.dti.INT_CREDITS))

	rag.equipment = oldRag.equipment
	rag.was_role = oldRag.was_role
	rag.role_color = oldRag.role_color

	rag.was_team = oldRag.was_team
	rag.bomb_wire = oldRag.bomb_wire
	rag.dmgtype = oldRag.dmgtype

	rag.dmgwep = oldRag.dmgwep

	rag.was_headshot = oldRag.was_headshot
	rag.time = oldRag.time
	rag.kills = oldRag.kills
	rag.killer_sample = oldRag.killer_sample

   	rag.scene = oldRag.scene
end

local function denyIfRagdolled(pl)
	if TTTRagdolling.IsPlayerRagdolling(pl) then return false end
end

hook.Add("PlayerPostThink", TTTRagdolling._hookName, function(pl)
	if TTTRagdolling.IsPlayerRagdolling(pl) then
		-- This is the only suitable place where SetGroundEntity actually affects the magneto-stick's anti-pickup
		pl:SetGroundEntity(NULL)
	end
end)

hook.Add("TTTOnCorpseCreated", TTTRagdolling._hookName, function(corpse, pl)
	local rag = TTTRagdolling.GetPlayerRagdoll(pl)

	if IsValid(rag) then
		transferCorpseData(corpse, rag)

		corpse:SetNoDraw(true)
		corpse:SetSolid(SOLID_NONE)

		timer.Simple(0, function()
			if IsValid(corpse) then
				corpse:Remove()
			end
		end)
	end
end)

hook.Add("PlayerDeath", TTTRagdolling._hookName, function(pl)
	TTTRagdolling.Stop(pl, true)
end)

-- Don't let ragdolled people use stuff (traitor buttons are handled differently so they are still useable)
hook.Add("PlayerUse", TTTRagdolling._hookName, denyIfRagdolled)

-- Don't let ragdolled people pick up guns
hook.Add("PlayerCanPickupWeapon", TTTRagdolling._hookName, denyIfRagdolled)

-- Don't let ragdolled people pick up items like ammo
hook.Add("PlayerCanPickupItem", TTTRagdolling._hookName, denyIfRagdolled)

-- Don't let ragdolled people drop ammo boxes
hook.Add("TTT2DropAmmo", TTTRagdolling._hookName, denyIfRagdolled)

-- Don't let ragdolled people turn on their flashlight
hook.Add("PlayerSwitchFlashlight", TTTRagdolling._hookName, function(pl, state)
	if state and TTTRagdolling.IsPlayerRagdolling(pl) then return false end
end)