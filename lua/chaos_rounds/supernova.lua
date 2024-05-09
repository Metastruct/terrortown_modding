local ROUND = {}
ROUND.Name = "Super-nova"
ROUND.Description = "Every innocent explodes on death!"

function ROUND:Start()
	if SERVER then
		timer.Simple(1, function()
			for _, ply in pairs(player.GetAll()) do
				if ply ~= ROLE_INNOCENT then continue end

				ply:SetRole(ROLE_NOVA)
			end
		end)
	end

	if CLIENT then
		local ply = LocalPlayer()
		if ply:GetRole() == ROLE_INNOCENT then
			ply:SetRole(ROLE_NOVA)
		end
	end
end

function ROUND:Finish()
end

return ROUND