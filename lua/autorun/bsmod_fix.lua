local TAG = "bsmod_integration"
local convarMinHealth

local function getConvarMinHealth()
	convarMinHealth = convarMinHealth or GetConVar("bsmod_killmove_minhealth")
	return convarMinHealth
end

local function elligibleForKillMove(ply)
	if GetRoundState and GetRoundState() ~= ROUND_ACTIVE then return false end
	if not IsValid(ply) or not ply:IsPlayer() or (CLIENT and ply == LocalPlayer()) or not ply:Alive() then return false end

	local convar = getConvarMinHealth()
	if convar and ply:Health() > convar:GetInt() then return false end

	return true
end

if SERVER then
	AddCSLuaFile()
	util.AddNetworkString(TAG)

	hook.Add("InitPostEntity", TAG, function()
		local PLY = FindMetaTable("Player")
		PLY.old_KillMove = PLY.old_KillMove or PLY.KillMove
		if not PLY.old_KillMove then return end

		function PLY:KillMove(...)
			if GetRoundState and GetRoundState() ~= ROUND_ACTIVE then return end
			if not self:IsTerror() then return end
			PLY.old_KillMove(self, ...)
		end
	end)

	local plys_pressing = {}
	net.Receive(TAG, function(_, ply)
		plys_pressing[ply] = true
		timer.Create(TAG, 1, 1, function()
			plys_pressing[ply] = nil
		end)
	end)

	hook.Add("Think", TAG, function()
		if not _G.KMCheck then return end
		for ply, _ in pairs(plys_pressing) do
			if not IsValid(ply) then
				plys_pressing[ply] = nil
				continue
			end

			local tr = ply:GetEyeTrace()
			if elligibleForKillMove(tr.Entity) then
				_G.KMCheck(ply)
			end
		end
	end)
end

if CLIENT then
	local RED_COLOR = Color(255, 0, 0)
	local convarGlow

	local function getConvarGlow()
		convarGlow = convarGlow or GetConVar("bsmod_killmove_glow")
		return convarGlow
	end

	local RELOAD_BIND = input.LookupBinding("+reload", true) or "unknown"
	hook.Add("TTTRenderEntityInfo", TAG, function(data)
		local ent = data:GetEntity()
		if not elligibleForKillMove(ent) then return end

		local dist = data:GetEntityDistance()
		if dist > 200 then return end

		local convar = getConvarGlow()
		if convar then
			convar:SetBool(false)
		end

		data:EnableText()
		data:EnableOutline()
		data:SetOutlineColor(RED_COLOR)
		data:AddDescriptionLine("Press [" .. RELOAD_BIND:upper() .. "] to FINISH them!")
	end)

	hook.Add("PlayerBindPress", TAG, function(_, bind)
		if bind ~= "+reload" then return end

		net.Start(TAG, true)
		net.SendToServer()
	end)
end