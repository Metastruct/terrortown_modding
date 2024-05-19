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
end

if CLIENT then
	local RED_COLOR = Color(255, 0, 0)
	local convarGlow

	local function getConvarGlow()
		convarGlow = convarGlow or GetConVar("bsmod_killmove_glow")
		return convarGlow
	end

	local RELOAD_BIND = input.LookupBinding("bsmod_killmove")
	if not RELOAD_BIND then
		RELOAD_BIND = "\'bsmod_killmove\' IS NOT BOUND"
	else
		RELOAD_BIND = RELOAD_BIND:upper()
	end

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
		data:AddDescriptionLine("Press [" .. RELOAD_BIND .. "] to FINISH them!")
	end)
end