if SERVER then
	AddCSLuaFile()
end

local tankVoiceNwTag = "TTTL4DTankNextVoiceLine"
local tankRockThrowNwTag = "TTTL4DTankRockThrowStart"

DEFINE_BASECLASS("weapon_tttbase")

if CLIENT then
	SWEP.PrintName = "Tank Fists"
	SWEP.Slot = 1

	SWEP.ViewModelFlip = false
	SWEP.ViewModelFOV = 45
end

SWEP.HoldType = "normal"

SWEP.Kind = WEAPON_MELEE

SWEP.Primary.Damage = 40
SWEP.Primary.Delay = 1.5
SWEP.Primary.HitDelay = 0.5
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Primary.Range = 70
SWEP.Primary.HullSize = 4
SWEP.Primary.SwingDegrees = 60
SWEP.Primary.SwingSteps = 10

SWEP.Primary.HitSound = "infected/tank_punch.ogg"

SWEP.Secondary.Delay = 999
SWEP.Secondary.ThrowDelay = 2.3
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Secondary.Sound = "infected/tank_rock_pickup.ogg"

SWEP.UseHands = false
SWEP.ViewModel = "models/v_models/weapons/v_claw_hulk.mdl"
SWEP.WorldModel = "models/weapons/w_grenade.mdl"
SWEP.idleResetFix = true

SWEP.NoSights = true
SWEP.AllowDrop = false
SWEP.overrideDropOnDeath = DROP_ON_DEATH_TYPE_DENY

SWEP.AttackVoiceLines = {
	"player/tank/voice/attack/tank_attack_01.wav",
	"player/tank/voice/attack/tank_attack_02.wav",
	"player/tank/voice/attack/tank_attack_03.wav",
	"player/tank/voice/attack/tank_attack_04.wav",
	"player/tank/voice/attack/tank_attack_05.wav",
	"player/tank/voice/attack/tank_attack_06.wav",
	"player/tank/voice/attack/tank_attack_07.wav",
	"player/tank/voice/attack/tank_attack_08.wav",
	"player/tank/voice/attack/tank_attack_09.wav",
	"player/tank/voice/attack/tank_attack_10.wav"
}

function SWEP:SetupDataTables()
	self:NetworkVar("Float", "PunchTime")
	self:NetworkVar("Float", "RockThrowTime")
end

function SWEP:Initialize()
	-- Because of some Meta code shenanigans, this has to be set here or else it's stuck at 1s
	self.Secondary.Delay = 8

	BaseClass.Initialize(self)
end

