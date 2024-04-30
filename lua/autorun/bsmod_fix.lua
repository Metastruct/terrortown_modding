if SERVER then
	AddCSLuaFile()

	hook.Add("InitPostEntity", "BSModTakeDamage_fix", function()
		local PLY = FindMetaTable("Player")
		local old = PLY.old_KillMove or PLY.KillMove
		if not old then return end

		function PLY:KillMove(...)
			if not self:IsTerror() then return end

			old(self, ...)
		end
	end)
end

if CLIENT then
	local Tag = "bsmod_integration"

	local function elligibleForKillMove(ply)
		if not IsValid(ply) then return false end
		if not ply:IsPlayer() then return false end
		if ply == LocalPlayer() then return false end
		if not ply:Alive() then return false end
		if ply:Health() > GetConVar("bsmod_killmove_minhealth"):GetInt() then return false end

		return true
	end

	hook.Add("PlayerBindPress", Tag, function(ply, bind)
		if ply ~= LocalPlayer() then return end
		if bind ~= "+use" then return end

		local tr = ply:GetEyeTrace()
		if not elligibleForKillMove(tr.Entity) then return end

		ply:ConCommand("bsmod_killmove")
	end)

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