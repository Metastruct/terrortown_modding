local ROUND = {}
ROUND.Name = "Just Fucking Pirates"
ROUND.Description = "Everyone gets a blunderbuss!"

function ROUND:Start()
	if SERVER then
		for _, v in next, player.GetAll() do
			v:Give("weapon_ttt_blunderbuss")
		end
	end
end

return ROUND
