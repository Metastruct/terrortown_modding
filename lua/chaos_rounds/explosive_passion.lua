local ROUND = {}
ROUND.Name = "Explosive Passion"
ROUND.Description = "Everyone has been given a rigged c4. If anyone dies, their c4 will start counting down..."

local TAG = "ChaosRoundExplosivePassion"

if SERVER then
	function ROUND:OnPrepare()
		hook.Add("TTT2MetaModifyFinalRoles", TAG, function(role_map)
			for ply, role_id in pairs(role_map) do
				local role = roles.GetByIndex(role_id)
				if role and role.defaultTeam == "innocents" and roles.BOMBER then
					role_map[ply] = roles.BOMBER.id
				end
			end
		end)
	end

	function ROUND:Finish()
		hook.Remove("TTT2MetaModifyFinalRoles", TAG)
	end
end

if CLIENT then
	function ROUND:Start()
		if LocalPlayer():GetTeam() == "innocents" then
			LocalPlayer():SetRole(ROLE_BOMBER)
		end
	end
end

return RegisterChaosRound(ROUND)