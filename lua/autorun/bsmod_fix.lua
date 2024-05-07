local Tag = "bsmod_integration"
local function elligibleForKillMove(ply)
	if GetRoundState and GetRoundState() ~= ROUND_ACTIVE then return false end
	if not IsValid(ply) then return false end
	if not ply:IsPlayer() then return false end

	if CLIENT and ply == LocalPlayer() then return false end

	if not ply:Alive() then return false end
	if ply:Health() > GetConVar("bsmod_killmove_minhealth"):GetInt() then return false end

	return true
end

if SERVER then
	AddCSLuaFile()

	hook.Add("InitPostEntity", Tag, function()
		local PLY = FindMetaTable("Player")
		PLY.old_KillMove = PLY.old_KillMove or PLY.KillMove
		if not PLY.old_KillMove then return end

		function PLY:KillMove(...)
			if GetRoundState and GetRoundState() ~= ROUND_ACTIVE then return end
			if not self:IsTerror() then return end

			PLY.old_KillMove(self, ...)
		end
	end)

	hook.Add("PlayerUse", Tag, function(ply, ent)
		if not _G.KMCheck then return end
		if not elligibleForKillMove(ent) then return end

		_G.KMCheck(ply)
	end)
end

if CLIENT then
	local RED_COLOR = Color(255,0,0)
	hook.Add("TTTRenderEntityInfo", Tag, function(data)
		local ent = data:GetEntity()
		if not elligibleForKillMove(ent) then return end

		local dist = data:GetEntityDistance()
		if dist > 200 then return end

		local glow_cvar = GetConVar("bsmod_killmove_glow")
		if glow_cvar then
			glow_cvar:SetBool(false)
		end

		data:EnableText()
		data:EnableOutline()

		data:SetOutlineColor(RED_COLOR)
		data:AddDescriptionLine("Press [" .. input.LookupBinding("+use", true):upper() .. "] to FINISH them!")
	end)
end