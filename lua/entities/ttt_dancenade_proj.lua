AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_entity"
ENT.Model = Model("models/weapons/w_eq_flashbang_thrown.mdl")
ENT.PrintName = "Dance Grenade"
ENT.Author = "Earu"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.CanPickup = false
ENT.Projectile = true

ENT.DanceRadius = 300
ENT.DanceDuration = 15
ENT.NextParticle = 0
ENT.FloatHeight = 100  -- How high to float
ENT.RiseSpeed = 40     -- How fast to rise (increased from 20)
ENT.SpinSpeed = 100    -- How fast to spin (increased from 50)
ENT.AccelerationRate = 1.5 -- Acceleration multiplier for rising

AccessorFunc(ENT, "thrower", "Thrower")

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/weapons/w_grenade.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:Wake()
		end

		self.DetonateTime = CurTime() + 3
		self.IsFloating = false
		self.OriginalPos = nil

		SafeRemoveEntityDelayed(self, self.DanceDuration + self.DetonateTime)
		return self.BaseClass.Initialize(self)
	end

	function ENT:Think()
		if self.DetonateTime and CurTime() > self.DetonateTime then
			self:Explode()
		end

		if self.DanceEnd and CurTime() > self.DanceEnd then
			SafeRemoveEntity(self)
			return
		end

		-- Handle floating after detonation
		if self.IsFloating then
			local phys = self:GetPhysicsObject()
			if IsValid(phys) then
				-- Get current height above original position
				local currentHeight = self:GetPos().z - self.OriginalPos.z

				if currentHeight < self.FloatHeight then
					-- Still rising with acceleration
					if not self.CurrentRiseSpeed then
						self.CurrentRiseSpeed = self.RiseSpeed
					else
						self.CurrentRiseSpeed = math.min(self.CurrentRiseSpeed * self.AccelerationRate, self.RiseSpeed * 3)
					end
					phys:SetVelocity(Vector(0, 0, self.CurrentRiseSpeed))
				else
					-- Hovering at target height, continuous spin
					phys:SetVelocity(Vector(0, 0, 0))
				end

				-- Always spinning, even while rising
				self:SetAngles(Angle(
					math.sin(CurTime() * 0.5) * 15, -- Slight bobbing pitch
					CurTime() * self.SpinSpeed % 360, -- Continuous yaw rotation
					math.sin(CurTime() * 0.7) * 10  -- Slight bobbing roll
				))

				-- Keep it in the same X,Y position with slight wobble
				local pos = self:GetPos()
				pos.x = self.OriginalPos.x + math.sin(CurTime() * 1.5) * 5
				pos.y = self.OriginalPos.y + math.cos(CurTime() * 1.2) * 5
				self:SetPos(pos)
			end
		end

		self:NextThink(CurTime())
		return true
	end

	function ENT:Explode()
		self.DanceEnd = CurTime() + self.DanceDuration

		local pos = self:GetPos()
		self.OriginalPos = pos -- Store position for floating

		-- Make it start floating
		self.IsFloating = true
		self:SetMoveType(MOVETYPE_VPHYSICS) -- Ensure it can move

		-- Remove gravity
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableGravity(false)
			phys:Wake()
		end

		-- Store affected players to repeatedly apply dance
		self.AffectedPlayers = {}

		for _, ply in ipairs(ents.FindInSphere(pos, self.DanceRadius)) do
			if ply:IsPlayer() and ply:Alive() then
				ply:Lock()
				ply:DoAnimationEvent(ACT_GMOD_TAUNT_DANCE)

				-- Add player to affected list
				table.insert(self.AffectedPlayers, ply)

				-- Create timer to unlock players when effect ends
				timer.Simple(self.DanceDuration, function()
					if IsValid(ply) then
						ply:UnLock()
					end
				end)
			end
		end

		-- Setup repeating timer to keep players dancing
		self.DanceLoopTimer = "DanceLoop_" .. self:EntIndex()
		timer.Create(self.DanceLoopTimer, 8, 0, function()
			if not IsValid(self) then
				timer.Remove(self.DanceLoopTimer)
				return
			end

			-- Make all affected players dance again
			for _, ply in ipairs(self.AffectedPlayers) do
				if IsValid(ply) and ply:Alive() then
					ply:DoAnimationEvent(ACT_GMOD_TAUNT_DANCE)
				end
			end
		end)
	end

	function ENT:OnRemove()
		-- Clean up dance loop timer
		if self.DanceLoopTimer then
			timer.Remove(self.DanceLoopTimer)
		end

		-- Make sure we unlock any players if removed early
		if self.AffectedPlayers then
			for _, ply in ipairs(self.AffectedPlayers) do
				if IsValid(ply) then
					ply:UnLock()
				end
			end
		end
	end
