-- Achievements for TTT using MetAchievements
if not MetAchievements then return end

local IsValid = IsValid
local playerIterator = player.Iterator

local convarDebug = CreateConVar("ttt_metachievements_debug", 0, FCVAR_UNREGISTERED)

local tag = "MetAchievements_TTT"

local unlockQueue = {}

local function debugPrint(...)
	if not convarDebug:GetBool() then return end

	MsgC(color_white, "[TTT-MetAchievements] Debug: ")
	print(...)
end

local function isRoundActive()
	return gameloop.GetRoundState() == ROUND_ACTIVE
end

local function setAchievementToUnlock(pl, id)
	local tab = unlockQueue[pl]

	if tab then
		tab[id] = true
	else
		unlockQueue[pl] = { [id] = true }
	end

	debugPrint("ACHIEVEMENT PENDING for", pl, id)
end

local function processAchievementUnlocks(pl, ids)
	for id in pairs(ids) do
		debugPrint("UNLOCKING ACHIEVEMENT for", pl, id)
		MetAchievements.UnlockAchievement(pl, id)
	end
end

hook.Add("TTTC4Disarm", tag, function(bomb, result, pl)
	-- Doesn't count if the defuser is a traitor or the one who planted the C4 because they always succeed no matter what
	if not result
		or pl:IsTraitor()
		or pl == bomb:GetOriginator()
		or not isRoundActive()
	then return end

	local timeRemaining = (bomb:GetArmTime() + bomb:GetTimerLength()) - CurTime() -- GetExplodeTime has been zero'd so we can't use that

	if timeRemaining <= 5 then
		setAchievementToUnlock(pl, "ttt_closedefuse")
	end
end)

hook.Add("TTTFoundDNA", tag, function(finder, toucher, ent)
	local scanner = finder:GetWeapon("weapon_ttt_wtester")
	if not IsValid(scanner) then return end

	if not istable(scanner.ItemSampleFinders) then
		scanner.ItemSampleFinders = {}
	end

	scanner.ItemSampleFinders[toucher] = finder
end)

hook.Add("TTT2OnTransferCredits", tag, function(sender, target, credits, isTargetDead)
	-- Credit sent to teammate
	if credits >= 1 and sender != target and sender:GetTeam() == target:GetTeam() then
		setAchievementToUnlock(sender, "ttt_sentcredit")
	end
end)

local fallItemClass, physItemClass = "item_ttt_nofalldmg", "item_ttt_nophysdmg"

hook.Add("TTT2OrderedEquipment", tag, function(pl, class)
	if pl:GetGroundEntity() == NULL and (class == fallItemClass or class == physItemClass) then
		pl._ach_boughtNoFallInAir = true
	end
end)

hook.Add("OnPlayerHitGround", "!" .. tag, function(pl, inWater, onFloater, speed)
	-- Fall damage resistance clutch-buy
	-- NOTE: Fall damage the player WOULD have taken is recalculated here to determine if the player would have died.
	--		 Ideally, we would use a stabler way of determining if the fall would have killed, but there isn't one.
	--		 Calculation code is copied from base TTT2's OnPlayerHitGround - if that updates, we need to update it here too, otherwise desync...
	if pl._ach_boughtNoFallInAir then
		pl._ach_boughtNoFallInAir = nil

		if not inWater
		and (pl:HasEquipmentItem(fallItemClass) or pl:HasEquipmentItem(physItemClass))
		and GetConVar("ttt2_falldmg_enable"):GetBool()
		then
			local minVel = GetConVar("ttt2_falldmg_min_velocity"):GetInt()
			if speed < minVel then return end

			local dmg = (0.05 * (speed - (minVel - 30))) ^ GetConVar("ttt2_falldmg_exponent"):GetFloat()

			if onFloater then
				dmg = dmg * 0.5
			end

			local ground = pl:GetGroundEntity()
			if IsValid(ground) and ground:IsPlayer() then
				dmg = dmg / 3
			end

			if math.floor(dmg) >= pl:Health() then
				setAchievementToUnlock(pl, "ttt_fallclutch")
			end
		end
	end
end)

