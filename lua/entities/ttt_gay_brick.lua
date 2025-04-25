AddCSLuaFile()
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Author = "Earu"
ENT.Spawnable = false
ENT.PrintName = "Gay Brick"
ENT.ClassName = "gay_brick"
ENT.CanPickup = true
ENT.MaxRange = 500

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/weapons/tbrick01.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:StartMotionController(true)
		self:SetUseType(SIMPLE_USE)
		self.ShadowParams = {}

		timer.Simple(55, function()
			if not IsValid(self) then return end

			local expl = ents.Create("env_explosion")
			expl:SetPos(self:WorldSpaceCenter())
			expl:Spawn()
			expl:Fire("explode")

			for i = 1, math.random(4, 8) do
				local brick = ents.Create("ttt_brick_proj")
				brick:SetPos(self:WorldSpaceCenter() + VectorRand(-50, 50))
				brick:SetThrower(self:GetAttacker())
				brick:Spawn()

				local phys = brick:GetPhysicsObject()
				if IsValid(phys) then
					phys:Wake()
					phys:SetVelocity(VectorRand(-1000, 1000))
				end
			end

			SafeRemoveEntity(self)
			util.BlastDamage(self, self:GetAttacker(), self:WorldSpaceCenter(), self.MaxRange, 50)
		end)
	end

	function ENT:GetAttacker()
		return IsValid(self.Owner) and self.Owner or self
	end

	function ENT:Use(_, caller)
		caller:Kill()
	end

	function ENT:Think()
		if isnumber(self.NextDamage) and CurTime() < self.NextDamage then return end

		for _, ent in ipairs(ents.FindInSphere(self:WorldSpaceCenter(), self.MaxRange)) do
			if ent == self or ent:IsWeapon() then continue end

			local dmg = DamageInfo()
			dmg:SetAttacker(self:GetAttacker())
			dmg:SetInflictor(self)
			dmg:SetDamage(math.Round((1 - ent:GetPos():Distance(self:WorldSpaceCenter()) / self.MaxRange) * 8))
			dmg:SetDamageType(DMG_RADIATION)

			ent:TakeDamageInfo(dmg)
		end

		self.NextDamage = CurTime() + 1
		self:NextThink(CurTime() + 1)
		return true
	end

	function ENT:PhysicsSimulate(phys, delta)
		phys:Wake()

		local target_pos
		if IsValid(self.Target) and self.Target:IsPlayer() and self.Target:IsTerror() then
			target_pos = self.Target:EyePos() + Vector(0, 0, 30)
		else
			local tr = util.TraceLine({
				start = self:GetPos(),
				endpos = self:GetPos() - Vector(0, 0, 100),
				filter = self
			})

			target_pos = tr.HitPos + Vector(0, 0, 60)
		end

		self.ShadowParams.secondstoarrive = 2 -- How long it takes to move to pos and rotate accordingly - only if it could move as fast as it want - damping and max speed/angular will make this invalid (Cannot be 0! Will give errors if you do)
		self.ShadowParams.pos = target_pos -- Where you want to move to
		self.ShadowParams.angle = self:GetAngles() + Angle(0, 30, 0) -- Angle you want to move to
		self.ShadowParams.maxangular = 5000 --What should be the maximal angular force applied
		self.ShadowParams.maxangulardamp = 10000 -- At which force/speed should it start damping the rotation
		self.ShadowParams.maxspeed = 1000000 -- Maximal linear force applied
		self.ShadowParams.maxspeeddamp = 10000 -- Maximal linear force/speed before  damping
		self.ShadowParams.dampfactor = 0.8 -- The percentage it should damp the linear/angular force if it reaches it's max amount
		self.ShadowParams.teleportdistance = 0 -- If it's further away than this it'll teleport (Set to 0 to not teleport)
		self.ShadowParams.deltatime = delta -- The deltatime it should use - just use the PhysicsSimulate one
		phys:ComputeShadowControl(self.ShadowParams)
	end
end

if CLIENT then
	function ENT:Initialize()
		if IsValid(self.Channel) then return end

		sound.PlayURL("https://raw.githubusercontent.com/PAC3-Server/chatsounds/refs/heads/master/sounds/chatsounds/metal%20gear%20solid/mgs2%20yell%20dead%20cell%20vr%20remix%20loop.ogg", "3d", function(chan, err)
			if err or not IsValid(chan) then return end
			if IsValid(self.Channel) then return end

			chan:SetVolume(0.8)
			chan:SetPos(self:GetPos())
			chan:Play()

			self.Channel = chan
		end)
	end

	function ENT:Think()
		if not IsValid(self.Channel) then return end
		self.Channel:SetPos(self:GetPos())
	end

	local WHITE_MAT = Material("models/debug/debugwhite")
	function ENT:Draw()
		local col = HSVToColor(CurTime() * 300 % 360, 1, 1)
		render.SetColorModulation(col.r / 255, col.g / 255, col.b / 255)
		render.MaterialOverride(WHITE_MAT)
		self:DrawModel()
		render.SetColorModulation(1, 1, 1)
		render.MaterialOverride()

		local dlight = DynamicLight(self:EntIndex())
		if dlight then
			dlight.pos = self:WorldSpaceCenter()
			dlight.r = col.r
			dlight.g = col.g
			dlight.b = col.b
			dlight.brightness = 5
			dlight.decay = 1
			dlight.size = self.MaxRange + 400
			dlight.dietime = CurTime() + 0.25
		end
	end

	function ENT:OnRemove()
		if IsValid(self.Channel) then
			self.Channel:Stop()
		end
	end
end