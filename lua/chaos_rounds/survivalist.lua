local ROUND = {}
ROUND.Name = "Survivalist"

function ROUND:Start()
	if SERVER then
		for _, ply in pairs(player.GetAll()) do
			ply:SetMaxHealth(1)
			ply:SetHealth(1)
		end
	end
end

function ROUND:Finish()
	if SERVER then
		for _, ply in pairs(player.GetAll()) do
			ply:SetMaxHealth(100)
		end
	end
end