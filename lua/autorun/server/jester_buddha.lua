-- The Jester role gains buddha to certain damage types

if ROLE_JESTER then
	local buddhaDamageType = {
		[DMG_BURN] = true,
		[DMG_BLAST] = true
	}

	hook.Add("EntityTakeDamage", "TTTJesterBuddha", function(pl, dmg)
		if IsValid(pl) and
			pl:IsPlayer() and
			pl:GetRole() == ROLE_JESTER and
			buddhaDamageType[dmg:GetDamageType()] then

			local attacker = dmg:GetAttacker()

			if IsValid(attacker) and attacker:IsPlayer() then
				local dmg = math.floor(dmginfo:GetDamage())

				dmginfo:SetDamage(dmg)

				if dmg >= pl:Health() then
					pl:SetHealth(dmg + 1)
				end
			end
		end
	end)

end