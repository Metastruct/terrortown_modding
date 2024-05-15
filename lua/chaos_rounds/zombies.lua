local ROUND = {}
ROUND.Name = "Zombies"
ROUND.Description = "A virus spreads, kills claimed by traitors will be revived as zombies. Survive for 5 minutes!"

local TAG = "ChaosRoundsZombie"

if SERVER then
	util.AddNetworkString(TAG)

	local function make_zombie(ply)
		if not IsValid(ply) then return end
		if not ply:IsPlayer() then return end

		ply:SetRole(ROLE_ZOMBIE)
		ply:StripWeapons()

		ply:Give("weapon_ttt_zombie")
		ply:SetMaxHealth(50)
		ply:SetHealth(50)
		ply:SetArmor(0)
		ply:SetRunSpeed(400)

		net.Start(TAG)
		net.WriteEntity(ply)
		net.Broadcast()
	end

	function ROUND:Start()
		local end_time = CurTime() + 60 * 5
		SetRoundEnd(end_time)

		timer.Simple(1, function()
			SetRoundEnd(CurTime())

			for _, ply in ipairs(player.GetAll()) do
				if ply:GetRole() == ROLE_TRAITOR and ply:IsTerror() then
					make_zombie(ply)
				end
			end
		end)

		hook.Add("PlayerLoadout", TAG, function(ply)
			return true
		end)

		hook.Add("TTT2PostPlayerDeath", TAG, function(victim, _, attacker)
			SetRoundEnd(end_time) -- dont deviate from original round end

			if victim:GetRole() == ROLE_ZOMBIE then
				victim:Revive(15)
				return
			end

			if victim:GetRole() ~= ROLE_ZOMBIE and IsValid(attacker) and attacker:IsPlayer() and attacker:GetRole() == ROLE_ZOMBIE then
				victim:Revive(15, function(ply)
					make_zombie(ply)
				end)
			end
		end)

		hook.Add("PlayerCanPickupWeapon", TAG, function(ply)
			if ply:GetRole() == ROLE_ZOMBIE then return false end
		end)

		hook.Add("PlayerCanPickupItem", TAG, function(ply)
			if ply:GetRole() == ROLE_ZOMBIE then return false end
		end)

		hook.Add("TTTCheckForWin", TAG, function()
			local survivors = 0
			for _, ply in ipairs(player.GetAll()) do
				if not ply:IsTerror() then continue end
				if ply:GetRole() ~= ROLE_TRAITOR then
					survivors = survivors + 1
				end
			end

			if CurTime() > end_time and survivors > 0 then return WIN_INNOCENT end
			if end_time < CurTime() and survivors < 1 then return WIN_TRAITOR end

			return WIN_NONE
		end)
	end

	function ROUND:Finish()
		hook.Remove("PlayerLoadout", TAG)
		hook.Remove("TTT2PostPlayerDeath", TAG)
		hook.Remove("PlayerCanPickupWeapon", TAG)
		hook.Remove("PlayerCanPickupItem", TAG)
		hook.Remove("TTTCheckForWin", TAG)

		for _, ply in ipairs(player.GetAll()) do
			if ply:GetRole() == ROLE_ZOMBIE then
				ply:SetMaxHealth(100)
			end
		end
	end
end

if CLIENT then
	net.Receive(TAG, function()
		local ply = net.ReadEntity()
		ply:SetRole(ROLE_ZOMBIE)
	end)
end


return RegisterChaosRound(ROUND)
