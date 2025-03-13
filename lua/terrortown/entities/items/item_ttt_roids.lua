local itemClassName = "item_ttt_roids"
local hookName = "TTT2RoiderRoids"

local crowbarClassName = "weapon_zm_improvised"

if SERVER then
    AddCSLuaFile()

	resource.AddFile("materials/vgui/ttt/icon_roids.vmt")
	resource.AddSingleFile("materials/vgui/ttt/perks/hud_roids.png")
else
	LANG.AddToLanguage("en", itemClassName, "Roids")
end

game.AddParticles("particles/impact_fx.pcf")
PrecacheParticleSystem("impact_wood")

ITEM.EquipMenuData = {
    type = "item_passive",
    name = itemClassName,
    desc = "Bulk out your muscles using Roider's Roids! Your melee attacks will do crazy damage, but you won't be able to use most guns with your shakey fingers anymore!",
}
ITEM.CanBuy = { ROLE_TRAITOR }

ITEM.hud = Material("vgui/ttt/perks/hud_roids.png")
ITEM.material = "vgui/ttt/icon_roids.png"

function ITEM:Equip(pl)
	local crowbar = IsValid(pl) and pl:GetWeapon(crowbarClassName)

	if IsValid(crowbar) then
		crowbar.Primary.DelayOriginal = crowbar.Primary.Delay

		crowbar.Primary.Delay = 0.4
	end
end

function ITEM:Reset(pl)
	local crowbar = IsValid(pl) and pl:GetWeapon(crowbarClassName)

	if IsValid(crowbar) then
		crowbar.Primary.Delay = crowbar.Primary.DelayOriginal or 0.5

		crowbar.Primary.DelayOriginal = nil
	end
end

-- Weapons will be checked using their .Kind to see if a Roided player can use it.
local whitelistedKinds = {
	[WEAPON_MELEE] = true,
	[WEAPON_NADE] = true,
	[WEAPON_CARRY] = true,
	[WEAPON_UNARMED] = true
}

