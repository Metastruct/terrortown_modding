if SERVER then
	AddCSLuaFile()

	util.OnInitialize(function()
		-- Fix vampire bat still showing PACs
		if PIGEON and pac and pac.TogglePartDrawing then
			PIGEON.EnableOriginal = PIGEON.EnableOriginal or PIGEON.Enable
			PIGEON.DisableOriginal = PIGEON.DisableOriginal or PIGEON.Disable

			PIGEON.Enable = function(pl)
				PIGEON.EnableOriginal(pl)

				pac.TogglePartDrawing(pl, false)
			end

			PIGEON.Disable = function(pl)
				PIGEON.DisableOriginal(pl)

				pac.TogglePartDrawing(pl, true)
			end
		end
	end)
else
	util.OnInitialize(function()
		-- Fix vampire bat bind not being created in the TTT2FinishedLoading hook by re-running it here
		local hookTable = hook.GetTable().TTT2FinishedLoading
		if hookTable and hookTable.TTTRoleVampireInit then
			hookTable.TTTRoleVampireInit()
		end
	end)
end