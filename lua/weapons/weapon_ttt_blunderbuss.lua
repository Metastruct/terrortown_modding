local className = "weapon_ttt_blunderbuss"
local effectNetworkTag = "TTTBlunderbussFireEffect"
local convarFireDelayName = "ttt_blunderbuss_firedelay"

if SERVER then
	AddCSLuaFile()
	resource.AddFile("models/weapons/blunderbus.mdl")
	resource.AddFile("models/weapons/w_blunderbus.mdl")
	resource.AddFile("materials/models/weapons/blunderbus.vmt")
	resource.AddSingleFile("materials/models/weapons/blunderbus_normal.vtf")
	resource.AddSingleFile("materials/models/weapons/blunderbus_skin.vmt")

	resource.AddSingleFile("sound/weapons/blunderbuss_fire.mp3")
	resource.AddSingleFile("sound/weapons/blunderbuss_fire_distant.mp3")
	resource.AddSingleFile("sound/weapons/blunderbuss_delay.mp3")

	resource.AddFile("materials/vgui/ttt/icon_blunderbuss.vmt")

	util.AddNetworkString(effectNetworkTag)
else
	SWEP.PrintName = "Blunderbuss"
	SWEP.Author = "TW1STaL1CKY"
	SWEP.Slot = 8
	SWEP.SlotPos = 1

	SWEP.ViewModelFlip = false
	SWEP.ViewModelFOV = 50
	SWEP.DrawCrosshair = false

	SWEP.EquipMenuData = {
		type = "item_weapon",
		desc = "A quite explosive blunderbuss that shreds through whatever is in front of it.\n\nUse it wisely, you only get one shot with this thing."
	}

	SWEP.Icon = "vgui/ttt/icon_blunderbuss"
	SWEP.IconLetter = "c"

	LANG.AddToLanguage("en", convarFireDelayName .. "_help", "If this is set to 0, the blunderbuss will fire instantly when pulling the trigger.\nIf this is set to a number above 0, the blunderbuss will make a click and fuse sound before actually firing. This setting will alter how long the delay is, in seconds.")
end

DEFINE_BASECLASS("weapon_tttbase")

SWEP.HoldType = "shotgun"
SWEP.ClassName = className

SWEP.ViewModel = "models/weapons/blunderbus.mdl"
SWEP.WorldModel = "models/weapons/w_blunderbus.mdl"

SWEP.Primary.Damage = 50
SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = 0.2
SWEP.Primary.Ammo = "none"
SWEP.Primary.Sound = ")weapons/blunderbuss_fire.mp3"
SWEP.Primary.DelayedShotSound = ")weapons/blunderbuss_delay.mp3"
SWEP.Primary.MaxPenetrations = 3
SWEP.Primary.DamageScalePerPenetration = 0.9
SWEP.Primary.MaxRange = 400
SWEP.Primary.FalloffStartRange = 250
SWEP.Primary.SelfKnockbackForce = 400

SWEP.Primary.Spread = {
	-- How much space to put between each ring
	SpaceBetweenRings = 3.5,

	-- How many shots to create per ring (each number is an additional outer ring)
	RingNumShots = {
		6,
		12,
		16,
		18,
		16,
		14
	}
}

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Delay = 1

SWEP.Kind = WEAPON_EQUIP
SWEP.CanBuy = {ROLE_TRAITOR}
SWEP.LimitedStock = true

SWEP.DeploySpeed = 0.6
SWEP.NoSights = true

local convarFireDelay = CreateConVar(convarFireDelayName, 0.3, {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED})

local propPhysicsClass = "prop_physics"
local propDynamicClass = "prop_dynamic"
local funcBreakableClass = "func_breakable"
local funcBreakableSurfClass = "func_breakable_surf"

