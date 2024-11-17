-- Jester role tweaks (serverside only)

require("hookextras")

util.OnInitialize(function()
	if not ROLE_JESTER or not roles.JESTER then return end

	-- 1. Give Jester buddha to certain damage types
	local buddhaDamageTypes = {
		[DMG_BURN] = true,
		[DMG_BLAST] = true
	}

	local function shouldDamageTypeBuddha(dmgType)
		if buddhaDamageTypes[dmgType] then return true end

		for k in pairs(buddhaDamageTypes) do
			if bit.band(dmgType, k) != 0 then return true end
		end

		return false
	end

	-- "WTF why are you doing it in this hacky way???"
	-- Because there are other factors that further scale the final damage output after EntityTakeDamage and TTT's PlayerTakeDamage
	-- Inside GM:PlayerTakeDamage, this is the final step of the damage calculation, so to ensure the buddha calculation happens last, we append it here!
	if ARMOR then
		ARMOR.HandlePlayerTakeDamage_Original = ARMOR.HandlePlayerTakeDamage_Original or ARMOR.HandlePlayerTakeDamage

		function ARMOR:HandlePlayerTakeDamage(pl, infl, attacker, originalDmg, dmgInfo)
			-- Run the original ARMOR:HandlePlayerTakeDamage
			self:HandlePlayerTakeDamage_Original(pl, infl, attacker, originalDmg, dmgInfo)

			-- Now do the jester buddha calculations if needed
			if shouldDamageTypeBuddha(dmgInfo:GetDamageType())
			and pl:GetSubRole() == ROLE_JESTER
			and IsValid(attacker)
			and attacker:IsPlayer()
			and attacker != pl
			and attacker:GetSubRole() != ROLE_JESTER
			then
				local dmgFloor = math.floor(dmgInfo:GetDamage())

				dmgInfo:SetDamage(dmgFloor)

				if dmgFloor >= pl:Health() then
					pl:SetHealth(dmgFloor + 1)
				end
			end
		end
	else
		ErrorNoHalt("TTT's ARMOR table was not found! Jester Buddha won't be working!")
	end

	-- 2. Make Jester wins not count towards rounds played
	-- Override the Jester's CheckForWin hook to be able to make this happen at the right time
	-- Using any of the EndRound hooks is too late, since TTT checks if the map should change before calling any of those
	hook.Add("TTTCheckForWin", "JesterCheckWin", function()
		if roles.JESTER.shouldWin then
			roles.JESTER.shouldWin = false

			-- Additions to the hook go here - increase the round count by 1 just before the round ends (the count will then decrease as normal when the round actually changes)
			gameloop.DecreaseRoundsLeft(-1)

			return TEAM_JESTER
		end
	end)
end)