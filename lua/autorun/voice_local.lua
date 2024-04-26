local tag = "TTTVoiceLocal"

local cvarLocalVoiceEnable = CreateConVar("ttt_voice_local", "0", {FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED})
local cvarLocalVoiceRangeMin = CreateConVar("ttt_voice_local_range_min", "200", {FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED})
local cvarLocalVoiceRangeMax = CreateConVar("ttt_voice_local_range_max", "2500", {FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED})

if SERVER then
	local function CanHearVoiceChat(listener, speaker, teamVoice)
		if not teamVoice and GetRoundState() == ROUND_ACTIVE and listener:IsTerror() and speaker:IsTerror() then
			local maxDist = cvarLocalVoiceRangeMax:GetInt()

			return listener:GetPos():DistToSqr(speaker:GetPos()) < maxDist * maxDist, false
		end
	end

	cvars.AddChangeCallback("ttt_voice_local", function(name, oldVal, newVal)
		oldVal, newVal = tobool(oldVal), tobool(newVal)

		if oldVal == newVal then return end

		if newVal then
			hook.Add("TTT2CanHearVoiceChat", tag, CanHearVoiceChat)
		else
			hook.Remove("TTT2CanHearVoiceChat", tag)
		end
	end)

	if cvarLocalVoiceEnable:GetBool() then
		hook.Add("TTT2CanHearVoiceChat", tag, CanHearVoiceChat)
	end
else
	local inCirc = math.ease.InCirc

	local globalVoiceSuffix = "_gvoice"
	local resetIfDisabled = true

	local selfRoleDisabledTeamVoiceRecv, minDist, maxDist

	local function IsRoleChatting(pl)
	    local plTeam = pl:GetTeam()
	    local plRoleData = pl:GetSubRoleData()

	    selfRoleDisabledTeamVoiceRecv = selfRoleDisabledTeamVoiceRecv or LocalPlayer():GetSubRoleData().disabledTeamVoiceRecv

	    return not plRoleData.unknownTeam
	        and not plRoleData.disabledTeamVoice
	        and not selfRoleDisabledTeamVoiceRecv
	        and plTeam != TEAM_NONE
	        and not TEAMS[plTeam].alone
	        and not pl[plTeam .. globalVoiceSuffix]
	end

	local function VoiceScale(localPos, speakerPos)
		local dist = speakerPos:Distance(localPos) - minDist
		local scale = 1 - (dist / (maxDist - minDist))

		return inCirc(scale > 1 and 1 or (scale < 0 and 0 or scale))
	end

	hook.Add("PlayerStartVoice", tag, function(pl)
		if pl != LocalPlayer() then
			pl.VoiceChatting = true
		end
	end)

	hook.Add("PlayerEndVoice", tag, function(pl)
		pl.VoiceChatting = false
	end)

	hook.Add("Tick", tag, function()
		if not cvarLocalVoiceEnable:GetBool() then
			if resetIfDisabled then
				for k,v in ipairs(player.GetAll()) do
					v:SetVoiceVolumeScale(1)
				end

				resetIfDisabled = false
			end

			return
		end

		resetIfDisabled = true

		local pl = LocalPlayer()
		if not IsValid(pl) then return end

		local now = RealTime()
		local roundNotActive = GetRoundState() != ROUND_ACTIVE

		minDist, maxDist = cvarLocalVoiceRangeMin:GetInt(), cvarLocalVoiceRangeMax:GetInt()

		local plPos = pl:GetPos()

		for k,v in ipairs(player.GetAll()) do
			if v.VoiceChatting or (pl != v and now >= (v.VoiceChatNextTick or 0)) then
				local scale = (roundNotActive or not v:IsTerror() or IsRoleChatting(v))
					and 1
					or VoiceScale(plPos, v:GetPos())

				v:SetVoiceVolumeScale(scale)

				v.VoiceChatNextTick = now + 0.2
			end
		end

		selfRoleDisabledTeamVoiceRecv = nil
	end)
end