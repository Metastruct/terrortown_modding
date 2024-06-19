local className = "weapon_ttt_massiveminigun"

if SERVER then
	AddCSLuaFile()

	-- Models and base sounds came from https://steamcommunity.com/sharedfiles/filedetails/?id=338915940
	-- w_minigun was fixed up by me
	resource.AddFile("models/weapons/c_minigun.mdl")
	resource.AddFile("models/weapons/w_minigun_fixed.mdl")
	resource.AddFile("materials/models/weapons/v_minigun_new/jb_chaingun.vmt")
	resource.AddSingleFile("materials/models/weapons/v_minigun_new/jb_chaingun_normal.vtf")

	resource.AddSingleFile("sound/weapons/minigun/minigun_shoot.wav")
	resource.AddSingleFile("sound/weapons/minigun/minigun_shoot_end.ogg")
	resource.AddSingleFile("sound/weapons/minigun/minigun_start.wav")
	resource.AddSingleFile("sound/weapons/minigun/minigun_stop.ogg")

	resource.AddFile("materials/vgui/ttt/icon_massiveminigun.vmt")
else
	SWEP.PrintName = "M.A.S.S.I.V.E"
	SWEP.Author = "TW1STaL1CKY"
	SWEP.Slot = 8
	SWEP.SlotPos = 1

	SWEP.ViewModelFlip = false
	SWEP.ViewModelFOV = 52

	SWEP.EquipMenuData = {
		type = "item_weapon",
		desc = "The M.A.S.S.I.V.E - a minigun fit for mowing down the competition."
	}

	SWEP.Icon = "vgui/ttt/icon_massiveminigun"
end

DEFINE_BASECLASS("weapon_tttbase")

SWEP.ClassName = className
SWEP.HoldType = "crossbow"

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_minigun.mdl"
SWEP.WorldModel = "models/weapons/w_minigun_fixed.mdl"

SWEP.Primary.Damage = 10
SWEP.Primary.NumShots = 2
SWEP.Primary.Cone = 0.08
SWEP.Primary.ClipSize = 500
SWEP.Primary.ClipMax = 500
SWEP.Primary.DefaultClip = 500
SWEP.Primary.Automatic = true
SWEP.Primary.Delay = 0.05
SWEP.Primary.Recoil = 1
SWEP.Primary.Ammo = "none"
SWEP.Primary.Sound = ")weapons/minigun/minigun_shoot.wav"
SWEP.Primary.SoundEnd = ")weapons/minigun/minigun_shoot_end.ogg"

SWEP.HeadshotMultiplier = 2.6

SWEP.DryFireSound = ")weapons/pistol/pistol_empty.wav"

SWEP.SpinupDuration = 0.8
SWEP.SpinupStartSound = ")weapons/minigun/minigun_start.wav"
SWEP.SpinupStopSound = ")weapons/minigun/minigun_stop.ogg"

SWEP.Kind = WEAPON_EQUIP
SWEP.CanBuy = {ROLE_TRAITOR}
SWEP.LimitedStock = true

SWEP.DeploySpeed = 1.25
SWEP.NoSights = true

function SWEP:PrimaryAttack() end

function SWEP:SecondaryAttack() end

function SWEP:Reload() end

-- A copy of PrimaryAttack pulled from weapon_tttbase
-- This has been moved from PrimaryAttack so it doesn't trigger on regular primary fire
function SWEP:PrimaryAttackEx()
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    if not self:CanPrimaryAttack() then
		self:StopFiringSound()
        return
    end

	if not self.SpinupFiring then
		self.SpinupFiring = true

		self:EmitSound(self.Primary.Sound, 100, 100)
	end

	local recoil = self:GetPrimaryRecoil()

    self:ShootBullet(
        self.Primary.Damage,
        recoil,
        self.Primary.NumShots,
        self:GetPrimaryCone()
    )

    self:TakePrimaryAmmo(1)

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

	if IsFirstTimePredicted() and (SERVER or (owner == LocalPlayer() and owner:ShouldDrawLocalPlayer())) then
		local ef = EffectData()
		ef:SetEntity(self)
		ef:SetAttachment(1)
		ef:SetFlags(7)

		util.Effect("MuzzleFlash", ef)

		local attachment = self:GetAttachment(2)
		if attachment then
			ef = EffectData()
			ef:SetEntity(self)
			ef:SetOrigin(attachment.Pos)
			ef:SetAngles(attachment.Ang)

			util.Effect("RifleShellEject", ef)
		end
	end

    owner:ViewPunch(
        Angle(
            util.SharedRandom(className, -0.5, -0.2, 0) * recoil,
            util.SharedRandom(className, -0.5, 0.5, 1) * recoil,
            0
        )
    )
end

function SWEP:DryFire()
    self:EmitSound(self.DryFireSound, 65, 82, 0.3, CHAN_ITEM)

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
end

function SWEP:ResetFiringValues()
	self.SpinupTime = nil

	if CLIENT then
		self.SpinupBarrelRoll = 0
		self.SpinupBarrelSpeed = 0
	end
