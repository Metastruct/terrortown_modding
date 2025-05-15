if SERVER then
	AddCSLuaFile()
	resource.AddFile("materials/vgui/ttt/icon_remover.vmt")
end

DEFINE_BASECLASS("weapon_tttbase")

SWEP.PrintName = "Remover"
SWEP.Author = "Earu"
SWEP.Instructions = "Left click to remove entities or kill players/NPCs"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Weight = 5
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

SWEP.Slot = 0
SWEP.SlotPos = 1
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.ViewModel = "models/weapons/v_toolgun.mdl"
SWEP.WorldModel = "models/weapons/w_toolgun.mdl"

SWEP.UseHands = true
SWEP.ViewModelFlip = false
SWEP.ViewModelFOV = 54

SWEP.Kind = WEAPON_EQUIP2
SWEP.CanBuy = { ROLE_TRAITOR, ROLE_DETECTIVE }
SWEP.LimitedStock = true
SWEP.AllowDrop = true
SWEP.IsSilent = false
SWEP.NoSights = false

if CLIENT then
	SWEP.EquipMenuData = {
		type = "Weapon",
		desc = "Remove entities or kill players/NPCs"
	}

	SWEP.Icon = "vgui/ttt/icon_remover"
	SWEP.IconLetter = "h"
end

function SWEP:Initialize()
	self:SetHoldType("pistol")

	return BaseClass.Initialize(self)
end

function SWEP:PrimaryAttack()
	if CLIENT then return end

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local tr = util.TraceLine({
		start = owner:EyePos(),
		endpos = owner:EyePos() + owner:GetAimVector() * 5000,
		filter = owner
	})

	if IsValid(tr.Entity) then
		if tr.Entity:IsPlayer() then
			if self.KilledPlayer then return end -- dont allow multiple kills

			self:DoShootEffect(tr.HitPos, tr.HitNormal, tr.Entity, tr.PhysicsBone, IsFirstTimePredicted())

			tr.Entity:TakeDamage(1000000, owner, self)
			if tr.Entity:Alive() then return end

			local hookName = ("remover_%s"):format(tr.Entity:EntIndex())
			hook.Add("TTTOnCorpseCreated", hookName, function(rag, pl)
				if pl ~= tr.Entity then return end
				if not IsValid(rag) then
					hook.Remove("TTTOnCorpseCreated", hookName)
					return
				end

				SafeRemoveEntityDelayed(rag, 0.1)
				hook.Remove("TTTOnCorpseCreated", hookName)
			end)

			timer.Simple(2, function()
				hook.Remove("TTTOnCorpseCreated", hookName)
				-- failsafe
			end)

			local ed = EffectData()
			ed:SetEntity(tr.Entity)
			util.Effect("entity_remove", ed, true, true)

			self.KilledPlayer = true
			self:SetNextPrimaryFire(CurTime() + 10) -- 10s
		else
			if not tr.Entity:IsWorld() then
				self:DoShootEffect(tr.HitPos, tr.HitNormal, tr.Entity, tr.PhysicsBone, IsFirstTimePredicted())

				local ed = EffectData()
				ed:SetEntity(tr.Entity)
				util.Effect("entity_remove", ed, true, true)

				constraint.RemoveAll(tr.Entity)
				SafeRemoveEntity(tr.Entity)
				self:SetNextPrimaryFire(CurTime() + 10) -- 10s
			end
		end
	end
end

function SWEP:DoShootEffect(hitpos, hitnormal, entity, physbone, firsttimepredicted)
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	owner:EmitSound("Airboat.FireGunRevDown")
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	owner:SetAnimation(PLAYER_ATTACK1)

	local effectdata = EffectData()
	effectdata:SetOrigin( hitpos )
	effectdata:SetNormal( hitnormal )
	effectdata:SetEntity( entity )
	effectdata:SetAttachment( physbone )
	util.Effect("selection_indicator", effectdata)

	local effect_tr = EffectData()
	effect_tr:SetOrigin( hitpos )
	effect_tr:SetStart( owner:GetShootPos() )
	effect_tr:SetAttachment( 1 )
	effect_tr:SetEntity( self )
	util.Effect("tooltracer", effect_tr)
end

function SWEP:SecondaryAttack()
	return false
end