-- Weapons here will be allowed if true, or force denied if false. Otherwise the weapon will rely on the above Kinds table.
-- "Why is this list hardcoded?" We can't programmatically check how a weapon really works, so we just have to allow/disallow them here.
local wepAllowment = {
	-- Melee
	weapon_ttt_knife = true,
	weapon_ttt_shankknife = true,
	weapon_ttt_homebat = true,

	-- Misc offensive (these do damage but aren't guns)
	weapon_banana = true,
	weapon_ttt_beartrap = true,
	weapon_ttt_defector_jihad = true,
	weapon_ttt_greendemon = true,
	weapon_ttt_ivy_kiss = true,
	weapon_ttt_jihad_bomb = true,
	weapon_ttt_slam = true,
	weapon_prop_rain = true,
	weapon_ttt_gay_brick = true,
	weapon_ttt_springmine = true,
	weapon_ttt_suicide = true,
	weapon_ttt_confgrenade_s = true,
	ttt_kamehameha_swep = true,

	-- Utility (built-in)
	weapon_ttt_beacon = true,
	weapon_ttt_binoculars = true,
	weapon_ttt_c4 = true,
	weapon_ttt_cse = true,
	weapon_ttt_decoy = true,
	weapon_ttt_defuser = true,
	weapon_ttt_health_station = true,
	weapon_ttt_radio = true,
	weapon_ttt_spawneditor = true, -- Just in case
	weapon_ttt_teleport = true,

	-- Utility (addons)
	weapon_ttt_beer = true,
	weapon_ttt_fakedeath = true,
	weapon_ttt_defibrillator = true,
	weapon_ttt_mesdefi = true,
	weapon_ttt_detective_toy_car = true,
	weapon_ttt_glue_trap = true,
	weapon_ttt_identity_disguiser = true,
	weapon_ttt2_jan_broom = true,
	weapon_ttt2_kiss = true,
	weapon_ttt_propdisguiser = true,
	weapon_ttt_squirtbottle = true,
	weapon_fan = true,
}

local function CanRoidedUseWeapon(wep)
	if not IsValid(wep) then return false end

	local wepSetting = wepAllowment[wep:GetClass()]

	return wepSetting == true or (wepSetting != false and whitelistedKinds[wep.Kind])
end

local noticeTime
hook.Add("StartCommand", hookName, function(pl, cm)
	if pl:Alive()
		and pl:IsTerror()
		and pl:HasEquipmentItem(itemClassName)
		and not CanRoidedUseWeapon(pl:GetActiveWeapon())
	then
		if CLIENT and (cm:KeyDown(IN_ATTACK) or cm:KeyDown(IN_ATTACK2) or cm:KeyDown(IN_RELOAD)) and (not noticeTime or noticeTime <= RealTime()) then
			noticeTime = RealTime() + 2

			LANG.Msg("You can't operate this weapon while all roided up!", nil, MSG_MSTACK_WARN)
			EmitSound("physics/metal/weapon_footstep2.wav", vector_origin, -1, CHAN_AUTO, 0.25, 75, 0, math.random(95, 105))
		end

		cm:SetButtons(bit.band(cm:GetButtons(), bit.bnot(IN_ATTACK), bit.bnot(IN_ATTACK2), bit.bnot(IN_RELOAD)))
	end
end)

if SERVER then
	local specialRoiderInteractions = {
		weapon_ttt_homebat = function(wep, ent, dmg)
			if not ent:IsPlayer() then return end

			dmg:SetDamage(200)

			ent.RoidedRagdollVelocity = wep:GetOwner():GetAimVector() * 2000

			local pos = wep:GetPos() + Vector(0, 0, 40)

			for i = 1, 8 do
				ParticleEffect("impact_wood", pos + VectorRand(-12, 12), AngleRand())
			end

			util.ScreenShake(pos, 10, 20, 1, 200, true)
			sound.Play("physics/wood/wood_plank_impact_hard5.wav", pos, 75, math.random(110, 125))

			timer.Simple(0.08, function()
				sound.Play("physics/wood/wood_box_break1.wav", pos, 75, math.random(120, 130))

				-- Remove the bat with a delay to let it play its hit sounds without erroring
				SafeRemoveEntityDelayed(wep, 0.5)

				if IsValid(wep) then
					ent:DropWeapon(wep)

					wep:SetNoDraw(true)
					wep:SetSolid(SOLID_NONE)
					wep:PhysicsDestroy()
				end
			end)
		end
	}

	hook.Add("TTT2ModifyRagdollVelocity", hookName, function(pl, rag, vel)
		if IsValid(pl) and isvector(pl.RoidedRagdollVelocity) then
			local newVel = pl.RoidedRagdollVelocity

			vel.x = newVel.x
			vel.y = newVel.y
			vel.z = newVel.z

			pl.RoidedRagdollVelocity = nil
		end
	end)

	local convarCrowbarPushForce = GetConVar("ttt_crowbar_pushforce")

	-- Give extra force for crowbar pushes by cheekily using this hook
	hook.Add("TTT2PlayerPreventPush", hookName, function(pl, victim)
		if pl:HasEquipmentItem(itemClassName) then
			-- Replicate what normally happens but mess with the velocity
			local pushvel = pl:GetAimVector() * (convarCrowbarPushForce:GetFloat() * 2)
            pushvel.z = math.Clamp(pushvel.z, 50, 100)

            victim:SetVelocity(victim:GetVelocity() + pushvel)

            victim.was_pushed = {
                att = pl,
                t = CurTime(),
                wep = crowbarClassName
            }

			return true
		end
	end)

    hook.Add("EntityTakeDamage", hookName, function(ent, dmg)
        if not IsValid(ent) then return end

		local attacker = dmg:GetAttacker()

		if IsValid(attacker)
			and attacker:IsPlayer()
			and attacker:IsTerror()
			and attacker:HasEquipmentItem(itemClassName)
		then
			if dmg:IsDamageType(DMG_CLUB) then
				dmg:ScaleDamage(2)

				if ent:IsPlayer() then
					ent:SetVelocity(attacker:GetAimVector() * 100)
				end
			end

			local wep = dmg:GetInflictor()

			if IsValid(wep) then
				local func = specialRoiderInteractions[wep:GetClass()]

				if isfunction(func) then
					func(wep, ent, dmg)
				end
			end
		end
    end)
else
	hook.Add("CalcViewModelView", hookName, function(wep, vm, oldPos, oldAng, pos, ang)
		local pl = LocalPlayer()

		if IsValid(pl) and pl:HasEquipmentItem(itemClassName) then
			return pos + VectorRand(-0.04, 0.04), ang + AngleRand(-0.2, 0.2)
		end
	end)
end