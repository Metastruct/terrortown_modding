local TAG = "use_voice_goddamnit"

if CLIENT then
	local VOICE_ENABLE = GetConVar("voice_enable")
	local VOLUME = GetConVar("volume")
	local VOICE_SCALE = GetConVar("voice_scale")
	local RED_COLOR = Color(255, 0, 0, 255)

	local function has_voice_enabled()
		if not VOICE_ENABLE or not VOLUME or not VOICE_SCALE then return true end --- uuuhhhh
		if VOICE_ENABLE:GetBool() and VOLUME:GetFloat() > 0 and VOICE_SCALE:GetFloat() > 0 then return true end -- good boy :)

		return false
	end

	local PLY = FindMetaTable("Player")
	function PLY:HasVoiceEnabled()
		return has_voice_enabled()
	end

	local warned = false
	local function on_voice_state_update(enabled)
		net.Start(TAG)
		net.WriteBool(enabled)
		net.SendToServer()

		if not enabled and not warned then
			chat.AddText(RED_COLOR, "[WARN] TTT is a gamemode better played using voice & sound. Because you have those disabled you will automatically be moved to spectators.")
			warned = true
		end

		hook.Run("PlayerVoiceStateChanged", LocalPlayer(), enabled)
	end

	local voice_state = nil
	local next_check = 0
	hook.Add("Think", "use_voice_goddamnit", function()
		if CurTime() < next_check then return end

		local cur_voice_state = has_voice_enabled()
		if cur_voice_state ~= voice_state then
			voice_state = cur_voice_state
			on_voice_state_update(voice_state)
		end

		next_check = CurTime() + 2
	end)
end

if SERVER then
	util.AddNetworkString(TAG)

	local player_voice_states = {}
	net.Receive(TAG, function(_, ply)
		local cur_state = net.ReadBool()
		if player_voice_states[ply] ~= cur_state then
			player_voice_states[ply] = cur_state

			hook.Run("PlayerVoiceStateChanged", ply, cur_state)
		end
	end)

	local PLY = FindMetaTable("Player")
	function PLY:HasVoiceEnabled()
		if player_voice_states[self] ~= nil then
			return player_voice_states[self]
		end

		return true -- by default assume its enabled
	end

	hook.Add("PlayerDisconnected", TAG, function(ply)
		player_voice_states[ply] = nil
	end)

	local function make_spectator(ply)
		if ply:IsGhost() then
			ply:SetForceSpec(true)

			return
		end

		if not ply:IsSpec() then
			ply:Kill()
		end

		GAMEMODE:PlayerSpawnAsSpectator(ply)
		ply:SetTeam(TEAM_SPEC)
		ply:SetForceSpec(true)
		ply:Spawn()
		ply:SetRagdollSpec(false)
	end

	hook.Add("TTTPrepareRound", TAG, function()
		for _, ply in ipairs(player.GetAll()) do
			if ply:IsSpec() then continue end
			if ply:HasVoiceEnabled() then continue end

			make_spectator(ply)
		end
	end)

	hook.Add("PlayerVoiceStateChanged", TAG, function(ply, enabled)
		if not enabled and ply:IsTerror() then
			make_spectator(ply)
		else
			ply:SetForceSpec(false)
		end
	end)
end