function SWEP:SetupDataTables()
	self:NetworkVar("Bool", 0, "Fired")
	self:NetworkVar("Float", 0, "DelayedShotTime")
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
	self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)

	if self:GetFired() then
		if self:GetDelayedShotTime() <= 0 then
			self:EmitSound("weapons/pistol/pistol_empty.wav", 64, math.random(50, 52), 0.2, CHAN_VOICE)
		end

		return
	end

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	self:SetFired(true)

	local fireDelay = convarFireDelay:GetFloat()

	if fireDelay > 0 then
		-- This is needed to track to who held it last
		self.LastFiredOwner = owner

		self:EmitSound(self.Primary.DelayedShotSound, 68)

		self:SetDelayedShotTime(CurTime() + fireDelay)

		owner:ViewPunch(Angle(1,0,0))
	else
		self:Shoot()
	end
end

function SWEP:Shoot()
	self:SetDelayedShotTime(0)
	self:SetClip1(0)

	local owner = self:GetOwner()
	local ownerIsPlayer = IsValid(owner) and owner:IsPlayer()

	if not ownerIsPlayer then
		-- We're going to be shooting from the blunderbuss entity itself! Fun!
		owner = self
	end

	local spreadInfo = self.Primary.Spread

	if ownerIsPlayer then
		owner:LagCompensation(true)
	end

	local startPos
	local viewVec
	local viewAng

	if ownerIsPlayer then
		startPos = owner:GetShootPos()
		viewVec = owner:GetAimVector()
		viewAng = viewVec:Angle()
	else
		viewAng = owner:GetAngles()
		viewVec = viewAng:Forward()
		startPos = owner:GetPos() + (viewVec * 24) + (viewAng:Up() * 1.9)
	end

	local viewRight = viewAng:Right()
	local viewUp = viewAng:Up()

	local firstTimePredicted = IsFirstTimePredicted()

	self.CurrentShot = {
		StartPos = startPos,
		Owner = owner,
		Attacker = self.LastFiredOwner,
		FirstPredict = firstTimePredicted
	}

	-- Do one pellet trace straight forward
	self:DoPelletTrace(startPos, viewVec)

	-- Then do the rest of the pellet traces in rings
	for ringCount, numShots in ipairs(spreadInfo.RingNumShots) do
		local spreadSize = spreadInfo.SpaceBetweenRings * ringCount

		for i = 1, numShots do
			local prog = (i / numShots) * math.pi * 2
			local sin = math.sin(prog) * spreadSize
			local cos = math.cos(prog) * spreadSize

			local spreadAng = Angle(viewAng)

			spreadAng:RotateAroundAxis(viewRight, sin)
			spreadAng:RotateAroundAxis(viewUp, cos)

			local spreadNormal = spreadAng:Forward()

			self:DoPelletTrace(startPos, spreadNormal)
		end
	end

	self.CurrentShot = nil

	if ownerIsPlayer then
		owner:LagCompensation(false)

		-- Calculate and add some knockback to owner
		local knockbackForce = self.Primary.SelfKnockbackForce

		local vel2D = owner:GetVelocity()
		vel2D.z = 0

		local velTotal = vel2D:Length2D()

		local viewVec2D = Vector(viewVec)
		viewVec2D.z = 0
		viewVec2D = viewVec2D:GetNormalized()

		local vecDot = viewVec2D:Dot(vel2D:GetNormalized())

		local forwardScale = math.max(vecDot, 0)
		local backwardScale = -math.min(vecDot, 0)

		local calculatedKnockbackAmt = math.max(knockbackForce - (velTotal * backwardScale), 0)
		local resultVel =
			(vector_up * knockbackForce * -viewVec.z) 								-- Z-axis knockback based on up/down viewangle
			+ (viewVec2D * (1 - math.abs(viewVec.z)) * -calculatedKnockbackAmt)		-- Actual knockback based on how much you're already moving backwards
			- (viewVec2D * velTotal * forwardScale)									-- Forward velocity to cancel any forward momentum

		owner:SetGroundEntity()
		owner:SetVelocity(resultVel)

		self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
		owner:SetAnimation(PLAYER_ATTACK1)
		owner:ViewPunch(Angle(-20,0,0))
	else
		local phys = owner:GetPhysicsObject()

		if IsValid(phys) then
			phys:Wake()
			phys:AddVelocity(viewVec * -1600)
		end
	end

	if firstTimePredicted then
		local effectPos = owner:GetPos()

		if ownerIsPlayer then
			self:EmitSound(self.Primary.Sound, 90)

			effectPos.z = effectPos.z + 50
		else
			-- If it's going to come from the blunderbuss itself, don't let the sound follow it, play it where it fired instead
			sound.Play(self.Primary.Sound, effectPos, 90)

			-- Do this to stop the click-fizzle sound playing after it's been fired
			if SERVER and IsValid(self.LastFiredOwner) then
				self:StopSound(self.Primary.DelayedShotSound)
			end
		end

		effectPos = effectPos + (viewVec * 32)

		-- Synced particles and long range sound
		if SERVER then
			net.Start(effectNetworkTag)
			net.WriteVector(effectPos)
			net.WriteVector(viewVec)
			net.WriteEntity(self.LastFiredOwner)

			if ownerIsPlayer then
				net.SendOmit(owner)
			else
				net.Broadcast()
			end
		else
			self:DoShootEffects(effectPos, viewVec)
		end
	end
