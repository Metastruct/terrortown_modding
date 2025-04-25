DEFINE_BASECLASS("weapon_tttbase")
if SERVER then
	AddCSLuaFile()
	resource.AddSingleFile("sound/weapons/electroshock/kyourselfnow.ogg")
	resource.AddSingleFile("sound/weapons/electroshock/yourlifeisnothing.ogg")
	resource.AddSingleFile("sound/weapons/electroshock/thunderclap.ogg")
end

SWEP.ClassName = "weapon_ttt_electroshock"
SWEP.PrintName = "Electroshock"
SWEP.Author = "Earu"
SWEP.Purpose = "You should kill yourself NOW!!!!"
SWEP.Slot = 0
SWEP.SlotPos = 4
SWEP.Spawnable = true
SWEP.ViewModel = Model("models/weapons/c_arms.mdl")
SWEP.WorldModel = ""
SWEP.ViewModelFOV = 54
SWEP.UseHands = true
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = "none"
SWEP.DrawAmmo = false
SWEP.HitDistance = 48

SWEP.Kind = WEAPON_EQUIP1
SWEP.AutoSpawnable = false
SWEP.CanBuy = { ROLE_TRAITOR }
SWEP.InLoadoutFor = { nil }
SWEP.LimitedStock = true
SWEP.AllowDrop = false
SWEP.IsSilent = false
SWEP.NoSights = false
SWEP.EquipMenuData = {
	type = "item_weapon",
	desc = "Be empowered by the power of Zeus!"
}

function SWEP:Initialize()
	self:SetHoldType("normal")
end

function SWEP:SetInMagic(inmagic)
	self:SetDTFloat(0, inmagic and CurTime() or 0)
end

function SWEP:InMagic()
	local f = self:GetDTFloat(0)
	if f > 0 then return CurTime() - f end
end

function SWEP:SetTargetVictim(e)
	self:SetDTEntity(0, e)
end

function SWEP:GetTargetVictim()
	return self:GetDTEntity(0)
end

local SEQUENCE_PATHS = {
	"sound/weapons/electroshock/yourlifeisnothing.ogg",
	"sound/weapons/electroshock/kyourselfnow.ogg",
}

function SWEP:PlaySequence(index, onFinish)
	if SERVER then return end
	if self.IsPlayingSequence and index == 1 then return end

	index = index or 1
	local owner = self:GetOwner()

	if index > #SEQUENCE_PATHS then
		if onFinish then
			onFinish()
		end

		self.IsPlayingSequence = false
		return
	end

	if not IsValid(owner) then
		self.IsPlayingSequence = false
		return
	end

	self.IsPlayingSequence = true
	sound.PlayURL(SEQUENCE_PATHS[index], "3d noplay", function(station)
		if IsValid(station) and IsValid(owner) then
			self.sndwindup = self.sndwindup or {}
			table.insert(self.sndwindup, station)

			station:SetPos(owner:EyePos())
			station:Play()

			timer.Simple(station:GetLength(), function()
				self:PlaySequence(index + 1, onFinish)
			end)
		end
	end)
end

function SWEP:PrimaryAttack()
	if self:InMagic() then return end

	local tr = util.TraceLine({
		start = self:GetOwner():GetShootPos(),
		endpos = self:GetOwner():GetShootPos() + self:GetOwner():GetAimVector() * 2048,
		filter = self:GetOwner(),
		mask = MASK_SHOT_HULL
	})

	if not tr.Entity:IsValid() or not tr.Entity:IsPlayer() then return end

	self:SetHoldType("magic")
	self:SetInMagic(true)

	local target_pos = tr.Entity:GetPos()
	if CLIENT and IsFirstTimePredicted() then
		timer.Simple(0.6, function()
			self:PlaySequence(1, function()
				sound.PlayFile("sound/weapons/electroshock/thunderclap.ogg", "3d noplay", function(station)
					if IsValid(station) then
						station:SetPos(target_pos)
						station:SetVolume(6)
						station:Play()
					end
				end)
			end)
		end)
	end

	self:SetTargetVictim(tr.Entity)
end

function SWEP:StartTargeting()
end

function SWEP:SecondaryAttack()
end

