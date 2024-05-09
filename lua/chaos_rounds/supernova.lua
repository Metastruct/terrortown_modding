local ROUND = {}
ROUND.Name = "Super-nova"
ROUND.Description = "Every innocent explodes on death!"

function ROUND:Start()
	timer.Simple(1, function()
		if SERVER then
			for _, ply in pairs(player.GetAll()) do
				if ply ~= ROLE_INNOCENT then continue end

				ply:SetRole(ROLE_NOVA)
			end
		end

		if CLIENT then
			local ply = LocalPlayer()
			if ply:GetRole() == ROLE_INNOCENT then
				ply:SetRole(ROLE_NOVA)
			end
		end
	end)
end

return ROUND