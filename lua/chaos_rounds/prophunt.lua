local ROUND = {}
ROUND.Name = "Prop Hunt"
ROUND.Description = "Everyone gets a prop disguiser!"

function ROUND:Start()
	if SERVER then
		for _, v in next, player.GetAll() do
			v:Give("weapon_ttt_propdisguiser")
		end
	end
end

return RegisterChaosRound(ROUND)
