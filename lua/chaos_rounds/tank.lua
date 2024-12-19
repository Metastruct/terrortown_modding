local ROUND = {}
ROUND.Name = "Tank!"
ROUND.Description = "[BETA] What is that thing!? Take it out before it kills us all!"

local tankHookTag = "TTTL4DTank"
local tankNetTag = "TTTUpdateL4DTank"
local tankNwTag = "TTTIsL4DTank"
local tankVoiceNwTag = "TTTL4DTankNextVoiceLine"
local tankRockThrowNwTag = "TTTL4DTankRockThrowStart"
local tankModel = "models/infected/hulk.mdl"
local tankWeaponClass = "weapon_ttt_tankfists"

local tankHitSlowNwTag = "TTTL4DTankHitSlow"

if SERVER then
	util.AddNetworkString(tankNetTag)

	-- Include all the tank stuff here instead of sprawling it around multiple files
	resource.AddFile("models/infected/hulk.mdl")
	resource.AddFile("models/v_models/weapons/v_claw_hulk.mdl")
	resource.AddSingleFile("materials/models/infected/hulk_01.vmt")
	resource.AddSingleFile("materials/models/infected/tank_color.vtf")
	resource.AddSingleFile("materials/models/infected/tank_normal.vtf")
	resource.AddSingleFile("materials/models/v_models/infected/v_hulk.vmt")
	resource.AddSingleFile("materials/models/v_models/infected/v_hulk_t.vmt")
	resource.AddSingleFile("sound/infected/tank_bg.ogg")
	resource.AddSingleFile("sound/infected/tank_punch.ogg")
	resource.AddSingleFile("sound/infected/tank_rock_hit.ogg")
	resource.AddSingleFile("sound/infected/tank_rock_pickup.ogg")
	resource.AddSingleFile("sound/infected/tank_step1.ogg")
	resource.AddSingleFile("sound/infected/tank_step2.ogg")
	resource.AddSingleFile("sound/infected/tank_step3.ogg")
	resource.AddSingleFile("sound/infected/tank_step4.ogg")
	resource.AddSingleFile("sound/infected/tank_step5.ogg")
	resource.AddSingleFile("sound/infected/tank_step6.ogg")

	function TTTSelectRandomTank()
		if IsValid(TTTChosenTank) then return end

		local activePlayers = {}
		for k, v in ipairs(player.GetAll()) do
			if v:IsTerror() then
				activePlayers[#activePlayers + 1] = v
			end
		end

		-- Temporary global variable
		TTTChosenTank = activePlayers[math.random(1, #activePlayers)]
	end

	function TTTStartBeingTank(pl)
		if not IsValid(pl) or pl:GetNWBool(tankNwTag) then return end

		pl:SetNWBool(tankNwTag, true)

		pl.l4dTankInfo = {
			UsingOutfitter = pl.outfitter_mdl != nil,
			OldModel = pl.outfitter_mdl or pl:GetModel(),
			OldClimbSpeed = pl:GetLadderClimbSpeed()
		}

		pl:SetModel(tankModel)

		if pac and pac.TogglePartDrawing then
			pac.TogglePartDrawing(pl, false)
		end

		-- Stop Tank from being affected by karma
		pl:SetDamageFactor(1)

		-- Give only fists (drop any dropable weapons so other people can use them)
		for k, v in ipairs(pl:GetWeapons()) do
			if v.AllowDrop != false then
				pl:DropWeapon(v, nil, vector_origin)
			else
				v:Remove()
			end
		end

		pl:Give(tankWeaponClass)
		pl:SelectWeapon(tankWeaponClass)

		pl:GiveEquipmentItem("item_ttt_radar")

		-- Set HP based on the amount of active players
		local plMultiplier = 0
		for k, v in ipairs(player.GetAll()) do
			if v != pl and v:IsTerror() then
				plMultiplier = plMultiplier + 1
			end
		end

		local newHP = 500 + (2500 * plMultiplier)
		pl:SetMaxHealth(newHP)
		pl:SetHealth(newHP)

		pl:AddEFlags(EFL_NO_DAMAGE_FORCES)

		pl:SetLadderClimbSpeed(125)

		-- Hooking into TTT's targetid to not show nametags sucks, so reuse this special NWBool hehe
		pl:SetNWBool("disguised", true)

		-- Make Tank heavier so it can push props a little easier
		local plPhys = pl:GetPhysicsObject()
		if plPhys:IsValid() then
			pl.l4dTankInfo.OldMass = plPhys:GetMass()

			plPhys:SetMass(200)
		end

		net.Start(tankNetTag)
		net.WritePlayer(pl)
		net.WriteBool(true)
		net.WriteString(pl.l4dTankInfo.OldModel)
		net.Broadcast()
	end

	function TTTStopBeingTank(pl)
		if not IsValid(pl) or not pl:GetNWBool(tankNwTag) then return end

		pl:SetNWBool(tankNwTag, false)

		if not pl.l4dTankInfo then return end

		local oldModel = pl.l4dTankInfo.OldModel

		pl:SetModel(oldModel)

		-- For some reason, this needs to be done for clients to see them normally again
		timer.Simple(0.2, function()
			if IsValid(pl) then
				pl:SetModel(oldModel)
			end
		end)

		if pac and pac.TogglePartDrawing then
			pac.TogglePartDrawing(pl, true)
		end

		-- Just in case, set their karma damage scale back to what it should be
		KARMA.ApplyKarma(pl)

		pl:StripWeapons()

		pl:RemoveEquipmentItem("item_ttt_radar")

		pl:SetMaxHealth(100)
		pl:SetHealth(100)

		pl:RemoveEFlags(EFL_NO_DAMAGE_FORCES)

		pl:SetLadderClimbSpeed(pl.l4dTankInfo.OldClimbSpeed or 200)

		-- Turn off NWBool that hides nametags
		pl:SetNWBool("disguised", false)

		-- Restore mass
		local plPhys = pl:GetPhysicsObject()
		if plPhys:IsValid() then
			plPhys:SetMass(pl.l4dTankInfo.OldMass or 85)
		end

		pl.l4dTankInfo = nil

		net.Start(tankNetTag)
		net.WritePlayer(pl)
		net.WriteBool(false)
		net.Broadcast()
	end

	function ROUND:OnPrepare()
		hook.Add("TTT2ModifyFinalRoles", tankHookTag, function(roleMap)
			-- Call again here just in case (this will not override the already chosen tank)
			TTTSelectRandomTank()

			local plTank = TTTChosenTank

			local roleBlacklist = {}
			if roles.UNKNOWN then
				roleBlacklist[roles.UNKNOWN.id] = true
			end
			if roles.UNDECIDED then
				roleBlacklist[roles.UNDECIDED.id] = true
			end
			if roles.WRATH then
				roleBlacklist[roles.WRATH.id] = true
			end

			for pl, roleId in pairs(roleMap) do
				local role = roles.GetByIndex(roleId)

				if pl == plTank then
					roleMap[pl] = roles.TRAITOR.id
				else
					if role and (roleBlacklist[role.id] or (role.defaultTeam != "innocents" and role.defaultTeam != "nones")) then
						roleMap[pl] = roles.INNOCENT.id
					end
				end
			end
		end)
	end
else
	net.Receive(tankNetTag, function()
		local pl = net.ReadPlayer()
		local toggle = net.ReadBool()

		if not IsValid(pl) then return end

		if toggle then
			local oldModel = net.ReadString()

			pl.l4dTankInfo = {
				UsingOutfitter = pl.outfitter_mdl != nil,
				OldModel = oldModel
			}

			-- If outfitter is present, use it to ensure it overrides the user chosen outfit
			if outfitter then
				pl:SetModel(tankModel)
				pl:EnforceModel(tankModel)
			end
		else
			if not pl.l4dTankInfo then return end

			-- If outfitter is present, set their model back to their chosen outfit
			if outfitter then
				if pl.l4dTankInfo.UsingOutfitter then
					pl:EnforceModel(pl.l4dTankInfo.OldModel)
				else
					pl:EnforceModel()
				end
			end

			local oldModel = pl.l4dTankInfo.OldModel

			pl:SetModel(oldModel)

			pl.l4dTankInfo = nil
		end
	end)
end

local footstepSounds = {
	"infected/tank_step1.ogg",
	"infected/tank_step2.ogg",
	"infected/tank_step3.ogg",
	"infected/tank_step4.ogg",
	"infected/tank_step5.ogg",
	"infected/tank_step6.ogg"
}

local activityTranslations = {
	[ACT_MP_STAND_IDLE]	= 6,
	[ACT_MP_CROUCH_IDLE] = 12,
	[ACT_MP_WALK] = 6,
	[ACT_MP_CROUCHWALK] = 12,
	[ACT_MP_RUN] = 10,
	[ACT_MP_JUMP] = 30,
	[ACT_LAND] = 119
}

local climbUpSeqId, climbDownSeqId, throwSeqId

function ROUND:Start()
	hook.Add("PlayerFootstep", tankHookTag, function(pl, pos, foot, snd, vol)
		if pl:GetNWBool(tankNwTag) then
			local rf

			if SERVER then
				rf = RecipientFilter()

				rf:AddAllPlayers()
				rf:RemovePlayer(pl)

				if pl:Crouching() then
					util.ScreenShake(pl:GetPos(), 1.5, 10, 0.8, 300, true, rf)
				else
					util.ScreenShake(pl:GetPos(), 3, 10, 0.8, 750, true, rf)
				end
			elseif pl != LocalPlayer() then
				return
			end

			pl:EmitSound(footstepSounds[math.random(1, #footstepSounds)], 80, 100, vol, CHAN_AUTO, 0, 0, rf)
			return true
		end
	end)

	hook.Add("PlayerStepSoundTime", tankHookTag, function(pl, stepType, walking)
		if pl:GetNWBool(tankNwTag) then
			return stepType == STEPSOUNDTIME_ON_LADDER and 500 or (walking and 375 or 250)
		end
	end)

	hook.Add("TranslateActivity", tankHookTag, function(pl, act)
		if pl:GetNWBool(tankNwTag) then
			-- The attack animations keep changing activity IDs, so find the ID and add it to the list when loaded
			if not activityTranslations[ACT_MP_ATTACK_STAND_PRIMARYFIRE] and pl:GetModel() == tankModel then
				local id = pl:GetSequenceActivity(pl:LookupSequence("Attack_Moving"))

				activityTranslations[ACT_MP_ATTACK_STAND_PRIMARYFIRE] = id
				activityTranslations[ACT_MP_ATTACK_CROUCH_PRIMARYFIRE] = id
			end

			return activityTranslations[act] or 1
		end
	end)

	hook.Add("CalcMainActivity", tankHookTag, function(pl, vel)
		if pl:GetNWBool(tankNwTag) then
			local rockThrowStart = pl:GetNWFloat(tankRockThrowNwTag)

			if rockThrowStart > 0 and CurTime() >= rockThrowStart then
				local progress = (CurTime() - rockThrowStart) * 0.385

				if progress < 1 then
					pl:SetCycle(progress)

					if not throwSeqId then
						throwSeqId = pl:LookupSequence("Throw_04")
					end

					return 2137, throwSeqId
				else
					pl:SetNWFloat(tankRockThrowNwTag, 0)
				end
			elseif pl:GetMoveType() == MOVETYPE_LADDER then
				local velZ = vel.z

				pl:SetCycle(velZ != 0 and CurTime() % 1 or 0)

				if velZ > 0 then
					if not climbUpSeqId then
						climbUpSeqId = pl:LookupSequence("Ladder_Ascend")
					end

					return ACT_CLIMB_UP, climbUpSeqId
				else
					if not climbDownSeqId then
						climbDownSeqId = pl:LookupSequence("Ladder_Descend")
					end

					return ACT_CLIMB_DOWN, climbDownSeqId
				end
			end
		end
	end)

	hook.Add("SetupMove", tankHookTag, function(pl, mv, cm)
		if pl:GetNWBool(tankNwTag) and pl:GetNWFloat(tankRockThrowNwTag) > 0 then
			mv:SetForwardSpeed(0)
			mv:SetSideSpeed(0)
			mv:SetUpSpeed(0)

			cm:SetForwardMove(0)
			cm:SetSideMove(0)
			cm:SetUpMove(0)

			mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_JUMP + IN_DUCK)))
		end
	end)

	hook.Add("ScalePlayerDamage", tankHookTag, function(pl, _, dmg)
		-- Reduce "friendly fire" damage between the terrorists
		if not pl:GetNWBool(tankNwTag) then
			local attacker = dmg:GetAttacker()

			if IsValid(attacker) and attacker:IsPlayer() and not attacker:GetNWBool(tankNwTag) then
				dmg:ScaleDamage(0.25)
			end
		end
	end)

	hook.Add("TTTPlayerSpeedModifier", tankHookTag, function(pl, _, _, speedMultiplierModifier)
		if IsValid(pl) then
			if pl:GetNWBool(tankNwTag) then
				speedMultiplierModifier[1] = speedMultiplierModifier[1] * 1.1
			elseif pl:GetNWBool(tankHitSlowNwTag) then
				speedMultiplierModifier[1] = speedMultiplierModifier[1] * 0.5
			end
		end
	end)

	if SERVER then
		local breatheSounds = {
			"player/tank/voice/idle/tank_breathe_01.wav",
			"player/tank/voice/idle/tank_breathe_02.wav",
			"player/tank/voice/idle/tank_breathe_03.wav",
			"player/tank/voice/idle/tank_breathe_04.wav",
			"player/tank/voice/idle/tank_breathe_05.wav",
			"player/tank/voice/idle/tank_breathe_06.wav",
			"player/tank/voice/idle/tank_breathe_07.wav",
			"player/tank/voice/idle/tank_breathe_08.wav"
		}

		local yellSounds = {
			"player/tank/voice/yell/tank_yell_01.wav",
			"player/tank/voice/yell/tank_yell_02.wav",
			"player/tank/voice/yell/tank_yell_03.wav",
			"player/tank/voice/yell/tank_yell_04.wav",
			"player/tank/voice/yell/tank_yell_05.wav",
			"player/tank/voice/yell/tank_yell_06.wav",
			"player/tank/voice/yell/tank_yell_07.wav",
			"player/tank/voice/yell/tank_yell_08.wav",
			"player/tank/voice/yell/tank_yell_09.wav",
			"player/tank/voice/yell/tank_yell_10.wav",
			"player/tank/voice/yell/tank_yell_12.wav",
			"player/tank/voice/yell/tank_yell_16.wav"
		}

		local hurtSounds = {
			"player/tank/voice/pain/tank_pain_01.wav",
			"player/tank/voice/pain/tank_pain_02.wav",
			"player/tank/voice/pain/tank_pain_03.wav",
			"player/tank/voice/pain/tank_pain_04.wav",
			"player/tank/voice/pain/tank_pain_05.wav",
			"player/tank/voice/pain/tank_pain_06.wav",
			"player/tank/voice/pain/tank_pain_07.wav",
			"player/tank/voice/pain/tank_pain_08.wav",
			"player/tank/voice/pain/tank_pain_09.wav",
			"player/tank/voice/pain/tank_pain_10.wav"
		}

		local deathSounds = {
			"player/tank/voice/die/tank_death_01.wav",
			"player/tank/voice/die/tank_death_02.wav",
			"player/tank/voice/die/tank_death_03.wav",
			"player/tank/voice/die/tank_death_04.wav",
			"player/tank/voice/die/tank_death_05.wav",
			"player/tank/voice/die/tank_death_06.wav",
			"player/tank/voice/die/tank_death_07.wav"
		}

		hook.Add("TTT2CanOrderEquipment", tankHookTag, function(pl)
			if IsValid(pl) and pl:GetNWBool(tankNwTag) then
				return false
			end
		end)

		hook.Add("TTTCanSearchCorpse", tankHookTag, function(pl)
			if IsValid(pl) and pl:GetNWBool(tankNwTag) then
				return false
			end
		end)

		hook.Add("TTTCanUseTraitorButton", tankHookTag, function(pl)
			if IsValid(pl) and pl:GetNWBool(tankNwTag) then
				return false
			end
		end)

		hook.Add("PlayerCanPickupWeapon", tankHookTag, function(pl, wep, dropBlockingWeapon, isPickupProbe)
			if IsValid(pl) and pl:GetNWBool(tankNwTag) and IsValid(wep) and wep:GetClass() != tankWeaponClass then
				return false, 3
			end
		end)

		hook.Add("PlayerUse", tankHookTag, function(pl, ent)
			if pl:GetNWBool(tankNwTag) then
				return false
			end
		end)

		hook.Add("OnPlayerHitGround", tankHookTag, function(pl)
			if pl:GetNWBool(tankHitSlowNwTag) then
				local timerName = tankHitSlowNwTag .. tostring(pl:EntIndex())

				if not timer.Exists(timerName) then
					timer.Create(timerName, 1, 1, function()
						if IsValid(pl) then
							pl:SetNWBool(tankHitSlowNwTag, false)
						end
					end)
				end
			end
		end)

		hook.Add("EntityTakeDamage", tankHookTag, function(ent, dmg)
			if ent:IsPlayer() and ent:GetNWBool(tankNwTag) then
				if dmg:GetDamage() >= 3 then
					local now = CurTime()

					if now >= ent:GetNWFloat(tankVoiceNwTag) then
						ent:SetNWFloat(tankVoiceNwTag, now + 0.8)

						ent:EmitSound(hurtSounds[math.random(1, #hurtSounds)], 90, math.random(99, 101), 1, CHAN_VOICE2)
					end

					ent.TankAngryTime = now + 10
				end
			end
		end)

		hook.Add("DoPlayerDeath", tankHookTag, function(pl)
			pl:SetNWBool(tankHitSlowNwTag, false)

			if pl:GetNWBool(tankNwTag) then
				pl:EmitSound(deathSounds[math.random(1, #deathSounds)], 90, math.random(99, 101), 1, CHAN_VOICE2)

				-- This mutes the default death sounds
				pl.was_headshot = true
			end
		end)

		timer.Create(tankHookTag .. "_IdleVoice", 6, 0, function()
			local now = CurTime()

			for k, v in ipairs(player.GetAll()) do
				if v:GetNWBool(tankNwTag)
					and v:IsTerror()
					and now >= v:GetNWFloat(tankVoiceNwTag)
				then
					v:SetNWFloat(tankVoiceNwTag, now + 1.5)

					if now <= (v.TankAngryTime or 0) then
						v:EmitSound(yellSounds[math.random(1, #yellSounds)], 90, math.random(99, 101), 1, CHAN_VOICE2)
					else
						v:EmitSound(breatheSounds[math.random(1, #breatheSounds)], 80, math.random(99, 101), 0.8, CHAN_VOICE2)
					end
				end
			end
		end)

		-- Start initialising the tank
		TTTSelectRandomTank()

		local plTank = TTTChosenTank
		local tankPos = plTank:GetPos()

		-- Get the average of all player positions - what could possibly go wrong!!
		local plPosList = {}
		for k, v in ipairs(player.GetAll()) do
			if plTank != v and v:IsTerror() then
				plPosList[#plPosList + 1] = v:GetPos()
			end
		end

		local calcPos = { x = 0, y = 0, z = 0 }
		for k, v in ipairs(plPosList) do
			calcPos.x = calcPos.x + v.x
			calcPos.y = calcPos.y + v.y
			calcPos.z = calcPos.z + v.z
		end

		local averagePos = Vector(calcPos.x, calcPos.y, calcPos.z) / math.max(#plPosList, 1)

		-- Get the spawnpoint farthest away from the average position
		local bestSpawnPos
		local farthest = 0

		for k, v in ipairs(plyspawn.GetPlayerSpawnPoints()) do
			local dist = averagePos:DistToSqr(v.pos)

			if dist > farthest then
				bestSpawnPos = v.pos
				farthest = dist
			end
		end

		plTank:SetPos(bestSpawnPos)

		TTTStartBeingTank(plTank)

		local rf = RecipientFilter()
		rf:AddPlayer(plTank)

		plTank:EmitSound("ui/pickup_guitarriff10.wav", 75, 100, 1, CHAN_AUTO, 0, 0, rf)
	else
		hook.Add("TTT2PreventAccessShop", tankHookTag, function(pl)
			if pl:GetNWBool(tankNwTag) then
				return true
			end
		end)

		hook.Add("TTTRenderEntityInfo", tankHookTag, function(tData)
			local pl = LocalPlayer()
			local ent = tData:GetEntity()

			if pl:GetNWBool(tankNwTag) and IsValid(ent) and not ent:IsPlayer() then
				tData.params.drawInfo = false
			end
		end)

		sound.PlayFile("sound/infected/tank_bg.ogg", "noplay noblock", function(audio)
			if IsValid(audio) then
				audio:EnableLooping(true)
				audio:SetVolume(0.6)
				audio:Play()

				TTTTankMusic = audio
			end
		end)
	end
end

function ROUND:Finish()
	timer.Simple(gameloop.GetPhaseEnd() - CurTime() - 0.5, function()
		-- When the chaos round is over, remove all its logic when the next round is being prepared
		-- This allows people to mess around with the Tank a bit more when the round is over :)

		hook.Remove("PlayerFootstep", tankHookTag)
		hook.Remove("PlayerStepSoundTime", tankHookTag)
		hook.Remove("TranslateActivity", tankHookTag)
		hook.Remove("CalcMainActivity", tankHookTag)
		hook.Remove("SetupMove", tankHookTag)
		hook.Remove("ScalePlayerDamage", tankHookTag)
		hook.Remove("TTTPlayerSpeedModifier", tankHookTag)

		if SERVER then
			hook.Remove("TTT2ModifyFinalRoles", tankHookTag)
			hook.Remove("TTT2CanOrderEquipment", tankHookTag)
			hook.Remove("TTTCanSearchCorpse", tankHookTag)
			hook.Remove("TTTCanUseTraitorButton", tankHookTag)

			hook.Remove("PlayerCanPickupWeapon", tankHookTag)
			hook.Remove("PlayerUse", tankHookTag)
			hook.Remove("OnPlayerHitGround", tankHookTag)
			hook.Remove("EntityTakeDamage", tankHookTag)
			hook.Remove("DoPlayerDeath", tankHookTag)

			timer.Remove(tankHookTag .. "_IdleVoice")

			-- Disable all tank related NW variables on all players
			for k, v in ipairs(player.GetAll()) do
				v:SetNWBool(tankHitSlowNwTag, false)

				TTTStopBeingTank(v)
			end

			TTTChosenTank = nil
		else
			hook.Remove("TTT2PreventAccessShop", tankHookTag)
			hook.Remove("TTTRenderEntityInfo", tankHookTag)

			if IsValid(TTTTankMusic) then
				TTTTankMusic:Stop()
				TTTTankMusic = nil
			end
		end
	end)

	-- Fade out the music if it's there :)
	if CLIENT and IsValid(TTTTankMusic) then
		local initialVol = TTTTankMusic:GetVolume()
		local startTime = RealTime()

		hook.Add("Think", tankHookTag, function()
			if not IsValid(TTTTankMusic) then
				hook.Remove("Think", tankHookTag)
				return
			end

			local newVol = (1 - ((RealTime() - startTime) / 6)) * initialVol

			TTTTankMusic:SetVolume(newVol)

			if newVol <= 0 then
				TTTTankMusic:Stop()
				TTTTankMusic = nil
			end
		end)
	end
end

return RegisterChaosRound(ROUND)