hook.Add("PlayerTakeDamage", tag, function(pl, inflictor, attacker, amount)
	if pl.was_headshot
		and pl != attacker
		and IsValid(attacker)
		and attacker:IsPlayer()
		and IsValid(inflictor)
		and isRoundActive()
	then
		local brick = inflictor

		if brick:GetClass() == "weapon_ttt_brick" then
			brick = brick:GetParent()
		end

		if brick:GetClass() == "ttt_brick_proj"
			and brick.ThrownPos
			and brick.ThrownPos:DistToSqr(brick:WorldSpaceCenter()) >= (788 ^ 2) -- 788hu = ~20 meters
		then
			setAchievementToUnlock(attacker, "ttt_brickbonk")
		end
	end
end)

local lastTraitorKiller, lastInnocentKiller, traitorDied, traitorStartCount
local propDisguiseSightLimitSqr = 1500 ^ 2

hook.Add("DoPlayerDeath", tag, function(pl, attacker, dmgInfo)
	-- Don't attempt to track kills for achievements if: suicide, swapper was killed, no attacker, round isn't active
	if pl == attacker
		or pl:GetSubRole() == ROLE_SWAPPER
		or not IsValid(attacker)
		or not isRoundActive()
	then return end

	local inflictor = dmgInfo:GetInflictor()
	if IsValid(inflictor) then
		local isRecentlyDestroyedDoor = inflictor.isDoorProp and CurTime() <= (inflictor.doorDestructionEndTime or 0)

		local realAttacker = isRecentlyDestroyedDoor and IsValid(inflictor.doorDestroyer) and inflictor.doorDestroyer or attacker

		if realAttacker:IsPlayer() then
			local attackerTeam = realAttacker:GetTeam()
			local plTeam = pl:GetTeam()

			-- Store killer for tracking revenge
			pl._ach_killer = realAttacker

			-- Revenge kill
			if realAttacker._ach_revived
				and realAttacker._ach_killer == pl
				and plTeam != attackerTeam
				and plTeam != TEAM_NONE
			then
				setAchievementToUnlock(realAttacker, "ttt_revengekill")
			end

			-- Goomba stomp kill
			if inflictor == realAttacker and realAttacker:GetGroundEntity() == pl and dmgInfo:IsDamageType(DMG_CRUSH) then
				setAchievementToUnlock(realAttacker, "ttt_stompkill")

				-- Kill with broken down door
			elseif isRecentlyDestroyedDoor and inflictor.doorDestroyer == realAttacker then
				setAchievementToUnlock(realAttacker, "ttt_doorkill")

			else
				local infClass = inflictor:GetClass()

				-- Telefrag with the teleporter SWEP
				if infClass == "weapon_ttt_teleport" then
					setAchievementToUnlock(realAttacker, "ttt_teleporterkill")

					-- Multikill with a C4 as traitor
				elseif infClass == "weapon_ttt_c4" and attackerTeam == TEAM_TRAITOR and attackerTeam != plTeam then
					local count = realAttacker._ach_c4BlastKillsCount

					if CurTime() > (realAttacker._ach_c4BlastKillsStamp or 0) then
						realAttacker._ach_c4BlastKillsStamp = CurTime()
						count = 0
					end

					count = count + 1
					realAttacker._ach_c4BlastKillsCount = count

					if count == 4 then
						setAchievementToUnlock(realAttacker, "ttt_c4multikill")
					end
				end
			end

			-- Witness murder of teammate while using prop disguiser and avenge
			if istable(pl._ach_propWitnesses) then
				local expireTime = pl._ach_propWitnesses[realAttacker]

				if expireTime and CurTime() <= expireTime then
					setAchievementToUnlock(realAttacker, "ttt_propwitness")
				end
			end

			local attackerCenter
			for _, v in playerIterator() do
				if v == realAttacker
					or v == pl
					or v:GetTeam() != plTeam
					or not IsValid(v.PropDisguiserProp)
				then continue end

				if not attackerCenter then
					attackerCenter = realAttacker:WorldSpaceCenter()
				end

				local propCenter = v.PropDisguiserProp:WorldSpaceCenter()

				if attackerCenter:DistToSqr(propCenter) <= propDisguiseSightLimitSqr then
					local tr = util.TraceLine({
						start = attackerCenter,
						endpos = propCenter,
						mask = MASK_SOLID_BRUSHONLY
					})

					if not tr.Hit then
						if not istable(realAttacker._ach_propWitnesses) then
							realAttacker._ach_propWitnesses = {}
						end

						realAttacker._ach_propWitnesses[v] = CurTime() + 60
					end
				end
			end

			-- Scan DNA and kill target
			local scanner = realAttacker:GetWeapon("weapon_ttt_wtester")
			if IsValid(scanner) then
				local toucher = scanner.ItemSamples[scanner.ActiveSample]

				if toucher == pl then
					local finder = istable(scanner.ItemSampleFinders) and scanner.ItemSampleFinders[toucher] or nil

					if finder == realAttacker then
						setAchievementToUnlock(realAttacker, "ttt_dnadetective")
					end
				end
			end

			-- Store if any traitor has died this round
			if plTeam == TEAM_TRAITOR then
				traitorDied = true
			end

			-- Store round winning kill for innocents/traitors
			if attackerTeam == TEAM_INNOCENT then
				if plTeam == TEAM_TRAITOR then
					lastTraitorKiller = realAttacker
				end
			elseif attackerTeam == TEAM_TRAITOR then
				if plTeam == TEAM_INNOCENT then
					lastInnocentKiller = realAttacker
				end
			end
		end
	end
end)

