local className = "weapon_ttt_posswapper"

if SERVER then
	AddCSLuaFile()

	util.AddNetworkString(className)

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

	SWEP.NullIcon = Material("null")
end

DEFINE_BASECLASS("weapon_tttbase")

SWEP.ClassName = className
SWEP.HoldType = "revolver"

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_pistol.mdl"
SWEP.WorldModel = "models/weapons/w_pistol.mdl"
SWEP.idleResetFix = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = 0.125
SWEP.Primary.Ammo = "none"
SWEP.Primary.Sound = "ambient/machines/thumper_hit.wav"
SWEP.Primary.SoundProcessing = "ambient/machines/thumper_top.wav"
SWEP.Primary.SoundUnavailable = "buttons/button8.wav"
SWEP.Primary.SoundFail = "player/suit_denydevice.wav"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Delay = 0.05
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Sound = "buttons/button14.wav"

SWEP.Kind = WEAPON_EQUIP
SWEP.CanBuy = {ROLE_TRAITOR}
SWEP.LimitedStock = true

SWEP.NoSights = true

function SWEP:PrimaryAttack()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
	self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)

	local target = self.Target
	if target == nil then
		local filter

		if SERVER then
			filter = RecipientFilter()
			filter:AddPlayer(owner)
		end

		-- Play failure sound
		self:EmitSound(self.Primary.SoundFail, 70, 100, 0.25, CHAN_AUTO, 0, 0, filter)

		return
	end

	if IsValid(target) and (not target:IsPlayer() or target:IsTerror()) then
		-- Position swap time!
		if SERVER then
			local screenFadeColor = Color(15, 15, 120, 180)

			local filter = RecipientFilter()

			local ownerPos, ownerAng, ownerVeh = owner:GetPos(), owner:EyeAngles(), owner.GetVehicle and owner:GetVehicle() or NULL
			local targetPos, targetAng, targetVeh = target:GetPos(), target:EyeAngles(), target.GetVehicle and target:GetVehicle() or NULL

			if owner:InVehicle() then
				owner:ExitVehicle()
			end
			if target:InVehicle() then
				target:ExitVehicle()
			end

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

			-- Make them swap vehicles too if applicable
			if IsValid(ownerVeh) then
				if isfunction(target.Sit) and ownerVeh.playerdynseat then
					-- Owner's vehicle is a SitAnywhere seat, sit in their spot
					target:Sit(ownerVeh:GetPos() - ownerVeh:GetUp() * 18, ownerVeh:GetAngles(), ownerVeh:GetParent())
				else
					target:EnterVehicle(ownerVeh)
				end
			end
			if IsValid(targetVeh) then
				if isfunction(owner.Sit) and targetVeh.playerdynseat then
					-- Target's vehicle is a SitAnywhere seat, sit in their spot
					owner:Sit(targetVeh:GetPos() - targetVeh:GetUp() * 18, targetVeh:GetAngles(), targetVeh:GetParent())
				else
					owner:EnterVehicle(targetVeh)
				end
			end

			-- Finally, remove the weapon :)
			self:StopSound(self.Primary.SoundProcessing)
			self:Remove()
		elseif not self.ProcessingSwap then
			-- While we stop the client from attempting to update their target any further while the server handles the swap, give the client some feedback in their latency
			self.ProcessingSwap = true

			self:EmitSound(self.Primary.SoundProcessing, 70, 110, 0.25)

			self:ClearHUDHelp()
			self:AddHUDHelpLine("Swapping with " .. target:Name() .. "...", self.NullIcon)
		end
	elseif SERVER then
		-- Somehow the target has died without the hooks noticing, handle this now
		self:SetTargetAsUnavailable()
	end
end

function SWEP:SecondaryAttack()
	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
	self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)

	if CLIENT and IsFirstTimePredicted() and not self.ProcessingSwap then
		local owner = self:GetOwner()
		if not IsValid(owner) then return end

		local pos = owner:GetShootPos()

		local tr = util.TraceLine({
			start = pos,
			endpos = pos + (owner:GetAimVector() * 5000),
			filter = owner,
			mask = MASK_SHOT
		})

		if tr.Entity != self.Target then
			self:UpdateTarget(tr.Entity)
		end
	end
end

function SWEP:Deploy()
	if SERVER then
		self:SyncTargetWithOwner()
	else
		self:RefreshHUDHelp()
	end

	return true
