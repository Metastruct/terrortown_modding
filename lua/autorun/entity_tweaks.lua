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
			ENT.ShowDefaultViewModel = false

			function ENT:DrawWorldModel(flags)
				if IsValid(self:GetOwner()) then return end
				self:DrawModel(flags)
			end

			-- Completely overwrite this net message with tweaks to handle outfitter (if it's present)
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

						if outfitter then
							-- Use outfitter to enforce it because a simple SetModel isn't effective
							owner:EnforceModel(mdl)
						else
							owner:SetModel(mdl)
						end

						-- Clear any PAC outfits due to custom playermodels conflicting
						if owner == LocalPlayer() and pac and pace and pace.ClearParts then
							pace.ClearParts()

							chat.AddText(Color(255, 120, 120), "Your PAC has been cleared to avoid any playermodel conflicts with the Identity Disguiser. You can rewear your PAC once you're done.")
						end
					end
				else
					owner.disguiserTarget = nil

					if owner.disguiserOriginalModel then
						if owner.disguiserOriginalIsOutfitter and outfitter then
							-- Enforce the owner's own outfitter model back
							owner:EnforceModel(owner.disguiserOriginalModel)
						else
							if outfitter then
								-- Stop enforcing, then try setting the regular model back
								owner:EnforceModel()
							end

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

		-- See client/hud_tweaks.lua for the voicehud tweaks
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

	-- Silenced Pistol: Increase fire-rate and slightly increase accuracy, slightly decrease overall damage, enable crit damage when shooting the back of heads
	ENT = weapons.GetStored("weapon_ttt_sipistol")
	if ENT then
		ENT.Primary.Damage = 26
		ENT.HeadshotMultiplier = 2.25

		ENT.Primary.Delay = 0.3
		ENT.Primary.Cone = 0.0125

		local pistolClass = ENT.ClassName
		local maxCritDistSqr = 512 ^ 2

		local function canCrit(owner, target)
			return owner:GetPos():DistToSqr(target:GetPos()) <= maxCritDistSqr and util.IsBehindAndFacingTarget(owner, target)
		end

		hook.Add("ScalePlayerDamage", pistolClass, function(target, hitGroup, dmgInfo)
			if hitGroup != HITGROUP_HEAD then return end

			local attacker = dmgInfo:GetAttacker()
			if not IsValid(attacker) or not attacker:IsPlayer() then return end

			local inflictor = dmgInfo:GetInflictor()
			if inflictor == attacker then
				inflictor = attacker:GetActiveWeapon()
			end

			if IsValid(inflictor)
				and inflictor:GetClass() == pistolClass
				and canCrit(attacker, target)
			then
				dmgInfo:ScaleDamage(2.5)
			end
		end)

		if CLIENT then
			ENT.EquipMenuData.desc = (ENT.EquipMenuData and ENT.EquipMenuData.desc or "") .. "\n\nShoot victims in the back of the head for critical damage."

			local critText = "CRIT DAMAGE!"

			local outer = 20
			local inner = 10

			hook.Add("TTTRenderEntityInfo", "HUDDrawTargetIDSilencedPistol", function(tData)
				local pl = LocalPlayer()
				if not IsValid(pl) or not pl:IsTerror() then return end

				local wep = pl:GetActiveWeapon()
				if not IsValid(wep) or wep:GetClass() != pistolClass then return end

				local ent = tData:GetEntity()
				if not ent:IsPlayer()
					or pl:GetEyeTraceNoCursor().HitGroup != HITGROUP_HEAD
					or not canCrit(pl, ent)
				then return end

				local roleColor = pl:GetRoleColor()

				-- Enable targetID rendering
				tData:EnableOutline()
				tData:SetOutlineColor(roleColor)

				tData:AddDescriptionLine(critText, roleColor)

				-- Draw crit damage marker
				local x, y = ScrW() * 0.5, ScrH() * 0.5

				surface.SetDrawColor(roleColor.r, roleColor.g, roleColor.b)

				surface.DrawLine(x - outer, y - outer, x - inner, y - inner)
				surface.DrawLine(x + outer, y + outer, x + inner, y + inner)

				surface.DrawLine(x - outer, y + outer, x - inner, y + inner)
				surface.DrawLine(x + outer, y - outer, x + inner, y - inner)
			end)
		end
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
			local takeDmgVar = "m_takedamage"
			local maxImpulse = 75 * 400

			ENT.ExplosionDamage = 200
			ENT.ExplosionRadius = 325
			ENT.ExplosionMaxBlockPercent = 0.75

			function ENT:Explode()
				local owner = self:GetOwner()
				local hasOwner = IsValid(owner)

				local pos = hasOwner and owner:WorldSpaceCenter() or self:GetPos()

				local dmg, radius, maxBlockPercent = self.ExplosionDamage, self.ExplosionRadius, self.ExplosionMaxBlockPercent

				local inWater = bit.band(util.PointContents(pos), MASK_WATER) != 0

				-- Change body to a random charred body
				if hasOwner then
					owner:SetModel("models/humans/charple0" .. math.random(1, 4) .. ".mdl")
				end

				-- Explosion damage - this is pretty much a port of Source's RadiusDamage function with some changes, mainly allowing some damage through walls
				local upPos = Vector(pos)
				upPos.z = upPos.z + 1

				local affectedEnts = ents.FindInSphere(upPos, radius)

				local trTab = {
					start = upPos,
					mask = MASK_SHOT - CONTENTS_HITBOX,
					filter = self
				}

				if hasOwner then
					trTab.filter = {self, owner}
				end

				for k, v in ipairs(affectedEnts) do
					if v == self
						or not IsValid(v)
						or (v:IsPlayer() and not v:IsTerror())
						or v:GetInternalVariable(takeDmgVar) == 0
						or v:WaterLevel() == (inWater and 0 or 3)
					then continue end

					local blockedDmgPercent = 0
					local entPos = v.BodyTarget and v:BodyTarget(upPos) or v:WorldSpaceCenter()

					local trNormal

					if v != owner then
						trTab.endpos = entPos

						local tr = util.TraceLine(trTab)
						local hitEnt = tr.Entity

						if tr.Hit
							and hitEnt != v
							and hitEnt != owner
						then
							if IsValid(hitEnt) then
								local phys = hitEnt:GetPhysicsObject()

								blockedDmgPercent = IsValid(phys)
									and math.min(phys:GetMass() / 350, 1) * maxBlockPercent
									or maxBlockPercent
							else
								blockedDmgPercent = maxBlockPercent
							end
						end

						trNormal = tr.Normal
					else
						trNormal = (entPos - upPos):GetNormalized()
					end

					local dist = v != owner and math.min(upPos:Distance(entPos), radius) or 0
					local dmgAmount = math.ceil(dmg * (1 - (dist / radius)) * (1 - blockedDmgPercent))

					if dmgAmount <= 0 then continue end

					local dmgInfo = DamageInfo()
					dmgInfo:SetDamage(dmgAmount)
					dmgInfo:SetDamageType(DMG_BLAST)
					dmgInfo:SetDamagePosition(upPos)
					dmgInfo:SetDamageForce(trNormal * math.min(dmgAmount * 300, maxImpulse))	 -- 300 (75 * 4) is the impulse value that Valve used
					dmgInfo:SetAttacker(hasOwner and owner or self)
					dmgInfo:SetInflictor(self)

					v:DispatchTraceAttack(dmgInfo, upPos, trNormal)
				end

				-- Do visual and sound effects
				local effect = EffectData()
				effect:SetStart(pos)
				effect:SetOrigin(pos)
				effect:SetScale(radius)
				effect:SetRadius(radius)
				effect:SetMagnitude(dmg)
				util.Effect("Explosion", effect, true, true)

				self:EmitSound("weapons/jihad_bomb/big_explosion.wav", 400, math.random(100, 125))

				util.ScreenShake(upPos, 60, 25, 1.5, radius + 200, true)
				util.PaintDown(upPos, "Scorch", trTab.filter)

				-- Make sure the owner dies anyway
				if hasOwner and owner:Alive() then
					owner:Kill()
				end

				self:Remove()
			end
		end

		-- All grenade projectiles: Disable air-drag for slightly better flight, following trajectory line more accurately
		local grenadeProjectileBaseClass = "ttt_basegrenade_proj"

		hook.Add("OnEntityCreated", "TTTGrenadesDisableAirdrag", function(ent)
			if not IsValid(ent) or ent.Base != grenadeProjectileBaseClass then return end

			timer.Simple(0, function()
				if not IsValid(ent) then return end

				local phys = ent:GetPhysicsObject()
				if IsValid(phys) then
					phys:EnableDrag(false)
				end
			end)
		end)

		-- All placeables: Allow placeables (like C4) to be attached to moveable entities
		-- Small edits and improvements made to base TTT2's ttt_base_placeable functions
		ENT = scripted_ents.GetStored("ttt_base_placeable")
		if ENT then
			ENT = ENT.t

			local downVec = Vector(0, 0, -16)
			local soundWeld = "weapons/c4/c4_plant.wav"

			local function RestorePhysics(ent)
				local phys = ent:GetPhysicsObject()

				if IsValid(phys) then
					phys:EnableMotion(true)
					phys:Wake()

					if ent.originalMass then
						phys:SetMass(ent.originalMass)
						ent.originalMass = nil
					end
				end
			end

			function ENT:WeldToSurface(stateWelding)
				self.stateWelding = stateWelding

				if stateWelding then
					local vecHitNormal = self:GetHitNormal()

					if vecHitNormal then
						local stickRotation = self:GetStickRotation()

						if stickRotation then
							self:SetAngles(vecHitNormal:Angle() + stickRotation)
						else
							self:SetAngles(vecHitNormal:Angle())
						end
					end

					local pos = self:GetPos()

					local ignore = player.GetAll()
					ignore[#ignore + 1] = self

					local tr = util.TraceEntity({
						start = pos,
						endpos = pos + downVec,
						filter = ignore,
						mask = MASK_SOLID + CONTENTS_DEBRIS,
					}, self)

					sound.Play(soundWeld, pos, 75)

					if tr.Hit and (IsValid(tr.Entity) or tr.HitWorld) then
						local phys = self:GetPhysicsObject()

						if IsValid(phys) then
							if tr.HitWorld then
								phys:EnableMotion(false)
							else
								self.originalMass = phys:GetMass()
								phys:SetMass(10)
							end
						end

						self.originalCanPickup = self.CanPickup

						self.CanPickup = false

						if tr.HitWorld then return end

						local weld = constraint.Weld(self, tr.Entity, 0, tr.PhysicsBone or 0, 0, true)

						if IsValid(weld) then
							weld.PlacedEntity = self
							weld:CallOnRemove("C4Weld", function(ent)
								local placed = ent.PlacedEntity
								if not IsValid(placed) then return end

								placed.CanPickup = placed.originalCanPickup

								placed.originalCanPickup = nil

								RestorePhysics(placed)
							end)
						else
							RestorePhysics(self)
						end
					end
				else
					constraint.RemoveConstraints(self, "Weld")
				end
			end

			function ENT:StickEntity(ply, rotationalOffset, angleCondition)
				ply:SetAnimation(PLAYER_ATTACK1)

				rotationalOffset = rotationalOffset or Angle(0, 0, 0)

				local pos = ply:GetShootPos()

				local ignore = player.GetAll()
				ignore[#ignore + 1] = self

				local tr = util.TraceLine({
					start = pos,
					endpos = pos + ply:GetAimVector() * 100,
					mask = MASK_SOLID + CONTENTS_DEBRIS,
					filter = ignore,
				})

				if not tr.Hit then return false end

				self:SetPos(tr.HitPos)
				self:SetOriginator(ply)
				self:Spawn()
				self:SetHitNormal(tr.HitNormal)

				if tr.HitNormal.x == 0 and tr.HitNormal.y == 0 and tr.HitNormal.z == 1 then
					rotationalOffset.yaw = rotationalOffset.yaw + ply:GetAngles().yaw + 180
				end

				if not angleCondition or math.abs(tr.HitNormal:Angle().pitch) >= angleCondition then
					self:SetStickRotation(rotationalOffset)
				end

				self:WeldToSurface(true)

				return true
			end
		end

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

		-- Destructible Doors: Allow weapons with SWEP.DoorDamageMultiplier to scale their damage done to doors
		hook.Add("EntityTakeDamage", "TTTDoorDamageMultiplier", function(ent, dmgInfo)
			if IsValid(ent) and (ent.isDoorProp or ent:IsDoor()) then
				local inflictor = dmgInfo:GetInflictor()

				if IsValid(inflictor) and isnumber(inflictor.DoorDamageMultiplier) then
					dmgInfo:ScaleDamage(inflictor.DoorDamageMultiplier)
				end
			end
		end)

		-- Destructible Doors: Make recently broken doors do extra damage to players (plus add data for achievement tracking)
		hook.Add("TTT2DoorDestroyed", "TTTDoorExtraInfo", function(doorProp, pl)
			doorProp.doorDestroyer = pl
			doorProp.doorDestructionEndTime = CurTime() + 2

			doorProp:SetPhysicsAttacker(pl, 2)
		end)
		hook.Add("PlayerTakeDamage", "TTTDoorExtraDamage", function(pl, inflictor, attacker, am, dmgInfo)
			if inflictor.isDoorProp and CurTime() <= (inflictor.doorDestructionEndTime or 0) then
				dmgInfo:ScaleDamage(3)
			end
		end)
	else
		-- Clientside only tweaks

		-- Teleporter: Hide its worldmodel when held
		ENT = weapons.GetStored("weapon_ttt_teleport")
		if ENT then
			function ENT:DrawWorldModel(flags)
				if IsValid(self:GetOwner()) then return end
				self:DrawModel(flags)
			end
		end

		-- Kiss: Hide its worldmodel (weird giant heart) when held
		ENT = weapons.GetStored("weapon_ttt2_kiss")
		if ENT then
			function ENT:DrawWorldModel(flags)
				if IsValid(self:GetOwner()) then return end
				self:DrawModel(flags)
			end

			function ENT:DrawWorldModelTranslucent() end
		end
	end
end)
