local effectNetworkTag = "TTTBlunderbussFireEffect"
local className = "weapon_ttt_blunderbuss"

if SERVER then
	AddCSLuaFile()
	resource.AddFile("models/weapons/blunderbus.mdl")
	resource.AddFile("models/weapons/w_blunderbus.mdl")
	resource.AddFile("materials/models/weapons/blunderbus.vmt")
	resource.AddSingleFile("materials/models/weapons/blunderbus_skin.vmt")

	resource.AddFile("sound/weapons/blunderbuss_fire.mp3")
	resource.AddFile("sound/weapons/blunderbuss_fire_distant.mp3")

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
		desc = "A quite explosive blunderbuss loaded for only one shot."
	}

	SWEP.Icon = "vgui/ttt/icon_blunderbuss"
	SWEP.IconLetter = "c"
end

SWEP.HoldType = "shotgun"

SWEP.Base = "weapon_tttbase"
SWEP.ClassName = className

SWEP.ViewModel = "models/weapons/blunderbus.mdl"
SWEP.WorldModel = "models/weapons/w_blunderbus.mdl"

SWEP.Primary.Damage = 50
SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = 0.2
SWEP.Primary.Ammo = "none"
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

local propPhysicsClass = "prop_physics"
local propDynamicClass = "prop_dynamic"
local funcBreakableClass = "func_breakable"
local funcBreakableSurfClass = "func_breakable_surf"

function SWEP:SetupDataTables()
	self:NetworkVar("Bool", 0, "Fired")
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
	self:SetNextSecondaryFire(CurTime() + self.Secondary.Delay)

	if self:GetFired() then
		self:EmitSound("weapons/pistol/pistol_empty.wav", 64, math.random(40, 42), 0.2, CHAN_BODY)
		return
	end

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	self:SetClip1(0)
	self:SetFired(true)

	local spreadInfo = self.Primary.Spread
	local startPos = owner:GetShootPos()
	local viewVec = owner:GetAimVector()
	local viewAng = viewVec:Angle()

	local viewRight = viewAng:Right()
	local viewUp = viewAng:Up()
	local viewForward = viewAng:Forward()

	local firstTimePredicted = IsFirstTimePredicted()

	self.CurrentShot = {
		StartPos = startPos,
		Owner = owner,
		FirstPredict = firstTimePredicted
	}

	owner:LagCompensation(true)

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

	if firstTimePredicted then
		-- Close range sound
		self:EmitSound(")weapons/blunderbuss_fire.mp3", 90)

		local effectPos = owner:GetPos() + (viewVec * 32)
		effectPos.z = effectPos.z + 50

		-- Synced particles and long range sound
		if SERVER then
			net.Start(effectNetworkTag)
			net.WriteVector(effectPos)
			net.WriteVector(viewVec)
			net.SendOmit(owner)
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
		Damage = self.Primary.Damage,
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
				if not ent._gibbed then
					local hp = ent:Health()

					if (hp - scaledDamage) <= 0 then
						-- If it's a breakable prop and we're going to break it, run this epic workaround to let gibs spawn (weapon_fists does the same, it's cool)
						if isProp and hp > 0 then
							SuppressHostEvents(NULL)
							SuppressHostEvents(owner)

							-- Health() doesn't update after taking damage?? Flag that we've gibbed instead I guess :)
							ent._gibbed = true
						elseif className == funcBreakableSurfClass then
							-- Shatter the whole window
							ent:Fire("Shatter", "0.5 0.5 100")
						end
					end
				end

				local dmg = DamageInfo()
				dmg:SetAttacker(self.CurrentShot.Owner)
				dmg:SetInflictor(self)
				dmg:SetDamage(scaledDamage)
				dmg:SetDamageType(DMG_BULLET)
				dmg:SetDamagePosition(self.CurrentShot.StartPos)
				dmg:SetDamageForce(tr.Normal * 4000)

				ent:TakeDamageInfo(dmg)
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

if SERVER then
	function SWEP:Equip()
		self:SetNextPrimaryFire(CurTime() + 0.75)
		self:SetNextSecondaryFire(CurTime() + 0.75)
	end
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
		local owner = self:GetOwner()

		if IsValid(owner) and owner == LocalPlayer() and owner:IsTerror() then
			RunConsoleCommand("lastinv")
		end

		if IsValid(self.ClientsideWorldModel.Model) then
			self.ClientsideWorldModel.Model:Remove()
		end
	end

	function SWEP:GetViewModelPosition(pos, ang)
		local right = ang:Right()
		local up = ang:Up()
		local forward = ang:Forward()

		ang:RotateAroundAxis(right, -9)
		ang:RotateAroundAxis(up, -4)

		pos = pos + 2 * up
		pos = pos + -1 * forward

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

	net.Receive(effectNetworkTag, function()
		-- We want the effects' position to be synced up for all clients regardless of entity position, angles, and PVS
		local pos = net.ReadVector()
		if not pos then return end

		local normal = net.ReadVector()
		if not normal then return end

		-- This is mega hacky, but we needed a place to keep this function safe without adding bloat anywhere else
		local wepInfo = weapons.GetStored(className)
		if not wepInfo then return end

		wepInfo:DoShootEffects(pos, normal)
	end)
end