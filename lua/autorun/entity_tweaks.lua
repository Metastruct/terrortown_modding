-- Manual entity tweaks
-- Use this file to apply manual tweaks and fixes onto an entity, without having to overwrite said entity's entire lua file

require("hookextras")

util.OnInitialize(function()
	local ENT

	-- Magneto-stick: Allow for bigger camera turns while holding a prop without dropping it
	ENT = weapons.GetStored("weapon_zm_carry")
	if ENT then
		ENT.dropAngleThreshold = 0.925
	end

	-- Regular Knife: Increase damage and attack speed, remove the weird artifical attack delay on equip (DeploySpeed handles this anyway)
	ENT = weapons.GetStored("weapon_ttt_knife")
	if ENT then
		ENT.Primary.Damage = 75
		ENT.Primary.Delay = 0.75

		if SERVER then
			function ENT:Equip()
				if self:IsOnFire() then
					self:Extinguish()
				end

				if self:HasSpawnFlags(SF_WEAPON_START_CONSTRAINED) then
					local flags = self:GetSpawnFlags()
					local newflags = bit.band(self:GetSpawnFlags(), bit.bnot(SF_WEAPON_START_CONSTRAINED))

					self:SetKeyValue("spawnflags", newflags)
				end
			end
		end
	end

	if SERVER then
		-- Serverside only tweaks

		-- Jihad Bomb: Set explosion radius and disable damage behind walls
		-- PS: this is terrible unfortunately the developer of this weapon left no configuration possible...
		ENT = weapons.GetStored("weapon_ttt_jihad_bomb")
		if ENT then
			function ENT:Explode()
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

		-- Detective hat: Allow it to be possessed by spectators
		ENT = scripted_ents.GetStored("ttt_hat_deerstalker")
		if ENT then
			ENT = ENT.t

			ENT.AllowPropspec = true

			ENT.EquipTo_Original = ENT.EquipTo_Original or ENT.EquipTo

			function ENT:EquipTo(pl)
				-- If someone picks it up to wear it, kick out the possessor
				if PROPSPEC then
					local specOwner = self:GetNWEntity("spec_owner")

					if IsValid(specOwner) then
						PROPSPEC.End(specOwner)
					end
				end

				self:EquipTo_Original(pl)
			end
		end
	else
		-- Clientside only tweaks

		-- Kiss: Hide its weird heart model on players
		ENT = weapons.GetStored("weapon_ttt2_kiss")
		if ENT then
			function ENT:DrawWorldModel()
				if IsValid(self:GetOwner()) then return end
				self:DrawModel()
			end

			function ENT:DrawWorldModelTranslucent() end
		end
	end
end)