end

if SERVER then
	function SWEP:Reload() end

	function SWEP:SetTargetAsUnavailable()
		local oldTarget = self.Target

		self.Target = nil

		local owner = self:GetOwner()
		if not IsValid(owner) then return end

		net.Start(className)
		net.WriteBool(true)
		net.WriteUInt(IsValid(oldTarget) and oldTarget:EntIndex() or 0, 8) -- EntIndex for verification if possible

		net.Send(owner)
	end

	function SWEP:SyncTargetWithOwner()
		local owner = self:GetOwner()
		if not IsValid(owner) then return end

		local targetValid = IsValid(self.Target)

		net.Start(className)
		net.WriteBool(false)
		net.WriteBool(not targetValid)

		if targetValid then
			net.WritePlayer(self.Target)
		else
			-- The target isn't valid, make sure the field is nil on server
			self.Target = nil
		end

		net.Send(owner)
	end

	net.Receive(className, function(_, pl)
		local wep = pl:GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() != className then return end

		local shouldClear = net.ReadBool()

		if shouldClear then
			wep.Target = nil
		else
			local target = net.ReadPlayer()

			if IsValid(target) then
				wep.Target = target
			end
		end
	end)

	local function clearPlayerFromAllPosSwappers(pl)
		for k, v in ipairs(ents.FindByClass(className)) do
			if v.Target == pl then
				v:SetTargetAsUnavailable()
			end
		end
	end

	-- Handle clearing the target if they die or disconnect
	hook.Add("PostPlayerDeath", className, clearPlayerFromAllPosSwappers)
	hook.Add("PlayerDisconnected", className, clearPlayerFromAllPosSwappers)
else
	function SWEP:Reload()
		if self.ProcessingSwap or not IsFirstTimePredicted() then return end

		local owner = self:GetOwner()

		-- KeyDownLast will disallow holding Reload to run it every tick
		if not IsValid(owner) or owner:KeyDownLast(IN_RELOAD) then return end

		if self.Target then
			self:UpdateTarget()

			net.Start(className)
			net.WriteBool(true)
			net.SendToServer()
		end
	end

	local nameColor = Color(255, 200, 0)
	local deathColor = Color(255, 120, 120)

	function SWEP:UpdateTarget(ent)
		local shouldClear = ent == nil

		if shouldClear then
			self.Target = nil

			net.Start(className)
			net.WriteBool(true)
			net.SendToServer()

			chat.AddText(color_white, "Your swapper target has been cleared.")
		else
			if not (IsValid(ent) and ent:IsPlayer() and ent:IsTerror()) then return end

			self.Target = ent

			net.Start(className)
			net.WriteBool(false)
			net.WritePlayer(ent)
			net.SendToServer()

			chat.AddText(
				color_white, "Your swapper has targeted: ",
				nameColor, ent:Name())
		end

		self:EmitSound(self.Secondary.Sound, 70, shouldClear and 50 or 120, 0.5)

		self:RefreshHUDHelp()
	end

	function SWEP:RefreshHUDHelp()
		local target = self.Target
		local hasTarget = IsValid(target)

		self:AddTTT2HUDHelp(hasTarget and ("Swap with " .. target:Name()) or nil, "Choose target")

		if hasTarget then
			self:AddHUDHelpLine("Clear target", Key("+reload", "R"))
		end
	end

	net.Receive(className, function()
		local pl = LocalPlayer()
		local wep = pl:GetWeapon(className)
		if not IsValid(wep) then return end

		local becameUnavailable = net.ReadBool()

		if becameUnavailable then
			-- The server is telling us the target isn't available because they've died, sync things up on the client and show feedback
			if IsValid(wep.Target) then
				local targetId = net.ReadUInt(8)

				-- Make sure we haven't changed target before the message got here
				if wep.Target:EntIndex() != targetId then return end
			end

			wep.Target = nil
			wep.ProcessingSwap = nil -- Reset this just in case

			pl:EmitSound(wep.Primary.SoundUnavailable, 70, 110)

			chat.AddText(
				color_white, "Your swapper target has ",
				deathColor, "died",
				color_white, "!")
		else
			local isClear = net.ReadBool()
			local target = net.ReadPlayer()

			if isClear then
				wep.Target = nil
			else
				wep.Target = target
			end
		end

		wep:RefreshHUDHelp()
	end)
end