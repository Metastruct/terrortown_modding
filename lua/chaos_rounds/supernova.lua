local ROUND = {}
ROUND.Name = "Supernova"
ROUND.Description = "Every innocent explodes on death!"

if SERVER then
	function ROUND:OnPrepare()
		hook.Add("TTT2MetaModifyFinalRoles", TAG, function(role_map)
			for ply, role_id in pairs(role_map) do
				local role = roles.GetByIndex(role_id)
				if role and role.defaultTeam == "innocents" and roles.NOVA then
					role_map[ply] = roles.NOVA.id
				end
			end
		end)
	end
end

if CLIENT then
	function ROUND:Start()
		if LocalPlayer():GetTeam() == "innocents" then
			LocalPlayer():SetRole(ROLE_NOVA)
		end
	end
end

return RegisterChaosRound(ROUND)