function SWEP:PrimaryAttack()
	local now = CurTime()

	-- Rock is about to be thrown, don't allow punching until it's thrown
	if now <= self:GetRockThrowTime() then return end

	self:SetNextPrimaryFire(now + self.Primary.Delay)

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	owner:SetAnimation(PLAYER_ATTACK1)
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

	self:SetPunchTime(now + self.Primary.HitDelay)

	self:EmitSound("npc/zombie/claw_miss1.wav", 75, math.random(22, 25), 0.6)

	if IsFirstTimePredicted() and now >= owner:GetNWFloat(tankVoiceNwTag) then
		local rf

		if SERVER then
			rf = RecipientFilter()

			rf:AddAllPlayers()
			rf:RemovePlayer(owner)
		end

		owner:SetNWFloat(tankVoiceNwTag, now + 1.2)

		-- Intentionally play sound on owner so other tank voicelines can be interrupted by this one and vice versa
		owner:EmitSound(self.AttackVoiceLines[math.random(1, #self.AttackVoiceLines)], 90, 100, 1, CHAN_VOICE2, 0, 0, rf)
	end

	if SERVER then
		owner.TankAngryTime = math.max(now + 5, owner.TankAngryTime or 0)
	end
end

local applyPunchForce = SERVER and function(ent, force)
	local phys = ent:GetPhysicsObject()

	if phys:IsValid() then
		phys:AddVelocity(force)
		phys:AddAngleVelocity(VectorRand() * 800)
	end
end or nil

function SWEP:TraceAttack()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	owner:LagCompensation(true)

	local spos = owner:GetShootPos()
	local eyeAim = owner:GetAimVector()
	local right = owner:EyeAngles():Up()

	local filter = {owner}

	local ang, aim, sdest

	local hasHit = false

	local size = self.Primary.HullSize
	local mins, maxs = Vector(-size, -size, -size), Vector(size, size, size)

	local swingHalf = self.Primary.SwingDegrees * 0.5

	for i = -swingHalf, swingHalf, self.Primary.SwingDegrees / self.Primary.SwingSteps do
		-- Use EyeAngles again because we want a new copy of it, and it's faster than building a new Angle
		ang = owner:EyeAngles()
		ang:RotateAroundAxis(right, i)

		aim = ang:Forward()

		local size = 4

		sdest = spos + aim * (self.Primary.Range - size)

		local tr = util.TraceHull({
			start = spos,
			endpos = sdest,
			mask = MASK_SHOT,
			filter = filter,
			mins = mins,
			maxs = maxs
		})

		local ent = tr.Entity
		local entValid = IsValid(ent)

		if entValid then
			if SERVER then
				ent = self:AffectSpecialEntity(ent, tr) or ent

				local force = eyeAim * 700
				force.z = 200

				if ent:IsPlayer() then
					ent:SetGroundEntity(NULL)
					ent:SetVelocity(force)

					ent:ViewPunch(Angle(-30, 0, math.random(-30, 30)))

					ent:SetNWBool("TTTL4DTankHitSlow", true)
				else
					ent:ForcePlayerDrop()

					local droppedByStick = false

					-- If a player is still holding it after ForcePlayerDrop, then it's being held by the magneto-stick, find it and force it to drop
					if ent:IsPlayerHolding() then
						local carryClass = "weapon_zm_carry"

						for k, v in ipairs(player.GetAll()) do
							local vWep = v:GetActiveWeapon()

							if IsValid(vWep) and vWep:GetClass() == carryClass and vWep:GetCarryTarget() == ent then
								vWep:Reset(true)

								droppedByStick = true
								break
							end
						end
					end

					if droppedByStick then
						-- Force has to be applied a frame later if it was dropped
						timer.Simple(0, function()
							applyPunchForce(ent, force)
						end)
					else
						applyPunchForce(ent, force)
					end
				end

				local dmg = DamageInfo()

				dmg:SetInflictor(self)
				dmg:SetAttacker(owner)
				dmg:SetDamage(self.Primary.Damage)
				dmg:SetDamageType(DMG_CLUB)
				dmg:SetDamagePosition(spos)
				dmg:SetDamageForce(force)

				ent:DispatchTraceAttack(dmg,  spos + aim * 3, sdest)

				owner.TankAngryTime = CurTime() + 10
			end

			filter[#filter + 1] = ent
		end

		if tr.Hit then
			hasHit = true
		end
	end

	owner:LagCompensation(false)

	if hasHit then
		self:EmitSound(self.Primary.HitSound, 90, math.random(98, 102))

		if IsFirstTimePredicted() then
			util.ScreenShake(spos, 5, 10, 1, 250, true)
		end
	end
end

function SWEP:SecondaryAttack()
	local now = CurTime()

	local owner = self:GetOwner()
	if not IsValid(owner)
		or owner:GetMoveType() == MOVETYPE_LADDER
	then return end

	self:SetNextPrimaryFire(now + self.Primary.Delay)
	self:SetNextSecondaryFire(now + self.Secondary.Delay)

	self:SetRockThrowTime(now + self.Secondary.ThrowDelay)

	owner:SetNWFloat(tankRockThrowNwTag, now)

	self:EmitSound(self.Secondary.Sound, 90)

	if SERVER then
		owner:SetNWFloat(tankVoiceNwTag, now + 1.25)

		owner.TankAngryTime = now + 10
	end
end

function SWEP:Reload() end

function SWEP:Think()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local punchTime = self:GetPunchTime()
	if punchTime > 0 and CurTime() >= punchTime then
		self:SetPunchTime(0)
		self:TraceAttack()
	end

	local throwTime = self:GetRockThrowTime()
	if throwTime > 0 and CurTime() >= throwTime then
		self:SetRockThrowTime(0)

		if SERVER then
			self:SpawnThrowRock()
		end
	end
end

if SERVER then
	local function breakOffDoor(ent)
		-- Just in case this somehow trips twice
		if ent.isBroken then return end

		local prop = ents.Create("prop_physics")

		prop:SetPos(ent:GetPos())
		prop:SetAngles(ent:GetAngles())
		prop:SetModel(ent:GetModel())
		prop:SetSkin(ent:GetSkin())

		local bodygroups = ""
		for i = 0, ent:GetNumBodyGroups() - 1 do
			bodygroups = bodygroups .. tostring(ent:GetBodygroup(i))
		end

		if bodygroups != "" then
			prop:SetBodyGroups(bodygroups)
		end

		-- If there happens to be entities parented to the door, transfer them over
		for k, v in ipairs(ent:GetChildren()) do
			local pos, ang = v:GetLocalPos(), v:GetLocalAngles()

			v:SetParent(prop)
			v:SetLocalPos(pos)
			v:SetLocalAngles(ang)
		end

		ent:SetNoDraw(true)
		ent:SetSolid(SOLID_NONE)

		ent.isBroken = true

		SafeRemoveEntityDelayed(ent, 0.25)

		prop:Spawn()

		prop:EmitSound("physics/wood/wood_furniture_break2.wav", 100, math.random(90, 100))

		return prop
	end

	local specialEntityActions = {
		prop_door_rotating = function(ent)
			-- Only allow punching it off if it isn't ignoring +use
			if ent:HasSpawnFlags(32768) then return end

			local prop = breakOffDoor(ent)

			-- Doors can be associated with areaportals, which will leave a void if the door is removed
			-- If the door is named, find all areaportals linked to this door and force them open
			local doorName = ent:GetName()
			if doorName != "" then
				for k, v in ipairs(ents.FindByClass("func_areaportal")) do
					if v:GetInternalVariable("target") == doorName then
						v:Fire("Open")
					end
				end
			end

			-- TTT2 already finds paired doors and set them in this handy field on the door entity
			-- If there's a paired door, break that off too
			if IsValid(ent.otherPairDoor) then
				local prop2 = breakOffDoor(ent.otherPairDoor)

				timer.Simple(0, function()
					if not IsValid(prop) or not IsValid(prop2) then return end

					local phys = prop2:GetPhysicsObject()
					if phys:IsValid() then
						phys:AddVelocity(prop:GetVelocity())
					end
				end)
			end

			return prop
		end,
		func_door = function(ent)
			-- Only allow punching it open if it can be opened with +use or by touch (to not break maps)
			if not ent:HasSpawnFlags(256) and not ent:HasSpawnFlags(1024) then return end

			local speed = ent:GetInternalVariable("speed")

			ent:Fire("SetSpeed", 300)
			ent:Fire("Toggle")

			ent:Fire("SetSpeed", speed, 0.05)
		end,
		func_breakable_surf = function(ent)
			-- Just break it all
			ent:Fire("Shatter", "0.5 0.5 1000")
		end,
		func_button = function(ent)
			-- If the button requires +use, make punching use the button
			if ent:HasSpawnFlags(1024) then
				ent:Fire("Press")
			end
		end
	}

	specialEntityActions.func_door_rotating = specialEntityActions.func_door
	specialEntityActions.func_rot_button = specialEntityActions.func_button

	function SWEP:AffectSpecialEntity(ent, tr)
		if not IsValid(ent) then return end

		local func = specialEntityActions[ent:GetClass()]

		return func and func(ent, tr) or nil
	end

	function SWEP:SpawnThrowRock()
		local owner = self:GetOwner()
		if not IsValid(owner) then return end

		local spos = owner:GetShootPos() + Vector(0, 0, 5)
		local desiredPos = owner:GetEyeTraceNoCursor().HitPos

		local diff = desiredPos - spos
		local dir = diff:GetNormalized()

		-- Since we're going to be adding extra pitch to our throw based on distance, we need to sort of target players who are near the crosshair,
		-- otherwise accurately throwing rocks at moving players is going to be terrible
		local trTab = {
			start = spos,
			filter = owner,
			mask = MASK_SOLID_BRUSHONLY
		}

		local closestPos
		local closestDot = 0.95	-- Base lower limit

		for k, v in ipairs(player.GetAll()) do
			if v != owner and v:IsTerror() then
				local vpos = v:WorldSpaceCenter()

				local dot = dir:Dot((vpos - spos):GetNormalized())

				if dot > closestDot then
					trTab.endpos = vpos

					local tr = util.TraceLine(trTab)

					if not tr.Hit then
						closestPos = vpos
						closestDot = dot
					end
				end
			end
		end

		local diffLen

		if closestPos then
			diffLen = closestPos:Distance(spos)
			desiredPos = spos + (dir * diffLen)

			diff = desiredPos - spos
		else
			diffLen = diff:Length()
		end

		local ang = diff:Angle()

		local extraPitch = math.min(10 * (diffLen / 870), 12.5)

		ang.p = math.max(math.NormalizeAngle(ang.p - extraPitch), -89)

		dir = ang:Forward()

		local rock = ents.Create("ttt_tankrock_proj")

		rock:SetPos(spos)
		rock:SetAngles(Angle(0, ang.y + 90, 0))
		rock:SetOwner(owner)

		rock:Spawn()

		local phys = rock:GetPhysicsObject()
		if phys:IsValid() then
			phys:SetVelocityInstantaneous(dir * 1250)
		end
	end
else
	local loweredY = 32
	local raisedY = 8

	local rockModel = "models/props_debris/concrete_chunk01a.mdl"
	local rockBone = "ValveBiped.debris_bone"

	local rockLiftDelay = 0.75

	SWEP.CurrentVMPitch = nil

	function SWEP:GetViewModelPosition(pos, ang)
		local owner = self:GetOwner()
		local vm = owner:IsValid() and owner:GetViewModel() or NULL

		if not vm:IsValid() then return end

		local act = vm:GetSequenceActivity(vm:GetSequence())

		local desiredY = act == ACT_VM_PRIMARYATTACK and vm:GetCycle() < 0.9 and raisedY or loweredY
		local pitch = Lerp(FrameTime() * 5, self.CurrentVMPitch != nil and self.CurrentVMPitch or desiredY, desiredY)

		self.CurrentVMPitch = pitch

		ang.p = ang.p + pitch

		return pos, ang
	end

	function SWEP:PostDrawViewModel(_, _, owner)
		local throwTime = self:GetRockThrowTime()
		local now = CurTime()

		local liftTime = throwTime - self.Secondary.ThrowDelay + rockLiftDelay

		if throwTime <= 0 or now > throwTime or now < liftTime then return end

		if not IsValid(self.RockModel) then
			self.RockModel = ClientsideModel(rockModel)

			self.RockModel:SetNoDraw(true)
		end

		local progress = math.ease.InOutQuint((now - liftTime) / (throwTime - liftTime))

		local ang = owner:EyeAngles()

		local upDir = ang:Up()

		local pos = owner:EyePos() + (ang:Forward() * 50) + (upDir * Lerp(progress, -32, 38))

		ang:RotateAroundAxis(upDir, 90)
		ang:RotateAroundAxis(ang:Forward(), Lerp(progress, 0, -180))

		self.RockModel:SetPos(pos)
		self.RockModel:SetAngles(ang)

		self.RockModel:DrawModel()
	end

	function SWEP:DrawWorldModel(flags)
		local throwTime = self:GetRockThrowTime()
		local now = CurTime()

		if throwTime <= 0 or now > throwTime or now < (throwTime - self.Secondary.ThrowDelay + rockLiftDelay) then return end

		local owner = self:GetOwner()
		if not IsValid(owner) then return end

		if not IsValid(self.RockModel) then
			self.RockModel = ClientsideModel(rockModel)

			self.RockModel:SetNoDraw(true)
		end

		local boneId = owner:LookupBone(rockBone)
		if boneId then
			local matrix = owner:GetBoneMatrix(boneId)

			local ang = matrix:GetAngles()

			ang:RotateAroundAxis(ang:Up(), -90)

			self.RockModel:SetPos(matrix:GetTranslation())
			self.RockModel:SetAngles(ang)

			self.RockModel:DrawModel(flags)
		end
	end

	local barColorOutline = Color(0, 0, 0, 220)
	local barFont = "PureSkinBar"
	local barText = "ROCK THROW"

	local barAlpha

	function SWEP:DrawHUD()
		local pl = LocalPlayer()
		if not IsValid(pl) then return end

		local progress = math.min(1 - ((self:GetNextSecondaryFire() - CurTime()) / (self.Secondary.Delay - self.Secondary.ThrowDelay)), 1)

		barAlpha = Lerp(FrameTime() * 3, barAlpha or 0.08, progress > 0 and progress < 1 and 1 or 0.08)

		surface.SetAlphaMultiplier(barAlpha)

		local scale = ScrH() / 1440
		local hW, hH = ScrW() * 0.5, ScrH() * 0.5

		local barLineSize = 1
		local barW, barH = 400 * scale, 25 * scale
		local barX, barY = hW - (barW * 0.5), hH + (200 * scale)

		draw.Box(barX, barY, barW, barH, barColorOutline)
		draw.OutlinedBox(barX, barY, barW, barH, barLineSize, barColorOutline)

		local barLineDouble = barLineSize * 2

		draw.Box(barX + barLineSize, barY + barLineSize, (barW * progress) - barLineDouble, barH - barLineDouble, pl:GetRoleColor())

		draw.ShadowedText(barText, barFont, hW, barY, util.GetDefaultColor(barColorOutline), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, scale)

		surface.SetAlphaMultiplier(1)

		BaseClass.DrawHUD(self)
	end

	function SWEP:OnRemove()
		if IsValid(self.RockModel) then
			self.RockModel:Remove()
		end
	end

	SWEP.OnReloaded = SWEP.OnRemove
end