function SWEP:DealDamage(e)
	if CLIENT then return end

	local dmginfo = DamageInfo()
	local attacker = self:GetOwner()

	if not IsValid(attacker) then
		attacker = self
	end

	-- Create dramatic lightning strike from sky
	local skyPos = e:GetPos() + util.TraceLine({
		start = e:GetPos(),
		endpos = e:GetPos() + Vector(0, 0, 2048),
		filter = e,
		mask = MASK_SOLID
	}).HitPos
	local groundPos = e:GetPos()

	-- Create start point
	local startName = "sky_" .. e:EntIndex() .. "_" .. math.random(1000, 9999)
	local startPoint = ents.Create("info_target")
	if IsValid(startPoint) then
		startPoint:SetPos(skyPos)
		startPoint:SetName(startName)
		startPoint:Spawn()
		SafeRemoveEntityDelayed(startPoint, 2)
	end

	-- Create end point
	local endName = "ground_" .. e:EntIndex() .. "_" .. math.random(1000, 9999)
	local endPoint = ents.Create("info_target")
	if IsValid(endPoint) then
		endPoint:SetPos(groundPos)
		endPoint:SetName(endName)
		endPoint:Spawn()
		SafeRemoveEntityDelayed(endPoint, 2)
	end

	-- Main lightning beam
	local beam = ents.Create("env_beam")
	if IsValid(beam) and IsValid(startPoint) and IsValid(endPoint) then
		beam:SetPos(skyPos)
		-- Required keyvalues from Valve documentation
		beam:SetKeyValue("life", "0.5")
		beam:SetKeyValue("BoltWidth", "12")
		beam:SetKeyValue("NoiseAmplitude", "64") -- Max allowed noise
		beam:SetKeyValue("damage", "0") -- Damage handled separately
		beam:SetKeyValue("renderamt", "255") -- Full brightness
		beam:SetKeyValue("rendercolor", "150 200 255") -- Blue-white lightning color
		beam:SetKeyValue("texture", "sprites/physbeam.vmt")
		beam:SetKeyValue("TextureScroll", "35") -- Fast scroll rate
		beam:SetKeyValue("framerate", "10") -- Frames per 10 seconds
		beam:SetKeyValue("framestart", "0")
		beam:SetKeyValue("StrikeTime", "0.1") -- Time between random strikes if enabled

		-- Set endpoints by name as per documentation
		beam:SetKeyValue("LightningStart", startName)
		beam:SetKeyValue("LightningEnd", endName)

		-- Set proper flags (16 = StartSparks, 32 = EndSparks, 32768 = Temporary)
		beam:SetKeyValue("spawnflags", "32768")

		beam:Spawn()
		beam:Activate()
		beam:Fire("TurnOn", "", 0)
		beam:Fire("Kill", "", 0.75)
	end

	-- Create branching secondary beams
	for i = 1, 4 do
		-- Create random endpoint for branch
		local branchEndPos = groundPos + Vector(math.random(-120, 120), math.random(-120, 120), math.random(-20, 40))
		local branchEndName = "branch_end_" .. e:EntIndex() .. "_" .. i .. "_" .. math.random(1000, 9999)
		local branchEnd = ents.Create("info_target")
		if IsValid(branchEnd) then
			branchEnd:SetPos(branchEndPos)
			branchEnd:SetName(branchEndName)
			branchEnd:Spawn()
			SafeRemoveEntityDelayed(branchEnd, 2)
		end

		-- Create branch start point
		local branchStartName = "branch_start_" .. e:EntIndex() .. "_" .. i .. "_" .. math.random(1000, 9999)
		local branchStart = ents.Create("info_target")
		if IsValid(branchStart) then
			branchStart:SetPos(groundPos)
			branchStart:SetName(branchStartName)
			branchStart:Spawn()
			SafeRemoveEntityDelayed(branchStart, 2)
		end

		-- Create branch beam
		local branchBeam = ents.Create("env_beam")
		if IsValid(branchBeam) and IsValid(branchEnd) and IsValid(branchStart) then
			branchBeam:SetPos(groundPos)
			branchBeam:SetKeyValue("life", "0.3")
			branchBeam:SetKeyValue("BoltWidth", "4")
			branchBeam:SetKeyValue("NoiseAmplitude", "32")
			branchBeam:SetKeyValue("renderamt", "200")
			branchBeam:SetKeyValue("rendercolor", "150 200 255")
			branchBeam:SetKeyValue("texture", "sprites/physbeam.vmt")
			branchBeam:SetKeyValue("TextureScroll", "25")
			branchBeam:SetKeyValue("framerate", "10")
			branchBeam:SetKeyValue("framestart", "0")

			branchBeam:SetKeyValue("LightningStart", branchStartName)
			branchBeam:SetKeyValue("LightningEnd", branchEndName)

			-- Set proper flags (32 = EndSparks, 32768 = Temporary)
			branchBeam:SetKeyValue("spawnflags", "32|32768")

			branchBeam:Spawn()
			branchBeam:Activate()
			branchBeam:Fire("TurnOn", "", math.Rand(0, 0.2))
			branchBeam:Fire("Kill", "", 0.5)
		end

		-- Create scorch marks at branch end points
		util.Decal("SmallScorch", branchEndPos, branchEndPos + Vector(0, 0, -10))

		-- Add sparks at branch endpoints
		local effectdata = EffectData()
		effectdata:SetOrigin(branchEndPos)
		effectdata:SetMagnitude(2)
		effectdata:SetScale(2)
		effectdata:SetRadius(8)
		util.Effect("ElectricSpark", effectdata)
	end

	-- Explosion effect at impact
	for i = 1, math.random(1, 4) do
		local explosion = ents.Create("env_explosion")
		if IsValid(explosion) then
			explosion:SetPos(groundPos + Vector(math.random(-64, 64), math.random(-64, 64), math.random(-20, 40)))
			explosion:SetKeyValue("iMagnitude", "25")
			explosion:SetKeyValue("iRadiusOverride", "256")
			explosion:SetKeyValue("spawnflags", "4")
			explosion:Spawn()
			explosion:Fire("Explode", "", 0)
			SafeRemoveEntityDelayed(explosion, 0.5)
		end
	end

	-- Electric sparks at the center
	local sparks = EffectData()
	sparks:SetOrigin(groundPos)
	sparks:SetMagnitude(8)
	sparks:SetScale(5)
	sparks:SetRadius(100)
	util.Effect("ElectricSpark", sparks)

	-- Create scorch mark on ground
	util.Decal("Scorch", groundPos, groundPos + Vector(0, 0, -50))

	-- Add intense screen shake
	util.ScreenShake(groundPos, 20, 5, 1.5, 750)

	-- Deal massive damage
	e:SetModel("models/humans/charple0" .. math.random(1, 4) .. ".mdl")
	dmginfo:SetAttacker(attacker)
	dmginfo:SetInflictor(self)
	dmginfo:SetDamage(999999) -- Much higher damage
	dmginfo:SetDamageType(DMG_SHOCK + DMG_DISSOLVE) -- Dissolve effect for dramatic destruction
	dmginfo:SetDamageForce(VectorRand() * 500) -- Random force but no upward movement
	e:TakeDamageInfo(dmginfo)

	timer.Simple(0.5, function()
		if IsValid(e) and e:IsTerror() then
			e:Kill()
		end
	end)

	for _, surroundingEnt in ipairs(ents.FindInSphere(groundPos, 128)) do
		if IsValid(surroundingEnt) and surroundingEnt ~= attacker and (surroundingEnt:IsPlayer() or surroundingEnt:GetClass():match("prop_*")) then
			surroundingEnt:Ignite(surroundingEnt:IsPlayer() and 2 or 10)
		end
	end

	-- Dramatic thunder sounds
	sound.Play("ambient/atmosphere/thunder3.wav", groundPos, 180, 100, 3)
	sound.Play("ambient/atmosphere/thunder4.wav", groundPos, 180, 100, 3)

	-- Create light flash
	local light = ents.Create("light_dynamic")
	if IsValid(light) then
		light:SetPos(groundPos)
		light:SetKeyValue("brightness", "8")
		light:SetKeyValue("distance", "512")
		light:SetKeyValue("_light", "40 120 255 255")
		light:SetKeyValue("style", "1")
		light:Spawn()
		light:Fire("TurnOn", "", 0)
		light:Fire("Kill", "", 0.2)
	end

	SafeRemoveEntity(self)
