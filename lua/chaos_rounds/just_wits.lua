local ROUND = {}
ROUND.Name = "Just your Wits"
ROUND.Description = "No HUD this time."

if CLIENT then
	local hookName = "TTTChaosNoHUD"

	-- HUDPaints that are allowed through - only chat addons should be allowed really
	local hookNamesAllowed = {
		EasyChat = true,
		EasyChatBlur = true
	}

	local hudElementsAllowed = {
		CFPSPanel = true,
		CHudChat = true,
		CHudGMod = true,
		NetGraph = true,
		TTTTButton = true
	}

	local hudPaintStore = {}

	function ROUND:Start()
		-- Temporarily remove all custom HUDPaints except the whitelisted ones
		local hooksHudPaint = hook.GetTable().HUDPaint or {}

		for k, v in pairs(hooksHudPaint) do
			if hookNamesAllowed[k] then continue end

			hudPaintStore[k] = v

			hook.Remove("HUDPaint", k)
		end

		-- Hide all HUD except the whitelisted ones
		hook.Add("HUDShouldDraw", hookName, function(hud)
			if not hudElementsAllowed[hud] then return false end
		end)

		-- Remove custom DrawHUDs from held SWEPs
		hook.Add("PlayerSwitchWeapon", hookName, function(pl, old, new)
			if pl == LocalPlayer() and IsValid(new) and new.DrawHUD then
				new.DrawHUD = function() end
				new.DrawHUDBackground = function() end
			end
		end)

		local heldWep = LocalPlayer():GetActiveWeapon()

		if IsValid(heldWep) then
			heldWep.DrawHUD = function() end
			heldWep.DrawHUDBackground = function() end
		end
	end

	function ROUND:Finish()
		-- Restore custom HUDPaints
		for k, v in pairs(hudPaintStore) do
			hook.Add("HUDPaint", k, v)
		end

		hudPaintStore = {}

		-- Remove HUD hiding hooks
		hook.Remove("HUDShouldDraw", hookName)
		hook.Remove("PlayerSwitchWeapon", hookName)
	end
end

return RegisterChaosRound(ROUND)