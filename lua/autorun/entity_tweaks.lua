-- Manual entity tweaks
-- Use this file to apply manual tweaks and fixes onto an entity, without having to overwrite said entity's entire lua file

require("hookextras")

if SERVER then
	AddCSLuaFile()
end

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

	-- Decoy: Allow people to carry 3 decoys at a time, and get 3 decoys when they buy them
	ENT = weapons.GetStored("weapon_ttt_decoy")
	if ENT then
		ENT.Primary.Ammo = "none"
		ENT.Primary.ClipSize = 3
		ENT.Primary.DefaultClip = 1

		if SERVER then
			function ENT:WasBought()
				self:SetClip1(self.Primary.ClipSize)
			end
		end
	end

	-- Identity Disguiser: Make disguiser invisible in hand and make user stand straight, add fire delays, hide PACs and steal outfitter models while in use
	ENT = weapons.GetStored("weapon_ttt_identity_disguiser")
	if ENT then
		ENT.HoldType = "normal"

		ENT.Primary.Delay = 0.1

		ENT.PrimaryAttack_Original = ENT.PrimaryAttack_Original or ENT.PrimaryAttack
		ENT.SecondaryAttack_Original = ENT.SecondaryAttack_Original or ENT.SecondaryAttack

		function ENT:PrimaryAttack()
			self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
			self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)

			self:PrimaryAttack_Original()
		end

		function ENT:SecondaryAttack()
			self:SetNextPrimaryFire(CurTime() + self.Secondary.Delay)
			self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)

			self:SecondaryAttack_Original()
		end

		if SERVER then
			local PLAYER = FindMetaTable("Player")

			PLAYER.ActivateDisguiserTarget_Original = PLAYER.ActivateDisguiserTarget_Original or PLAYER.ActivateDisguiserTarget
			PLAYER.DeactivateDisguiserTarget_Original = PLAYER.DeactivateDisguiserTarget_Original or PLAYER.DeactivateDisguiserTarget

			function PLAYER:ActivateDisguiserTarget()
				self:ActivateDisguiserTarget_Original()

				-- Ensure disguising actually took place before doing extra stuff
				if self.disguiserTargetActivated then
					if pac and pac.TogglePartDrawing then
						pac.TogglePartDrawing(self, false)
					end

					-- Funny feedback sound (only the user hears it)
					local filter = RecipientFilter()
					filter:AddPlayer(self)

					self:EmitSound("ambient/levels/citadel/pod_open1.wav", 100, 85, 0.75, CHAN_VOICE, 0, 0, filter)
				end
			end

			function PLAYER:DeactivateDisguiserTarget()
				local wasDisguised = self.disguiserTargetActivated

				self:DeactivateDisguiserTarget_Original()

				if pac and pac.TogglePartDrawing then
					pac.TogglePartDrawing(self, true)
				end

				-- Only play feedback sound if they were disguised
				if wasDisguised then
					local filter = RecipientFilter()
					filter:AddPlayer(self)

					self:EmitSound("ambient/levels/citadel/pod_close1.wav", 100, 85, 0.75, CHAN_VOICE, 0, 0, filter)
				end
			end
		else
			function ENT:DrawWorldModel(flags)
				local owner = self:GetOwner()

				if IsValid(owner) then return end

				self:DrawModel(flags)
			end

			-- Completely overwrite this net message with tweaks to handle outfitter (if it's present)
			if outfitter then
				net.Receive("TTT2ToggleDisguiserTarget", function()
					local addDisguise = net.ReadBool()
					local owner = net.ReadEntity()

					if not IsValid(owner) then return end

					if addDisguise then
						owner.disguiserTarget = net.ReadEntity()

						if IsValid(owner.disguiserTarget) then
							local mdl = owner.disguiserTarget.outfitter_mdl or owner.disguiserTarget:GetModel()

							owner.disguiserOriginalIsOutfitter = owner.outfitter_mdl != nil
							owner.disguiserOriginalModel = owner.outfitter_mdl or owner:GetModel()

							-- Clear any PAC outfits due to custom playermodels conflicting
							if owner == LocalPlayer() and pac and pace and pace.ClearParts then
								pace.ClearParts()

								chat.AddText(Color(255, 120, 120), "Your PAC has been cleared to avoid any playermodel conflicts with the Identity Disguiser. You can rewear your PAC once you're done.")
							end

							-- Use outfitter to enforce it because a simple SetModel isn't effective
							owner:EnforceModel(mdl)
						end
					else
						owner.disguiserTarget = nil

						if owner.disguiserOriginalModel then
							if owner.disguiserOriginalIsOutfitter then
								-- Enforce the owner's own outfitter model back
								owner:EnforceModel(owner.disguiserOriginalModel)
							else
								-- Stop enforcing, then try setting the regular model back
								owner:EnforceModel()
								owner:SetModel(owner.disguiserOriginalModel)
							end

							owner.disguiserOriginalIsOutfitter = nil
							owner.disguiserOriginalModel = nil

							if owner == LocalPlayer() and pac then
								chat.AddText(Color(150, 255, 150), "It's now safe to rewear your PAC.")
							end
						end
					end
				end)
			end
		end

		-- See client/voicehud_disguise.lua for the voicehud tweaks
	end

	-- Detective Toy Car: Change holdtype, remove jank driver damage application from this hook (damage is already dealt via another hook anyway)
	ENT = weapons.GetStored("weapon_ttt_detective_toy_car")
	if ENT then
		ENT.HoldType = "duel"

		if SERVER then
			hook.Add("EntityTakeDamage", "TTTDetectiveToyCarDamageMult", function(ent, dmg)
				if ent.IsDetectiveToyCar and isnumber(ent.DamageMult) then
					dmg:ScaleDamage(ent.DamageMult)
				end
			end)
		end
	end

	-- Silenced Pistol: Increase fire-rate and slightly increase accuracy, slightly decrease damage
	ENT = weapons.GetStored("weapon_ttt_sipistol")
	if ENT then
		ENT.Primary.Damage = 26
		ENT.HeadshotMultiplier = 2.65

		ENT.Primary.Delay = 0.3
		ENT.Primary.Cone = 0.0125
	end

	-- Medigun / Medic's Medigun: Re-enable use of lastinv
	ENT = weapons.GetStored("weapon_ttt_medigun")
	if ENT then
		function ENT:Deploy()
			return true
		end
	end
	ENT = weapons.GetStored("weapon_ttt2_medic_medigun")
	if ENT then
		function ENT:Deploy()
			return true
		end
	end

	-- SLAM: Make it use the c_ version of the SLAM viewmodel
	ENT = weapons.GetStored("weapon_ttt_slam")
	if ENT then
		ENT.ViewModel = "models/weapons/c_slam.mdl"
		ENT.UseHands = true
	end

	if SERVER then
		-- Serverside only tweaks

		-- No Fall Damage Item: Re-enable passthrough of fall damage when landing on players
		hook.Add("OnPlayerHitGround", "TTT2NoFallDmg", function(pl)
			if pl:Alive() and pl:IsTerror() and pl:HasEquipmentItem("item_ttt_nofalldmg") then
				local ground = pl:GetGroundEntity()

				if not IsValid(ground) or not ground:IsPlayer() then
					return false
				end
			end
		end)

		-- Jihad Bomb: Set explosion radius and disable damage behind walls
		-- PS: this is terrible unfortunately the developer of this weapon left no configuration possible...
		ENT = weapons.GetStored("weapon_ttt_jihad_bomb")
		if ENT then
			function ENT:Explode()
				local pos = self:GetPos()
				local dmg = 200
				local dmgowner = self:GetOwner()

				local r_outer = 320

				self:EmitSound("weapons/jihad_bomb/big_explosion.wav", 400, math.random(100, 125))

				-- Change body to a random charred body
				local model = "models/humans/charple0" .. math.random(1, 4) .. ".mdl"
				self:GetOwner():SetModel(model)

				-- Explosion damage
				util.BlastDamage(self, dmgowner, pos, r_outer, dmg)

				local effect = EffectData()
				effect:SetStart(pos)
				effect:SetOrigin(pos)
				effect:SetScale(r_outer)
				effect:SetRadius(r_outer)
				effect:SetMagnitude(dmg)
				util.Effect("Explosion", effect, true, true)

				-- Make sure the owner dies anyway
				if IsValid(dmgowner) and dmgowner:Alive() then
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

			-- These convars don't save and are created too late for cfg files to set them, execute them here...
			RunConsoleCommand("ttt_detective_hats_reclaim", "1")
			RunConsoleCommand("ttt_detective_hats_reclaim_any", "1")
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
