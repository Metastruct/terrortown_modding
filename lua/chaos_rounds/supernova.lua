local ROUND = {}
ROUND.Name = "Supernova"
ROUND.Description = "Every innocent explodes on death!"

if SERVER then
	function ROUND:OnPrepare()
		hook.Add("TTT2ModifyFinalRoles", TAG, function(role_map)
			for ply, role in pairs(role_map) do
				if ply:GetTeam() == "innocents" then
					role_map[ply] = roles.NOVA.id
				end
			end
		end)
	end
end

return RegisterChaosRound(ROUND)
