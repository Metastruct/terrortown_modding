-- Manual SWEP tweaks
-- Use this file to apply manual tweaks and fixes onto a weapon, without having to overwrite said weapon's entire lua file

local SWEP

-- Kiss: Make its weird heart model hidden on players)
if CLIENT then
	SWEP = weapons.GetStored("weapon_ttt2_kiss")
	if SWEP then
		function SWEP:DrawWorldModel()
			if IsValid(self:GetOwner()) then return end
			self:DrawModel()
		end

		function SWEP:DrawWorldModelTranslucent() end
	end
end

-- Medigun: Move the viewmodel out of the player's face (god, all of the medigun should be rewritten)
if CLIENT then
	SWEP = weapons.GetStored("weapon_ttt2_medic_medigun")
	if SWEP then
		function SWEP:GetViewModelPosition(pos, ang)
			local right = ang:Right()
			local up = ang:Up()
			local forward = ang:Forward()

			ang:RotateAroundAxis(forward, 85)
			ang:RotateAroundAxis(up, 96)

			pos = pos + 10 * right
			pos = pos + -12 * up
			pos = pos + 28 * forward

			return pos, ang
		end
	end
end