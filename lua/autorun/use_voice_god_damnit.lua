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

	hook.Add("Initialize", TAG, function()
		timer.Create(TAG, 10, 5, function()
			local has_voice = has_voice_enabled()
			if has_voice then return end
			chat.AddText(RED_COLOR, "[WARN] TTT is a gamemode better played using voice & sound. Because you have those disabled you have been moved to spectators. Use the menu or type 'ttt_spectator_mode 0' in console to leave spectator.")
			RunConsoleCommand("ttt_spectator_mode", '1')
		end)
	end)
end
