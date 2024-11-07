local className = "weapon_ttt_posswapper"

if SERVER then
	AddCSLuaFile()

	resource.AddFile("materials/vgui/ttt/icon_posswapper.vmt")
else
	SWEP.PrintName = "Position Swapper"
	SWEP.Author = "TW1STaL1CKY"
	SWEP.Slot = 7

	SWEP.DrawAmmo = false

	SWEP.ViewModelFlip = false
	SWEP.ViewModelFOV = 54

	SWEP.EquipMenuData = {
		type = "item_weapon",
		desc = "A tool to swap positions with another terrorist. Target someone with right-click, then swap places using left-click."
	}

	SWEP.Icon = "vgui/ttt/icon_posswapper"
	SWEP.IconLetter = "h"
end

DEFINE_BASECLASS("weapon_tttbase")

SWEP.ClassName = className
SWEP.HoldType = "revolver"

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_pistol.mdl"
SWEP.WorldModel = "models/weapons/w_pistol.mdl"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = 0.2
SWEP.Primary.Ammo = "none"
SWEP.Primary.Sound = "ambient/machines/thumper_hit.wav"
SWEP.Primary.SoundFail = "buttons/button2.wav"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Delay = 0.025
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Sound = "buttons/button14.wav"

SWEP.Kind = WEAPON_EQUIP
SWEP.CanBuy = {ROLE_TRAITOR}
SWEP.LimitedStock = true

SWEP.NoSights = true

function SWEP:SetupDataTables()
	BaseClass.SetupDataTables(self)

	self:NetworkVar("Entity", "TargetPlayer")

	if CLIENT then
		self:NetworkVarNotify("TargetPlayer", function(ent, name, oldVal, newVal)
			if oldVal != newVal then
				timer.Simple(0, function()
					if IsValid(ent) then
						ent:RefreshHUDHelp()
					end
				end)

				if IsFirstTimePredicted() and ent:GetOwner() == LocalPlayer() then
					local isValid = IsValid(newVal)

					if isValid then
						chat.AddText(color_white, "Your swapper has targeted: " .. newVal:Name())
					else
						chat.AddText(color_white, "Your swapper target has been cleared")
					end

					ent:EmitSound(ent.Secondary.Sound, 70, isValid and 120 or 50, 0.6)
				end
			end
		end)
	end
end

function SWEP:PrimaryAttack()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local target = self:GetTargetPlayer()
	if not IsValid(target) then return end

	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
	self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)

	if target:IsTerror() then
		-- Position swap time!
		if SERVER then
			local screenFadeColor = Color(15, 15, 120, 180)

			local filter = RecipientFilter()

			local ownerPos, ownerAng = owner:GetPos(), owner:EyeAngles()
			local targetPos, targetAng = target:GetPos(), target:EyeAngles()

			-- Move owner and do screenfade
			owner:SetPos(targetPos)
			owner:SetEyeAngles(targetAng)
			owner:ScreenFade(SCREENFADE.IN, screenFadeColor, 1.5, 0.2)

			-- Play teleport sound vividly for owner
			filter:AddPlayer(owner)

			owner:EmitSound(self.Primary.Sound, 70, 95, 0.4, CHAN_AUTO, 0, 0, filter)

			-- Play teleport sound vaguely for everyone else
			filter:AddAllPlayers()
			filter:RemovePlayer(owner)

			EmitSound(self.Primary.Sound, owner:WorldSpaceCenter(), 0, CHAN_AUTO, 0.2, 64, 0, 95, 0, filter)

			-- Move target and do screenfade
			target:SetPos(ownerPos)
			target:SetEyeAngles(ownerAng)
			target:ScreenFade(SCREENFADE.IN, screenFadeColor, 1.5, 0.2)

			-- Play teleport sound vividly for target
			filter:RemoveAllPlayers()
			filter:AddPlayer(target)

			target:EmitSound(self.Primary.Sound, 70, 95, 0.4, CHAN_AUTO, 0, 0, filter)

			-- Play teleport sound vaguely for everyone else
			filter:AddAllPlayers()
			filter:RemovePlayer(target)

			EmitSound(self.Primary.Sound, target:WorldSpaceCenter(), 0, CHAN_AUTO, 0.2, 64, 0, 95, 0, filter)

			-- Finally, remove the weapon :)
			self:Remove()
		end
	else
		local filter

		if SERVER then
			filter = RecipientFilter()
			filter:AddPlayer(owner)
		end

		-- Play failure sound
		self:EmitSound(self.Primary.SoundFail, 70, 86, 0.4, CHAN_AUTO, 0, 0, filter)
	end
end

function SWEP:SecondaryAttack()
	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
	self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	owner:LagCompensation(true)

	local pos = owner:GetShootPos()

	local tr = util.TraceLine({
		start = pos,
		endpos = pos + (owner:GetAimVector() * 5000),
		filter = owner,
		mask = MASK_SHOT
	})

	owner:LagCompensation(false)

	local ent = tr.Entity

	if IsValid(ent) and ent:IsPlayer() and ent:IsTerror() then
		self:SetTargetPlayer(ent)
	end
end

function SWEP:Reload()
	if IsValid(self:GetTargetPlayer()) then
		self:SetTargetPlayer(NULL)
	end
end

function SWEP:Deploy()
	if SERVER then
		-- Call this from the server in case Deploy isn't called properly on the client
		self:CallOnClient("RefreshHUDHelp")
	else
		self:RefreshHUDHelp()
	end

	return true
end

if CLIENT then
	function SWEP:RefreshHUDHelp()
		local target = self:GetTargetPlayer()
		local hasTarget = IsValid(target)

		self:AddTTT2HUDHelp(hasTarget and ("Swap with " .. target:Name()) or nil, "Choose target")

		if hasTarget then
			self:AddHUDHelpLine("Clear target", Key("+reload", "R"))
		end
	end
end