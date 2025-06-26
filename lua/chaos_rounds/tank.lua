local ROUND = {}
ROUND.Name = "Tank!"
ROUND.Description = "What is that thing!? Take it out before it kills us all!"

local tankHookTag = "TTTL4DTank"
local tankNetTag = "TTTUpdateL4DTank"
local tankNwTag = "TTTIsL4DTank"
local tankVoiceNwTag = "TTTL4DTankNextVoiceLine"
local tankRockThrowNwTag = "TTTL4DTankRockThrowStart"
local tankHitSlowNwTag = "TTTL4DTankHitSlow"
local tankRespawnableNwTag = "TTTL4DTankRespawnable"

local tankModel = "models/infected/hulk_ttt.mdl"
local tankWeaponClass = "weapon_ttt_tankfists"

local convarTankMusicVol
local convarTankHealPercent

if SERVER then
	util.AddNetworkString(tankNetTag)

	-- Include all the tank stuff here instead of sprawling it around multiple files
	resource.AddFile("models/infected/hulk_ttt.mdl")
	resource.AddFile("models/infected/v_hulk_ttt.mdl")
	resource.AddSingleFile("materials/models/infected/hulk_ttt/hulk_01.vmt")
	resource.AddSingleFile("materials/models/infected/hulk_ttt/tank_color.vtf")
	resource.AddSingleFile("materials/models/infected/hulk_ttt/tank_normal.vtf")
	resource.AddSingleFile("materials/models/infected/hulk_ttt/v_hulk.vmt")
	resource.AddSingleFile("materials/models/infected/hulk_ttt/v_hulk_t.vmt")
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

	local convarTankHealthBase = CreateConVar("ttt_tank_health_base", 250, FCVAR_ARCHIVE + FCVAR_NOTIFY, "The Tank's base health for the Tank chaos round.", 0)
	local convarTankHealthScale = CreateConVar("ttt_tank_health_scaleperplayer", 500, FCVAR_ARCHIVE + FCVAR_NOTIFY, "The Tank's extra scaling health per player for the Tank chaos round.", 0)

	convarTankHealPercent = CreateConVar("ttt_tank_health_healperkill", 0.05, FCVAR_ARCHIVE + FCVAR_NOTIFY, "The percentage (0-1) of health the Tank heals back per kill during the Tank chaos round.", 0, 1)

	TTTTank = TTTTank or {}

	function TTTTank.TrySelectRandomTank()
		if IsValid(TTTTank.ChosenTank) then return end

		local activePlayers = {}
		for k, v in ipairs(player.GetAll()) do
			if v:IsTerror() then
				activePlayers[#activePlayers + 1] = v
			end
		end

		-- Temporary global variable
		TTTTank.ChosenTank = activePlayers[math.random(1, #activePlayers)]
	end

	function TTTTank.GetFarthestSpawnPosition(plTank)
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

		return bestSpawnPos
	end

	function TTTTank.StartBeingTank(pl)
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

			-- Failsafe for if the player had a custom MDL playermodel, otherwise they end up being INVISIBLE or a t-posing dude
			local timerName = tankNetTag .. tostring(pl:EntIndex())

			timer.Create(timerName, 0.25, 8, function()
				if IsValid(pl) then
					pl:SetModel(tankModel)
				else
					timer.Remove(timerName)
				end
			end)
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

		local newHP = convarTankHealthBase:GetInt() + (convarTankHealthScale:GetInt() * plMultiplier)
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

			plPhys:SetMass(250)
		end

		EPOP:AddMessage(pl,
			{ text = "You are the TANK!", color = Color(255, 125, 125) },
			"SMASH everything in your path.",
			5,
			true)

		net.Start(tankNetTag)
		net.WritePlayer(pl)
		net.WriteBool(true)
		net.WriteString(pl.l4dTankInfo.OldModel)
		net.Broadcast()
	end

	function TTTTank.StopBeingTank(pl)
		if not IsValid(pl) or not pl:GetNWBool(tankNwTag) then return end

		pl:SetNWBool(tankNwTag, false)

		if not pl.l4dTankInfo then return end

		pl:SetModel(pl.l4dTankInfo.OldModel)

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
			TTTTank.TrySelectRandomTank()

			local plTank = TTTTank.ChosenTank

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
	local convarTankMusicVolName = "ttt_tank_music_volume"

	convarTankMusicVol = CreateConVar(convarTankMusicVolName, 0.333, FCVAR_ARCHIVE, "Volume of the music played during the Tank chaos round.", 0, 1)

	cvars.AddChangeCallback(convarTankMusicVolName, function(_, old, new)
		if IsValid(TTTTankMusic) then
			local num = math.Clamp(tonumber(new) or 0, 0, 1)

			TTTTankMusic:SetVolume(num)
		end
	end, "autoupdate")

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

			-- If the localplayer is the tank and PAC is present, force any PAC outfits to be cleared - sorry but PAC causes too much bullshit :(
			if pl == LocalPlayer() and pac and pace and pace.ClearParts then
				pace.ClearParts()

				chat.AddText(
					Color(255, 60, 60), "NOTE: ",
					Color(255, 180, 180), "To avoid visual glitches as the Tank, any PACs you were wearing have been cleared.")
			end

			-- If outfitter is present, disable it on them and spam setting the model because outfitter loves to ignore SetModel for some time after
			if outfitter then
				pl:EnforceModel()

				local timerName = tankNetTag .. tostring(pl:EntIndex())

				timer.Create(timerName, 0, 80, function()
					if IsValid(pl) then
						pl:SetModel(tankModel)
					else
						timer.Remove(timerName)
					end
				end)
			end
		else
			if not pl.l4dTankInfo then return end

			-- If outfitter is present, set their model back to their chosen outfit
			if outfitter then
				timer.Remove(tankNetTag .. tostring(pl:EntIndex()))

				if pl.l4dTankInfo.UsingOutfitter then
					pl:EnforceModel(pl.l4dTankInfo.OldModel)
				else
					pl:EnforceModel()
				end
			end

			pl:SetModel(pl.l4dTankInfo.OldModel)

			pl.l4dTankInfo = nil

			if pl == LocalPlayer() and pac then
				chat.AddText(
					Color(255, 60, 60), "NOTE: ",
					Color(150, 255, 150), "Any PACs you were wearing before controlling the Tank were cleared. It is now safe to wear PACs again.")
			end
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
	[ACT_MP_STAND_IDLE]	= ACT_WALK,
	[ACT_MP_CROUCH_IDLE] = ACT_RUN_CROUCH,
	[ACT_MP_WALK] = ACT_WALK,
	[ACT_MP_CROUCHWALK] = ACT_RUN_CROUCH,
	[ACT_MP_RUN] = ACT_RUN,
	[ACT_MP_JUMP] = ACT_JUMP,
	[ACT_LAND] = ACT_FLINCH_STOMACH,
	[ACT_MP_ATTACK_STAND_PRIMARYFIRE] = ACT_RANGE_ATTACK1,
	[ACT_MP_ATTACK_CROUCH_PRIMARYFIRE] = ACT_RANGE_ATTACK1
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

			pl:EmitSound(footstepSounds[math.random(1, #footstepSounds)], 75, 100, vol, CHAN_AUTO, 0, 0, rf)
			return true
		end
	end)

	hook.Add("PlayerStepSoundTime", tankHookTag, function(pl, stepType, walking)
		if pl:GetNWBool(tankNwTag) then
			return stepType == STEPSOUNDTIME_ON_LADDER and 500 or ((walking or pl:Crouching()) and 375 or 250)
		end
	end)

	hook.Add("TranslateActivity", tankHookTag, function(pl, act)
		if pl:GetNWBool(tankNwTag) then
			return activityTranslations[act] or 1
		end
	end)

	hook.Add("CalcMainActivity", tankHookTag, function(pl, vel)
		if pl:GetNWBool(tankNwTag) then
			local rockThrowStart = pl:GetNWFloat(tankRockThrowNwTag)

			if rockThrowStart > 0 and CurTime() >= rockThrowStart then
				local progress = (CurTime() - rockThrowStart) * 0.44

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
		if pl:GetNWBool(tankNwTag) then
			if dmg:IsFallDamage() then
				-- Make Tank take half fall damage
				dmg:ScaleDamage(0.5)
			elseif pl:GetNWFloat(tankRockThrowNwTag) > 0 and pl != dmg:GetAttacker() then
				-- Give Tank damage resistance while throwing rocks
				dmg:ScaleDamage(0.5)
			end

			if dmg:IsDamageType(DMG_CLUB) then
				-- Make Tank take a lot more damage from melee attacks (CLUB is usually melee)
				dmg:ScaleDamage(4)
			end
		else
			local attacker = dmg:GetAttacker()

			if IsValid(attacker) and attacker:IsPlayer() and not attacker:GetNWBool(tankNwTag) then
				-- Reduce "friendly fire" damage between the terrorists
				dmg:ScaleDamage(0.25)
			end
		end
	end)

	hook.Add("TTTPlayerSpeedModifier", tankHookTag, function(pl, _, _, speedMultiplierModifier)
		if IsValid(pl) then
			if pl:GetNWBool(tankNwTag) then
				speedMultiplierModifier[1] = speedMultiplierModifier[1] * 1.12
			elseif pl:GetNWBool(tankHitSlowNwTag) then
				speedMultiplierModifier[1] = speedMultiplierModifier[1] * 0.66
			end
		end
	end)

	-- Disallow tanks from being mutated by PAC (ie. custom entity MDLs)
	hook.Add("PACMutateEntity", tankHookTag, function(owner, ent, mutatorClass)
		if IsValid(owner) and owner:IsPlayer() and owner:GetNWBool(tankNwTag) then
			return false
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

		hook.Add("PlayerCanPickupWeapon", tankHookTag, function(pl, wep, dropBlockingWeapon, isPickupProbe)
			if IsValid(pl) and pl:GetNWBool(tankNwTag) and IsValid(wep) and wep:GetClass() != tankWeaponClass then
				return false, 3
			end
		end)

		hook.Add("TTT2OnButtonUse", tankHookTag, function(pl, ent)
			if pl:GetNWBool(tankNwTag) then
				return false
			end
		end)

		hook.Add("TTT2PlayDeathScream", tankHookTag, function(data)
			if IsValid(data.victim) and data.victim:GetNWBool(tankNwTag) then
				return false
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
					timer.Create(timerName, 0.8, 1, function()
						if IsValid(pl) then
							pl:SetNWBool(tankHitSlowNwTag, false)
						end
					end)
				end
			end
		end)

		local triggerHurtClass = "trigger_hurt"
		local triggerHurtMax, triggerHurtAlertLimit, triggerHurtExpiry = 200, 250, 2

		hook.Add("EntityTakeDamage", tankHookTag, function(ent, dmg)
			if ent:IsPlayer() and ent:GetNWBool(tankNwTag) then
				if dmg:GetDamage() >= 3 then
					local now = CurTime()

					if now >= ent:GetNWFloat(tankVoiceNwTag) then
						ent:SetNWFloat(tankVoiceNwTag, now + 0.8)

						ent:EmitSound(hurtSounds[math.random(1, #hurtSounds)], 85, math.random(95, 101), 1, CHAN_VOICE2)
					end

					ent.TankAngryTime = now + 10
				end

				-- Handle trigger_hurt damage and giving the Tank an option to respawn
				local inflictor = dmg:GetInflictor()

				if IsValid(inflictor) and inflictor:GetClass() == triggerHurtClass then
					local clampedDmg = math.min(dmg:GetDamage(), triggerHurtMax)

					ent.TankTriggerDamageAccum = ((ent.TankTriggerDamageExpires and ent.TankTriggerDamageExpires >= CurTime()) and ent.TankTriggerDamageAccum or 0) + clampedDmg
					ent.TankTriggerDamageExpires = CurTime() + triggerHurtExpiry

					if ent.TankTriggerDamageAccum > triggerHurtAlertLimit then
						ent:SetNWBool(tankRespawnableNwTag, true)

						timer.Create(tankRespawnableNwTag .. tostring(ent:EntIndex()), triggerHurtExpiry, 1, function()
							if IsValid(ent) then
								ent:SetNWBool(tankRespawnableNwTag, false)
							end
						end)
					end

					dmg:SetDamage(clampedDmg)
				end
			end
		end)

		local killWordsList = {
			"slaughtering",
			"mauling",
			"obliterating",
			"smashing",
			"mutilating",
			"bloodying"
		}

		hook.Add("DoPlayerDeath", tankHookTag, function(pl)
			pl:SetNWBool(tankHitSlowNwTag, false)

			if pl:GetNWBool(tankNwTag) then
				pl:EmitSound(deathSounds[math.random(1, #deathSounds)], 85, math.random(95, 101), 1, CHAN_VOICE2)

				-- Default death sounds are removed by a TTT2PlayDeathScream hook
			else
				local plTank = TTTTank.ChosenTank
				if not IsValid(plTank) or not pl:IsTerror() then return end

				local rf = RecipientFilter()
				rf:AddPlayer(plTank)

				plTank:EmitSound("ui/littlereward.wav", 75, 100, 1, CHAN_AUTO, 0, 0, rf)

				local healMult = convarTankHealPercent:GetFloat()
				if healMult > 0 then
					local tankMaxHP = plTank:GetMaxHealth()
					plTank:SetHealth(math.min(math.ceil(plTank:Health() + (tankMaxHP * healMult)), tankMaxHP))

					LANG.Msg(plTank, string.format("You feel better after %s %s...", killWordsList[math.random(1, #killWordsList)], pl:Name()), nil, MSG_MSTACK_PLAIN)
				end
			end
		end)

		hook.Add("TTT2ModifyRagdollVelocity", tankHookTag, function(pl, rag, vel)
			-- If a player dies from a tank punch, pass the intended velocity to their corpse
			if pl.TankPunchedVelocity then
				vel.x = pl.TankPunchedVelocity.x
				vel.y = pl.TankPunchedVelocity.y
				vel.z = pl.TankPunchedVelocity.z
			end
		end)

		-- If for whatever reason a ragdoll of the tank is spawned (eg. tank is tased), disallow it from being picked up with the magneto-stick, plus make it heavier
		hook.Add("OnEntityCreated", tankHookTag, function(ent)
			if IsValid(ent) and ent:IsRagdoll() then
				timer.Simple(0, function()
					if IsValid(ent) and ent:GetModel() == tankModel then
						ent.CanPickup = false

						for i = 0, ent:GetPhysicsObjectCount() - 1 do
							local phys = ent:GetPhysicsObjectNum(i)

							if phys:IsValid() then
								phys:SetMass(250)
							end
						end
					end
				end)
			end
		end)

		-- Disallow Tanks from wearing PACs, but still let them clear PACs!
		hook.Add("PrePACConfigApply", tankHookTag, function(pl, data)
			if IsValid(pl) and pl:GetNWBool(tankNwTag) and data.part != "__ALL__" then
				return false, "to avoid visual glitches as the Tank, you can't wear PACs. You can once the round is over."
			end
		end)

		timer.Create(tankHookTag .. "_IdleVoice", 7.5, 0, function()
			local now = CurTime()

			for k, v in ipairs(player.GetAll()) do
				if v:GetNWBool(tankNwTag)
					and v:IsTerror()
					and now >= v:GetNWFloat(tankVoiceNwTag)
				then
					v:SetNWFloat(tankVoiceNwTag, now + 1.5)

					if now <= (v.TankAngryTime or 0) then
						v:EmitSound(yellSounds[math.random(1, #yellSounds)], 85, math.random(95, 101), 1, CHAN_VOICE2)
					else
						v:EmitSound(breatheSounds[math.random(1, #breatheSounds)], 75, math.random(95, 101), 0.8, CHAN_VOICE2)
					end
				end
			end
		end)

		-- Start initialising the tank
		TTTTank.TrySelectRandomTank()

		local plTank = TTTTank.ChosenTank
		local spawnPos = TTTTank.GetFarthestSpawnPosition(plTank) or plTank:GetPos()

		plTank:SetPos(spawnPos)

		TTTTank.StartBeingTank(plTank)

		local rf = RecipientFilter()
		rf:AddPlayer(plTank)

		plTank:EmitSound("ui/pickup_guitarriff10.wav", 75, 100, 1, CHAN_AUTO, 0, 0, rf)

		-- Spawn extra ammo from every ammo spawnpoint
		local ammoForTypes, ammo = WEPS.GetAmmoForSpawnTypes()
		entspawn.SpawnEntities(map.GetAmmoSpawns(), ammoForTypes, ammo, AMMO_TYPE_RANDOM)

		-- Spawn a free defib at a player spawnpoint
		if weapons.GetStored("weapon_ttt_defibrillator") then
			local plySpawns = plyspawn.GetPlayerSpawnPoints()

			local defib = ents.Create("weapon_ttt_defibrillator")
			if IsValid(defib) then
				defib:SetPos(plySpawns[math.random(1, #plySpawns)].pos + Vector(0, 0, 16))
				defib:Spawn()

				LANG.Msg(ROLE_INNOCENT, "There's a defibrillator on the floor somewhere!\nFind it for a better chance of survival!", nil, MSG_MSTACK_PLAIN)
			end
		end
	else
		-- Try preventing the invisible tanks issue with this hook
		hook.Add("NotifyShouldTransmit", tankHookTag, function(ent, transmit)
			if transmit and ent:IsPlayer() and ent:Alive() and ent:GetNWBool(tankNwTag) then
				ent:SetModel(tankModel)
				ent:SetNoDraw(false)
			end
		end)

		hook.Add("TTT2PreventAccessShop", tankHookTag, function(pl)
			if pl:GetNWBool(tankNwTag) then
				return true
			end
		end)

		local traitorButtonClass = "ttt_traitor_button"
		local infoClassBlacklist = {
			prop_ragdoll = true
		}

		local materialLMB = Material("vgui/ttt/hudhelp/lmb")
		local smashText, smashRed = "SMASH...", Color(255, 80, 80)

		hook.Add("TTTRenderEntityInfo", tankHookTag, function(tData)
			local pl = LocalPlayer()
			local ent = tData:GetEntity()

			if pl:GetNWBool(tankNwTag) and IsValid(ent) then
				if not ent:IsPlayer() and ent:GetClass() != traitorButtonClass then
					if tData.params.drawInfo then
						if ent:IsWeapon() or infoClassBlacklist[ent:GetClass()] then
							tData.params.drawInfo = false
							tData.params.drawOutline = false
						else
							if tData.params.displayInfo then
								if tData.params.displayInfo.key then
									tData.params.displayInfo.key = nil
									tData.params.displayInfo.icon = {}

									tData:AddIcon(materialLMB)
								end

								if tData.params.displayInfo.subtitle then
									tData:SetSubtitle(smashText, smashRed)
								end

								if tData.params.displayInfo.desc then
									tData.params.displayInfo.desc = {}
								end
							end
						end
					end
				end
			end
		end)

		sound.PlayFile("sound/infected/tank_bg.ogg", "noplay noblock", function(audio)
			if IsValid(audio) then
				audio:EnableLooping(true)
				audio:SetVolume(convarTankMusicVol and convarTankMusicVol:GetFloat() or 0.4)
				audio:Play()

				TTTTankMusic = audio
			end
		end)
	end
end

function ROUND:Finish()
	-- I have to delay the removal timer because funny latency I guess :)))
	timer.Simple(0.5, function()
		local removeTime = gameloop.GetPhaseEnd() - CurTime() - 0.5

		print("[TTTTank] Removing chaos round hooks in " .. tostring(removeTime) .. "s...")

		timer.Simple(removeTime, function()
			-- When the chaos round is over, remove all its logic when the next round is being prepared
			-- This allows people to mess around with the Tank a bit more when the round is over :)

			hook.Remove("PlayerFootstep", tankHookTag)
			hook.Remove("PlayerStepSoundTime", tankHookTag)
			hook.Remove("TranslateActivity", tankHookTag)
			hook.Remove("CalcMainActivity", tankHookTag)
			hook.Remove("SetupMove", tankHookTag)
			hook.Remove("ScalePlayerDamage", tankHookTag)
			hook.Remove("TTTPlayerSpeedModifier", tankHookTag)

			hook.Remove("PACMutateEntity", tankHookTag)

			if SERVER then
				hook.Remove("TTT2ModifyFinalRoles", tankHookTag)
				hook.Remove("TTT2CanOrderEquipment", tankHookTag)
				hook.Remove("TTTCanSearchCorpse", tankHookTag)

				hook.Remove("PlayerCanPickupWeapon", tankHookTag)
				hook.Remove("PlayerUse", tankHookTag)
				hook.Remove("TTT2OnButtonUse", tankHookTag)
				hook.Remove("OnPlayerHitGround", tankHookTag)
				hook.Remove("EntityTakeDamage", tankHookTag)
				hook.Remove("DoPlayerDeath", tankHookTag)
				hook.Remove("TTT2ModifyRagdollVelocity", tankHookTag)
				hook.Remove("OnEntityCreated", tankHookTag)

				hook.Remove("PrePACConfigApply", tankHookTag)

				timer.Remove(tankHookTag .. "_IdleVoice")

				-- Disable all tank related NW variables on all players
				for k, v in ipairs(player.GetAll()) do
					v:SetNWBool(tankHitSlowNwTag, false)

					TTTTank.StopBeingTank(v)
				end

				TTTTank.ChosenTank = nil
			else
				hook.Remove("NotifyShouldTransmit", tankHookTag)
				hook.Remove("TTT2PreventAccessShop", tankHookTag)
				hook.Remove("TTTRenderEntityInfo", tankHookTag)

				if IsValid(TTTTankMusic) then
					TTTTankMusic:Stop()
					TTTTankMusic = nil
				end
			end

			print("[TTTTank] Removed chaos round hooks")
		end)
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