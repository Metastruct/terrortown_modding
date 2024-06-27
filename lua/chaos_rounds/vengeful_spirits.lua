local ROUND = {}
ROUND.Name = "Vengeful Spirits"
ROUND.Description = "Dead people can possess the living."

if SERVER then
	function ROUND:Start()
		for _, ply in pairs(player.GetAll()) do
			if not ply:IsTerror() then continue end

			ply:GiveEquipmentItem("item_demonic_possession")
		end
	end
end

--return RegisterChaosRound(ROUND)