end

function SWEP:DoPelletTrace(startPos, normal)
	local endPos = startPos + normal * self.Primary.MaxRange

	self.CurrentPellet = {
		CurrentPos = startPos,
		EndPos = endPos,
		Damage = self.Primary.Damage * (self.damageScaling or 1),	-- .damageScaling is TTT2's "Damage Scaling" setting found in the admin equipment menu
		Penetrations = 0,
		Filter = { self.CurrentShot.Owner }
	}

	self:ContinuePelletTrace()

	self.CurrentPellet = nil
end

function SWEP:ContinuePelletTrace()
	local tr = util.TraceLine({
		start = self.CurrentPellet.CurrentPos,
		endpos = self.CurrentPellet.EndPos,
		filter = self.CurrentPellet.Filter,
		mask = MASK_SHOT
	})

	--debugoverlay.Box(tr.HitPos, Vector(-1, -1, -1), Vector(1, 1, 1), 3)

	local shouldContinue = false
	local ent
	local entValid = false

	if tr.HitNonWorld then
		ent = tr.Entity
		entValid = IsValid(ent)

		if entValid then
			local falloffRange = self.Primary.MaxRange - self.Primary.FalloffStartRange
			local falloffMult = math.min(1 - ((tr.HitPos:Distance(self.CurrentShot.StartPos) - self.Primary.FalloffStartRange) / falloffRange), 1)
			local scaledDamage = math.ceil(self.CurrentPellet.Damage * falloffMult)

			local className = ent:GetClass()
			local isProp = className == propPhysicsClass or className == propDynamicClass
			local isFuncBreakable = className == funcBreakableClass or className == funcBreakableSurfClass

			if SERVER then
				local suppressNeedsRestoring = false

				if not ent._gibbed then
					local hp = ent:Health()

					if (hp - scaledDamage) <= 0 then
						-- If it's a breakable prop and we're going to break it, run this epic workaround to let gibs spawn (weapon_fists does the same, it's cool)
						if isProp and hp > 0 then
							SuppressHostEvents(NULL)

							suppressNeedsRestoring = true

							-- Health() doesn't update after taking damage?? Flag that we've gibbed instead I guess :)
							ent._gibbed = true
						elseif className == funcBreakableSurfClass then
							-- Shatter the whole window
							ent:Fire("Shatter", "0.5 0.5 100")
						end
					end
				end

				local dmg = DamageInfo()
				dmg:SetAttacker(IsValid(self.CurrentShot.Attacker) and self.CurrentShot.Attacker or self.CurrentShot.Owner)
				dmg:SetInflictor(self)
				dmg:SetDamage(scaledDamage)
				dmg:SetDamageType(DMG_BULLET)
				dmg:SetDamagePosition(self.CurrentShot.StartPos)
				dmg:SetDamageForce(tr.Normal * 4000)

				ent:TakeDamageInfo(dmg)

				if suppressNeedsRestoring then
					SuppressHostEvents(self.CurrentShot.Owner)
				end
			end

			if self.CurrentShot.FirstPredict then
				local eData

				if self.CurrentShot.ImpactEffectData then
					eData = self.CurrentShot.ImpactEffectData
				else
					eData = EffectData()
					eData:SetNormal(tr.Normal)
					eData:SetDamageType(DMG_BULLET)

					self.CurrentShot.ImpactEffectData = eData
				end

				eData:SetOrigin(tr.HitPos)
				eData:SetNormal(tr.Normal)
				eData:SetEntity(tr.HitEntity)
				eData:SetSurfaceProp(tr.SurfaceProps)
				eData:SetHitBox(tr.HitBox)

				util.Effect("Impact", eData)
			end

			shouldContinue = self.CurrentPellet.Penetrations < self.Primary.MaxPenetrations
				and (isProp or isFuncBreakable or ent:IsPlayer())
		end
	end

	if shouldContinue then
		self.CurrentPellet.Penetrations = self.CurrentPellet.Penetrations + 1
		self.CurrentPellet.Damage = math.ceil(self.CurrentPellet.Damage * self.Primary.DamageScalePerPenetration)
		self.CurrentPellet.CurrentPos = tr.HitPos

		if entValid then
			self.CurrentPellet.Filter[#self.CurrentPellet.Filter + 1] = ent
		end

		self:ContinuePelletTrace()
	end
end

function SWEP:SecondaryAttack() end

function SWEP:Holster()
	-- Prevent swapping away if delayed shot is in progress
	return self:GetDelayedShotTime() <= 0
end

function SWEP:Think()
	local shootTime = self:GetDelayedShotTime()

	if shootTime > 0 and shootTime <= CurTime() then
		self:Shoot()
	end
end

if SERVER then
	function SWEP:Equip()
		self:SetNextPrimaryFire(CurTime() + 0.75)
		self:SetNextSecondaryFire(CurTime() + 0.75)
	end

	function SWEP:OwnerChanged()
		-- :Think() doesn't run while not being held, so we need to continue the delay with a timer

		local shootTime = self:GetDelayedShotTime()
		if shootTime <= 0 then return end

		local newOwner = self:GetOwner()
		if IsValid(newOwner) then return end

		timer.Simple(shootTime - CurTime(), function()
			if IsValid(self) then
				self:Shoot()
			end
		end)
	end

	-- Disable pickup while delayed shot is going on, otherwise jank happens
	hook.Add("PlayerCanPickupWeapon", className, function(pl, wep)
		if wep:GetClass() == className and wep:GetDelayedShotTime() > 0 then return false end
	end)
else
	SWEP.ClientsideWorldModel = {
		Pos = Vector(6.5, -1.1, -2.6),
		Ang = Angle(170, 180, 0),
		Bone = "ValveBiped.Bip01_R_Hand"
	}

	function SWEP:DoShootEffects(pos, normal)
		-- This is more of a helper function living in the SWEP table, so avoid using "self" here

		local pl = LocalPlayer()
		if not IsValid(pl) then return end

		-- Smoke emission
		local em = ParticleEmitter(pos)
		local particleTex = "particle/particle_noisesphere"
		local radius = 5

		for i = 1, 50 do
			local randPos = VectorRand() * radius

			local p = em:Add(particleTex, pos + randPos)
			if p then
				local gray = math.random(20, 80)

				p:SetColor(gray, gray, gray)
				p:SetStartAlpha(255)
				p:SetEndAlpha(10)
				p:SetAirResistance(300)
				p:SetVelocity((VectorRand() * math.Rand(250, 500)) + (normal * 40 * i))

				p:SetLifeTime(0)
				p:SetDieTime(math.Rand(30, 35))

				p:SetStartSize(math.random(100, 150))
				p:SetEndSize(math.random(60, 80))
				p:SetRoll(math.random(-180, 180))
				p:SetRollDelta(math.Rand(-0.5, 0.5))

				p:SetCollide(true)
				p:SetBounce(0.4)

				p:SetLighting(false)
			end
		end

		em:Finish()

		-- Distant sound
		local dist = EyePos():Distance(pos)

		sound.Play("weapons/blunderbuss_fire_distant.mp3", pos, 120, 100, dist > 300 and 1 or 0.5)
	end

	function SWEP:OnRemove()
		if IsValid(self.ClientsideWorldModel.Model) then
			self.ClientsideWorldModel.Model:Remove()
		end

		BaseClass.OnRemove(self)
	end

	function SWEP:GetViewModelPosition(pos, ang)
		local right = ang:Right()
		local up = ang:Up()
		local forward = ang:Forward()

		ang:RotateAroundAxis(right, -9)
		ang:RotateAroundAxis(up, -4)

		local rightAmount = 0
		local forwardAmount = -1

		if self:GetDelayedShotTime() > 0 then
			self.DelayedShotPullScale = Lerp(3 * FrameTime(), self.DelayedShotPullScale or 0, 3)

			rightAmount = rightAmount + (math.Rand(-0.05, 0.05) * self.DelayedShotPullScale)
			forwardAmount = forwardAmount - self.DelayedShotPullScale
		else
			self.DelayedShotPullScale = nil
		end

		pos = pos + rightAmount * right
		pos = pos + 2 * up
		pos = pos + forwardAmount * forward

		return pos, ang
	end

	function SWEP:DrawWorldModel(flags)
		if not self:TryDrawWorldModel() then
			self:DrawModel(flags)
		end
	end

	function SWEP:TryDrawWorldModel()
		local owner = self:GetOwner()

		if not IsValid(owner) then return false end

		local pl = LocalPlayer()
		if not IsValid(pl) or (pl:GetObserverMode() == OBS_MODE_IN_EYE and pl:GetObserverTarget() == owner) then return false end

		local modelData = self.ClientsideWorldModel

		if not IsValid(modelData.Model) then
			modelData.Model = ClientsideModel(self:GetModel())

			modelData.Model:SetNoDraw(true)
			modelData.Model:SetupBones()
		end

		local boneId = owner:LookupBone(modelData.Bone)
		if not boneId then return false end

		local matrix = owner:GetBoneMatrix(boneId)
		if not matrix then return false end

		local pos, ang = LocalToWorld(modelData.Pos, modelData.Ang, matrix:GetTranslation(), matrix:GetAngles())

		modelData.Model:SetPos(pos)
		modelData.Model:SetAngles(ang)

		modelData.Model:DrawModel()

		return true
	end

	function SWEP:AddToSettingsMenu(parent)
		local form = vgui.CreateTTT2Form(parent, "header_equipment_additional")

		form:MakeHelp({
			label = convarFireDelayName .. "_help",
		})

		form:MakeSlider({
			serverConvar = convarFireDelayName,
			label = "Firing delay",
			min = 0,
			max = 2,
			decimal = 2
		})
	end

	net.Receive(effectNetworkTag, function()
		-- We want the effects' position to be synced up for all clients regardless of entity position, angles, and PVS
		local pos = net.ReadVector()
		if not pos then return end

		local normal = net.ReadVector()
		if not normal then return end

		-- This is mega hacky, but we needed a place to keep the DoShootEffects function safe without adding bloat anywhere else
		local wepInfo = weapons.GetStored(className)
		if not wepInfo then return end

		local lastFiredOwner = net.ReadEntity()
		if IsValid(lastFiredOwner) then
			-- Stop the click-fizzle sound on the clientside
			lastFiredOwner:StopSound(wepInfo.Primary.DelayedShotSound)
		end

		wepInfo:DoShootEffects(pos, normal)
	end)
end