hook.Add("PlayerSpawn", tag, function(pl)
	pl._ach_boughtNoFallInAir = nil

	-- Store whether this player was revived (ignore swapper "revives")
	if pl:IsActive() and pl:GetSubRole() != ROLE_SWAPPER then
		pl._ach_revived = true
	end
end)

hook.Add("TTTBeginRound", tag, function()
	traitorStartCount = 0

	for _, pl in playerIterator() do
		pl._ach_killer = nil
		pl._ach_revived = nil

		if pl:GetTeam() == TEAM_TRAITOR then
			traitorStartCount = traitorStartCount + 1
		end
	end
end)

hook.Add("TTTEndRound", tag .. "_UnlockQueue", function(result)
	-- Elderly wins
	if result != WIN_TIMELIMIT then
		-- Step 1: Track and award living Elderly players
		local winTeamForElderly

		for _, pl in playerIterator() do
			if pl:IsTerror() and pl:GetSubRole() == ROLE_ELDERLY then
				setAchievementToUnlock(pl, "ttt_elderlywin")
				winTeamForElderly = pl:GetTeam()
			end
		end

		-- Step 2: Award other players (dead and alive) on the same team as the living Elderly players
		if winTeamForElderly and winTeamForElderly != TEAM_NONE then
			for _, pl in playerIterator() do
				if pl:GetTeam() == winTeamForElderly and pl:GetSubRole() != ROLE_ELDERLY then
					setAchievementToUnlock(pl, "ttt_elderlywin")
				end
			end
		end
	end

	-- Final kill credits + Flawless traitor victory
	if result == TEAM_INNOCENT then
		if IsValid(lastTraitorKiller) then
			setAchievementToUnlock(lastTraitorKiller, "ttt_finalkillhero")
		end
	elseif result == TEAM_TRAITOR then
		if IsValid(lastInnocentKiller) then
			setAchievementToUnlock(lastInnocentKiller, "ttt_finalkillvillain")
		end

		if not traitorDied and (traitorStartCount or 0) >= 2 then
			for _, pl in playerIterator() do
				if pl:GetTeam() == TEAM_TRAITOR then
					setAchievementToUnlock(pl, "ttt_flawlesstraitors")
				end
			end
		end
	end

	lastTraitorKiller, lastInnocentKiller, traitorDied = nil, nil, nil

	-- Unlock achievements in the queue when the round ends - we don't want achievements popping mid-game and revealing information
	for pl, ids in pairs(unlockQueue) do
		if IsValid(pl) then
			processAchievementUnlocks(pl, ids)
		end
	end

	unlockQueue = {}
end)

hook.Add("PlayerDisconnected", tag .. "_UnlockQueue", function(pl)
	-- Unlock pending achievements for the disconnecting player
	local ids = unlockQueue[pl]

	if ids then
		processAchievementUnlocks(pl, ids)

		unlockQueue[pl] = nil
	end
end)