end

if CLIENT then
	function ENT:Initialize()
		sound.PlayURL("https://raw.githubusercontent.com/Metastruct/garrysmod-chatsounds/refs/heads/master/sound/chatsounds/autoadd/music/youre%20out%20of%20touch.ogg", "3d", function(station)
			if IsValid(station) then
				station:SetPos(self:GetPos())
				station:SetVolume(2)
				station:Play()
				self.Sound = station
			end
		end)

		return self.BaseClass.Initialize(self)
	end

	function ENT:OnRemove()
		if IsValid(self.Sound) then
			self.Sound:Stop()
		end
	end

	local WHITE_MAT = Material("models/debug/debugwhite")
	function ENT:Draw()
		local col = HSVToColor(CurTime() * 300 % 360, 1, 1)
		render.SetColorModulation(col.r / 255, col.g / 255, col.b / 255)
		render.MaterialOverride(WHITE_MAT)
		self:DrawModel()
		render.SetColorModulation(1, 1, 1)
		render.MaterialOverride()

		if self.NextParticle < CurTime() then
			local pos = self:WorldSpaceCenter()

			local emitter = ParticleEmitter(pos)
			for i = 1, 5 do
				local particle = emitter:Add("sprites/glow04_noz", pos)

				particle:SetVelocity(VectorRand() * 50)
				particle:SetDieTime(0.5)
				particle:SetStartAlpha(255)
				particle:SetEndAlpha(0)
				particle:SetStartSize(10)
				particle:SetEndSize(0)
				particle:SetRoll(math.Rand(0, 360))
				particle:SetRollDelta(math.Rand(-2, 2))
				particle:SetColor(
					math.random(50, 255),
					math.random(50, 255),
					math.random(50, 255)
				)
			end

			-- Add light ray particles
			local angles = self:GetAngles()
			local forward = angles:Forward()
			local right = angles:Right()

			for i = 1, 8 do
				local angle = math.rad(i * 45)
				local rayDir = forward * math.sin(angle) + right * math.cos(angle)
				rayDir:Normalize()

				local rayLength = 150 -- Length of the light ray
				for j = 0, 10 do -- Create multiple particles along the ray
					local rayPos = pos + rayDir * (j * rayLength / 10)
					local rayParticle = emitter:Add("sprites/glow04_noz", rayPos)

					if rayParticle then
						rayParticle:SetDieTime(0.2)
						rayParticle:SetStartAlpha(150)
						rayParticle:SetEndAlpha(0)
						rayParticle:SetStartSize(10)
						rayParticle:SetEndSize(5)
						rayParticle:SetColor(
							math.sin(CurTime() + i) * 127 + 128,
							math.sin(CurTime() + i + 2) * 127 + 128,
							math.sin(CurTime() + i + 4) * 127 + 128
						)
					end
				end
			end

			emitter:Finish()

			self.NextParticle = CurTime() + 0.1
		end
	end

	function ENT:Think()
		if IsValid(self.Sound) then
			self.Sound:SetPos(self:GetPos())
		end

		if not self.LightPos then
			self.LightPos = 0
		end

		local dlight = DynamicLight(self:EntIndex())
		if dlight then
			dlight.pos = self:WorldSpaceCenter()
			dlight.r = math.sin(CurTime() * 2) * 127 + 128
			dlight.g = math.sin(CurTime() * 2 + 2) * 127 + 128
			dlight.b = math.sin(CurTime() * 2 + 4) * 127 + 128
			dlight.brightness = 2
			dlight.Decay = 1000
			dlight.Size = 200
			dlight.DieTime = CurTime() + 0.1
		end

		-- Draw light beams
		local pos = self:WorldSpaceCenter()
		local angles = self:GetAngles()

		for i = 1, 4 do
			local beamAngle = angles.y + (i * 90) + (CurTime() * 30 % 360)
			local beamDir = Vector(math.cos(math.rad(beamAngle)), math.sin(math.rad(beamAngle)), 0.3)
			beamDir:Normalize()

			local beamEnd = pos + beamDir * 200
			local color = Color(
				math.sin(CurTime() + i) * 127 + 128,
				math.sin(CurTime() + i + 2) * 127 + 128,
				math.sin(CurTime() + i + 4) * 127 + 128
			)

			render.SetMaterial(Material("sprites/light_glow02_add"))
			render.DrawBeam(pos, beamEnd, 10, CurTime(), CurTime() + 1, color)
		end
	end
end