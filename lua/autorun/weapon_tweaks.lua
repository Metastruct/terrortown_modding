-- Manual SWEP tweaks
-- Use this file to apply manual tweaks and fixes onto a weapon, without having to overwrite said weapon's entire lua file

require("hookextras")

util.OnInitialize(function()
	local SWEP

	-- Magneto-stick: Allow for bigger camera turns while holding a prop without dropping it
	SWEP = weapons.GetStored("weapon_zm_carry")
	if SWEP then
		SWEP.dropAngleThreshold = 0.925
	end

	-- Jihad Bomb: Set explosion radius and disable damage behind walls
	-- PS: this is terrible unfortunately the developer of this weapon left no configuration possible...
	SWEP = weapons.GetStored("weapon_ttt_jihad_bomb")
	if SWEP then
		function SWEP:Explode()
			local pos = self:GetPos()
			local dmg = 200
			local dmgowner = self:GetOwner()

			local r_inner = 250
			local r_outer = r_inner * 1.15

			self:EmitSound("weapons/jihad_bomb/big_explosion.wav", 400, math.random(100, 125))

			-- change body to a random charred body
			local model = "models/humans/charple0" .. math.random(1, 4) .. ".mdl"
			self:GetOwner():SetModel(model)

			-- explosion damage
			util.BlastDamage(self, dmgowner, pos, r_outer, dmg)

			local effect = EffectData()
			effect:SetStart(pos)
			effect:SetOrigin(pos)
			effect:SetScale(r_outer)
			effect:SetRadius(r_outer)
			effect:SetMagnitude(dmg)
			util.Effect("Explosion", effect, true, true)

			-- make sure the owner dies anyway
			if (SERVER and IsValid(dmgowner) and dmgowner:Alive()) then
				dmgowner:Kill()
			end

			--BurnOwnersBody(model)
			self:Remove()
		end
	end

	if SERVER then
		-- Serverside only tweaks

		-- All grenade projectiles: Disable air-drag for slightly better flight, following trajectory line more accurately
		local grenadeProjectileBaseClass = "ttt_basegrenade_proj"

		hook.Add("OnEntityCreated", "TTTGrenadesDisableAirdrag", function(ent)
			if not IsValid(ent) or ent.Base ~= grenadeProjectileBaseClass then return end

			timer.Simple(0, function()
				if not IsValid(ent) then return end

				local phys = ent:GetPhysicsObject()
				if IsValid(phys) then
					phys:EnableDrag(false)
				end
			end)
		end)
	else
		-- Clientside only tweaks

		-- Kiss: Hide its weird heart model on players
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
