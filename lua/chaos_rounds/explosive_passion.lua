local ROUND = {}
ROUND.Name = "Explosive Passion"
ROUND.Description = "Everyone has been given a rigged c4. If anyone dies, their c4 will start counting down..."

local TAG = "ChaosRoundExplosivePassion"

if SERVER then
	function ROUND:Start()
		hook.Add("TTT2PostPlayerDeath", TAG, function(ply)
			local c4 = ents.Create("ttt_c4")
			c4:SetPos(ply:EyePos() + Vector(0, 0, 10))
			c4:Spawn()
			c4:DropToFloor()

			c4:Arm(ply, 5) -- 5 seconds
			c4:SetRadius(300) -- reduce radius
			c4:SetRadiusInner(150)

			function c4:Defusable() return false end -- no defuse
			function c4:Disarm() return false end
			function c4:ShowC4Config() return false end
		end)
	end

	function ROUND:Finish()
		hook.Remove("TTT2PostPlayerDeath", TAG)
	end
end

return RegisterChaosRound(ROUND)