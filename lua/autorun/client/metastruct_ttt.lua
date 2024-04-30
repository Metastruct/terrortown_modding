local Tag = "msttt"
hook.Add("WebBrowserF1", Tag, function() return false end)

do
	local function elligibleForKillMove(ply)
		if not IsValid(ply) then return false end
		if not ply:IsPlayer() then return false end
		if ply == LocalPlayer() then return false end
		if not ply:Alive() then return false end
		if ply:Health() > GetConVar("bsmod_killmove_minhealth"):GetInt() then return false end

		return true
	end

	hook.Add("PlayerBindPress", Tag .. "bsmod_integration", function(ply, bind)
		if ply ~= LocalPlayer() then return end
		if bind ~= "+use" then return end

		local tr = ply:GetEyeTrace()
		if not elligibleForKillMove(tr.Entity) then return end

		ply:ConCommand("bsmod_killmove")
	end)

	local RED_COLOR = Color(255,0,0)
	hook.Add("TTTRenderEntityInfo", Tag .. "bsmod_integration", function(data)
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