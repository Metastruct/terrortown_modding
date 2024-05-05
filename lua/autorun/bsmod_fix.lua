local Tag = "bsmod_integration"

local convarMinHealth = GetConVar("bsmod_killmove_minhealth")

local function elligibleForKillMove(ply)
	if not IsValid(ply)
		or not ply:IsPlayer()
		or (CLIENT and ply == LocalPlayer())
		or not ply:Alive()
		or ply:Health() > convarMinHealth:GetInt()
	then
		return false
	end

	return true
end

if SERVER then
	AddCSLuaFile()

	hook.Add("InitPostEntity", Tag, function()
		local PLY = FindMetaTable("Player")

		PLY.old_KillMove = PLY.old_KillMove or PLY.KillMove
		if not PLY.old_KillMove then return end

		function PLY:KillMove(...)
			if not self:IsTerror() then return end

			PLY.old_KillMove(self, ...)
		end
	end)

	hook.Add("PlayerUse", Tag, function(ply, ent)
		if not _G.KMCheck then return end
		if not elligibleForKillMove(ent) then return end

		_G.KMCheck(ply)
	end)
else
	local RED_COLOR = Color(255,0,0)

	local convarGlow = GetConVar("bsmod_killmove_glow")

	hook.Add("TTTRenderEntityInfo", Tag, function(data)
		local ent = data:GetEntity()
		if not elligibleForKillMove(ent) then return end

		local dist = data:GetEntityDistance()
		if dist > 200 then return end

		if convarGlow then
			convarGlow:SetBool(false)
		end

		data:EnableText()
		data:EnableOutline()

		data:SetOutlineColor(RED_COLOR)
		data:AddDescriptionLine("Press [" .. input.LookupBinding("+use", true):upper() .. "] to FINISH them!")
	end)
end