if not SERVER then return end

local function chainsaw_attack(self)
	local owner = self:GetOwner()

	--Trace shit from weapon_fists.lua packed with Gmod
	local trace = util.TraceLine({
		start = owner:GetShootPos(),
		endpos = owner:GetShootPos() + owner:GetAimVector() * 75,
		filter = owner
	})

	if not IsValid(trace.Entity) then
		trace = util.TraceHull({
			start = owner:GetShootPos(),
			endpos = owner:GetShootPos() + owner:GetAimVector() * 75,
			filter = owner,
			mins = Vector(-10, -10, -8),
			maxs = Vector(10, 10, 8)
		})
	end

	self:SendWeaponAnim(ACT_VM_HITCENTER)
	owner:SetAnimation(PLAYER_ATTACK1)

	if trace.Entity:IsValid() then
		if SERVER then
			if trace.Entity:GetClass() == "func_breakable" or trace.Entity:GetClass() == "func_breakable_surf" then
				local bullet = {}
				bullet.Num = self.GunShots
				bullet.Src = owner:GetShootPos()
				bullet.Dir = owner:GetAimVector()
				bullet.Spread = Vector(0, 0, 0)
				bullet.Tracer = 0
				bullet.Force = 1
				bullet.Damage = 40
				owner:FireBullets(bullet)
			else
				trace.Entity:TakeDamage(1, owner)
			end
		end

		if trace.Entity:IsPlayer() or trace.Entity:IsNPC() then
			self.RSaw_Attack:ChangePitch(50, 0.75)
			local BLOOOD = EffectData()
			BLOOOD:SetOrigin(trace.HitPos)
			BLOOOD:SetMagnitude(math.random(1, 3))
			BLOOOD:SetEntity(trace.Entity)
			util.Effect("bloodstream", BLOOOD)
		end
	else
		self.RSaw_Attack:ChangePitch(100, 0.75)
	end

	if trace.HitWorld then
		self:SendWeaponAnim(ACT_VM_MISSCENTER)
		local effectdata = EffectData()
		effectdata:SetOrigin(trace.HitPos)
		effectdata:SetNormal(trace.HitNormal)
		effectdata:SetMagnitude(1)
		effectdata:SetScale(2)
		effectdata:SetRadius(1)
		util.Effect("Sparks", effectdata)
		sound.Play("npc/manhack/grind" .. math.random(1, 5) .. ".wav", trace.HitPos, 75, 150)
	end

	self.Weapon:SetNextPrimaryFire(CurTime() + 0.01)
	self.Weapon:SetNextSecondaryFire(CurTime() + 0.25)
end

hook.Add("OnEntityCreated", "Chainsaw Balancing", function(ent)
	if ent:GetClass() == "weapon_chainsaw_new" then
		ent.PrimaryAttack = chainsaw_attack
	end
end)