end

function SWEP:StopFiringSound(stopSpinupSoundToo)
	local owner = self:GetOwner()
	local ownerValid = IsValid(owner)

	-- If the current owner has been lost but we remember who last spun us up, flag this to ensure sounds really stop
	local hasLostOwner = not ownerValid and IsValid(self.SpinupLastOwner)

	-- Ensure extra sounds are emitted from the owner if they're dying
	local emitSoundSource = SERVER and ownerValid and owner:Health() <= 0
		and owner
		or self

	self:StopSound(self.Primary.Sound)

	if hasLostOwner then
		self.SpinupLastOwner:StopSound(self.Primary.Sound)
	end

	if self.SpinupFiring then
		self.SpinupFiring = nil

		emitSoundSource:EmitSound(self.Primary.SoundEnd, 100, 100)
	end

	if stopSpinupSoundToo then
		self:StopSound(self.SpinupStartSound)

		if hasLostOwner then
			self.SpinupLastOwner:StopSound(self.SpinupStartSound)
		end

		if self.SpinupTime then
			emitSoundSource:EmitSound(self.SpinupStopSound, 78, 100, 1, CHAN_VOICE)
		end
	end

	-- Flag for the Think function to not recreate any sounds this frame
	self._stopSoundFrame = true

	timer.Simple(0, function()
		if IsValid(self) then
			self._stopSoundFrame = nil
		end
	end)
end

function SWEP:Think()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local wantsToFire = owner:KeyDown(IN_ATTACK)

	if wantsToFire then
		if not self.SpinupTime and not self._stopSoundFrame then
			self.SpinupTime = CurTime() + self.SpinupDuration
			self.SpinupLastOwner = owner

			self:EmitSound(self.SpinupStartSound, 78, 100, 1, CHAN_VOICE)

			owner:DoAnimationEvent(ACT_HL2MP_GESTURE_RANGE_ATTACK_AR2)
		end
	else
		if self.SpinupTime then
			self:StopFiringSound(true)

			self.SpinupTime = nil
		end
	end

	if self.SpinupTime then
		local now = CurTime()

		if self.SpinupTime <= now and self:GetNextPrimaryFire() <= now then
			self:PrimaryAttackEx()
		end
	end

	BaseClass.Think(self)
end

function SWEP:Deploy()
	local owner = self:GetOwner()

	if IsValid(owner) then
		self.SpinupLastOwner = nil

		-- Extra thirdperson animation to show they're lugging this big thing out
		owner:DoAnimationEvent(ACT_FLINCH_STOMACH)
	end

	return BaseClass.Deploy(self)
end

-- All the functions for stopping looping sounds if the weapon is put away
function SWEP:Holster()
	self:StopFiringSound(true)
	self:ResetFiringValues()

	return true
end

function SWEP:OwnerChanged()
	self:StopFiringSound(true)
	self:ResetFiringValues()
end

function SWEP:OnRemove()
	self:StopFiringSound(true)
	self:ResetFiringValues()

	BaseClass.OnRemove(self)
end

hook.Add("TTTPlayerSpeedModifier", "TTTMassiveMinigun", function(pl, _, _, speedMultiplierModifier)
	if IsValid(pl) then
        local wep = pl:GetActiveWeapon()

		if IsValid(wep) and wep:GetClass() == className then
			speedMultiplierModifier[1] = speedMultiplierModifier[1] * (wep.SpinupTime and 0.45 or 0.8)
		end
    end
end)

if CLIENT then
	local ang = Angle(0, 0, 0)

	local barrelMaxSpeed = 3000
	local barrelBoneName = "ValveBiped.bone2"
	local barrelCheckTimeName = "TTTMassiveMinigunVM"

	function SWEP:PreDrawViewModel(vm)
		local boneId = vm:LookupBone(barrelBoneName)
		if not boneId then return end

		local frameTime = FrameTime()

		self.SpinupBarrelSpeed = self.SpinupTime
			and math.min((self.SpinupBarrelSpeed or 0) + ((barrelMaxSpeed * self.SpinupDuration) * frameTime), barrelMaxSpeed)
			or math.max(Lerp(0.6 * frameTime, self.SpinupBarrelSpeed or 0, 0) - (16 * frameTime), 0)

		if self.SpinupBarrelSpeed > 0 then
			local roll = ((self.SpinupBarrelRoll or 0) + (self.SpinupBarrelSpeed * frameTime)) % 360

			self.SpinupBarrelRoll = roll
			ang.r = roll

			vm:ManipulateBoneAngles(boneId, ang, false)
		end

		-- Ugly way of making sure the viewmodel bone is definitely restored when this draw function is no longer called
		if timer.Exists(barrelCheckTimeName) then
			timer.Adjust(barrelCheckTimeName, 0.075)
		else
			timer.Create(barrelCheckTimeName, 0.075, 1, function()
				if IsValid(vm) then
					vm:ManipulateBoneAngles(boneId, angle_zero, false)
				end
			end)
		end
	end
end