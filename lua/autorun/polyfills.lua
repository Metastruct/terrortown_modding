AddCSLuaFile()

if SERVER then
	if not _G.SetRoundEnd then
		if _G.gameloop and _G.gameloop.SetPhaseEnd then
			_G.SetRoundEnd = _G.gameloop.SetPhaseEnd
		else
			_G.SetRoundEnd = function()
				ErrorNoHalt("Unable to set round end, could not find needed polyfill")
			end
		end
	end
end