end

function SWEP:OnDrop()
	self:EndMagic()
	self:Remove()
end

function SWEP:Holster()
	self:EndMagic()
	return true
end

function SWEP:Deploy()
	local cvar = GetConVar("sv_defaultdeployspeed")
	if not cvar then return end

	local speed = cvar:GetFloat()
	local vm = self:GetOwner():GetViewModel()
	vm:SendViewModelMatchingSequence(vm:LookupSequence("fists_draw"))
	vm:SetPlaybackRate(speed)

	self:SetNextPrimaryFire(CurTime() + vm:SequenceDuration() / speed)
	self:SetNextSecondaryFire(CurTime() + vm:SequenceDuration() / speed)

	return true
end

function SWEP:EndMagic()
	self:SetInMagic(false)
	self:SetHoldType("normal")
	self:SetNextPrimaryFire(CurTime() + 1)

	if self.sndwindup then
		for _, station in ipairs(self.sndwindup) do
			station:Stop()
		end

		self.sndwindup = nil
		self.IsPlayingSequence = false
	end
end

function SWEP:Think()
	local elapsed = self:InMagic()
	local owner = self:GetOwner()
	if elapsed then
		if not owner:IsValid() or not owner:KeyDown(IN_ATTACK) then return self:EndMagic() end
		if not IsValid(self:GetTargetVictim()) or (SERVER and not owner:TestPVS(self:GetTargetVictim())) then return self:EndMagic() end

		if elapsed > 4 then
			self:DealDamage(self:GetTargetVictim())
			self:EndMagic()
			self:SetNextPrimaryFire(CurTime() + 5)
		end
	end
end

function SWEP:DrawWorldModel()
end

function SWEP:DrawWorldModelTranslucent()
end

function SWEP:PreDrawViewModel()
	return true
end