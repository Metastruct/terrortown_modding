-- Manual SWEP tweaks
-- Use this file to apply manual tweaks and fixes onto a weapon, without having to overwrite said weapon's entire lua file

util.OnInitialize(function()
	local SWEP

	-- Magneto-stick: Allow for bigger camera turns while holding a prop without dropping it
	SWEP = weapons.GetStored("weapon_zm_carry")
	if SWEP then
		SWEP.dropAngleThreshold = 0.925
	end

	-- H.U.G.E-249: Buff the DPS while trading a little bit of recoil for accuracy
	SWEP = weapons.GetStored("weapon_zm_sledge")
	if SWEP then
		SWEP.Primary.Damage = 10
		SWEP.Primary.Delay = 0.05
		SWEP.Primary.Cone = 0.066
		SWEP.Primary.Recoil = 2
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

	-- Kiss: Make its weird heart model hidden on players
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
end)