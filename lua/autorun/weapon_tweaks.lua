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

	-- FAMAS: Change to intermediate ammo
	SWEP = weapons.GetStored("weapon_ttt_famas")
	if SWEP then
		SWEP.Primary.Ammo = "smg1"
	end

	-- M-16: Change to intermediate ammo
	SWEP = weapons.GetStored("weapon_ttt_m16")
	if SWEP then
		SWEP.Primary.Ammo = "smg1"
	end

	-- MAC-10: Change to pistol ammo
	SWEP = weapons.GetStored("weapon_zm_mac10")
	if SWEP then
		SWEP.Primary.Ammo = "pistol"
	end

	-- H.U.G.E-249: Buff DPS while trading a little bit of recoil for accuracy
	SWEP = weapons.GetStored("weapon_zm_sledge")
	if SWEP then
		SWEP.Primary.Damage = 10
		SWEP.Primary.Delay = 0.05
		SWEP.Primary.Cone = 0.066
		SWEP.Primary.Recoil = 2
	end

	-- G3SG1: Nerf the headshot damage, 4x is already insane
	SWEP = weapons.GetStored("weapon_ttt_g3sg1")
	if SWEP then
		SWEP.HeadshotDamage = 3
	end

	-- SG 550: Nerf the headshot damage, 4x is already insane
	SWEP = weapons.GetStored("weapon_ttt_sg550")
	if SWEP then
		SWEP.HeadshotDamage = 2.9
	end

	-- SG 552: Tweak DPS, but allow it to be a lot more viable at range
	SWEP = weapons.GetStored("weapon_ttt_sg552")
	if SWEP then
		SWEP.Primary.Damage = 19
		SWEP.Primary.Delay = 0.13
		SWEP.Primary.Cone = 0.0075
		SWEP.Primary.Recoil = 1.05
		SWEP.HeadshotMultiplier = 2.5
	end

	-- AUG: Make it more viable at range
	SWEP = weapons.GetStored("weapon_ttt_aug")
	if SWEP then
		SWEP.Primary.Cone = 0.012
		SWEP.Primary.Recoil = 1
	end

	-- Auto Shotgun: Decrease damage, shoot one extra pellet, increase fire-rate, slightly widen accuracy cone
	SWEP = weapons.GetStored("weapon_zm_shotgun")
	if SWEP then
		-- This damage sounds terrible on paper, but for some reason it does a lot more damage in-game so it's okay
		SWEP.Primary.Damage = 6
		SWEP.Primary.NumShots = 9
		SWEP.Primary.Delay = 0.75
		SWEP.Primary.Cone = 0.088

		-- Rename it to the auto shotgun to avoid confusion
		if CLIENT then
			SWEP.PrintName = "Auto Shotgun"
		end
	end

	-- Pump Shotgun: Decrease damage, shoot one extra pellet
	SWEP = weapons.GetStored("weapon_ttt_pump")
	if SWEP then
		SWEP.Primary.Damage = 11
		SWEP.Primary.NumShots = 9
	end

	-- S&W 500: Set accuracy to 100%
	SWEP = weapons.GetStored("weapon_ttt_revolver")
	if SWEP then
		SWEP.Primary.Cone = 0
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
			if not IsValid(ent) or ent.Base != grenadeProjectileBaseClass then return end

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
