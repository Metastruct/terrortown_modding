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
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local tr = util.TraceLine({
		start = owner:EyePos(),
		endpos = owner:EyePos() + owner:GetAimVector() * 5000,
		filter = owner
	})

	if (IsValid(tr.Entity) and not tr.Entity:IsPlayer()) or (IsValid(tr.Entity) and tr.Entity:IsPlayer() and IsValid(tr.Entity:GetActiveWeapon())) then
		if SERVER then
			self:DoShootEffect(tr.HitPos, tr.HitNormal, tr.Entity, tr.PhysicsBone, IsFirstTimePredicted())

			local ed = EffectData()
			ed:SetEntity(tr.Entity)
			util.Effect("entity_remove", ed, true, true)

			if tr.Entity:IsPlayer() then
				SafeRemoveEntity(tr.Entity:GetActiveWeapon())
			else
				constraint.RemoveAll(tr.Entity)
				SafeRemoveEntity(tr.Entity)
			end
		end

		self:SetNextPrimaryFire(CurTime() + 10) -- 10s
	else
		if SERVER then
			self:EmitSound("buttons/button2.wav")
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

if CLIENT then
	hook.Add("HUDPaint", "weapon_ttt_remover", function()
		local wep = LocalPlayer():GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= "weapon_ttt_remover" then return end

		local nextFire = wep:GetNextPrimaryFire()
		local curTime = CurTime()

		if nextFire > curTime then
			local remaining = nextFire - curTime
			local w = 200
			local h = 20
			local x = ScrW() / 2 - w / 2
			local y = ScrH() - 100

			surface.SetDrawColor(0, 0, 0, 180)
			surface.DrawRect(x, y, w, h)

			local progress = math.Clamp((10 - remaining) / 10, 0, 1)
			surface.SetDrawColor(255, 50, 50, 180)
			surface.DrawRect(x, y, w * progress, h)
			draw.SimpleText(string.format("Cooldown: %.1fs", remaining), "Default", ScrW() / 2, y + h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end)
end
