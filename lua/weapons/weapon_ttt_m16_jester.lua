local className = "weapon_ttt_m16_jester"
local hookName = "TTTJesterGun"

if SERVER then
	AddCSLuaFile()
	resource.AddFile("materials/vgui/ttt/icon_m16_jester.vmt")
else
	SWEP.PrintName = "Jester M16"

	SWEP.EquipMenuData = {
		type = "item_weapon",
		desc = "A Jester variant of the M16 rifle. It deals zero damage to terrorists and holding it saves you from a fatal blow, allowing you to mimic a Jester.\n\nInfinite ammo.\n\nIf a Jester is given this weapon, they will \"claim it\" and become bloodthirsty..."
	}

	SWEP.Icon = "vgui/ttt/icon_m16_jester"
end

DEFINE_BASECLASS("weapon_ttt_m16")

SWEP.ClassName = className

SWEP.Primary.JesterDelay = 0.15
SWEP.Primary.JesterRecoil = 1.4

SWEP.Kind = WEAPON_EQUIP
SWEP.CanBuy = {ROLE_TRAITOR}
SWEP.LimitedStock = true

function SWEP:SetupDataTables()
	BaseClass.SetupDataTables(self)

	self:NetworkVar("Entity", "JesterOwner")
	self:NetworkVar("Bool", "Reloading")
end

function SWEP:Initialize()
	-- This has to be manually set so ammo entities can see it
	self.AmmoEnt = BaseClass.AmmoEnt

	BaseClass.Initialize(self)
end

function SWEP:IsWorthyOfPower(pl)
	pl = pl or self:GetOwner()

	return IsValid(pl) and pl:IsPlayer() and self:GetJesterOwner() == pl and pl:GetTeam() == TEAM_TRAITOR
end

function SWEP:PrimaryAttack(worldsnd)
	local owner = self:GetOwner()

	self._isJester = self:IsWorthyOfPower(owner)

	local origDelay = self.Primary.Delay

	if self._isJester then
		self.Primary.Delay = self.Primary.JesterDelay
	end

	BaseClass.PrimaryAttack(self, worldsnd)

	if self._isJester then
		self._isJester = nil
		self.Primary.Delay = origDelay
	end
end

function SWEP:ShootBullet(dmg, recoil, numbul, cone)
	local isJester = self._isJester

	BaseClass.ShootBullet(
		self,
		dmg, -- A hook will handle this properly
		isJester and self.Primary.JesterRecoil or recoil,
		numbul,
		cone)
end

function SWEP:Reload()
	if self:Clip1() == self.Primary.ClipSize then return end

	local owner = self:GetOwner()
	local isJester = self:IsWorthyOfPower(owner)

	local vm, isReloading

	-- Always allow reloading even when out of ammo by giving 1 bullet then taking it away right after teehee
	if SERVER then owner:GiveAmmo(1, self:GetPrimaryAmmoType(), true) end

	if isJester then
		-- Perform faster reload - the only way to speed up DefaultReload is to use a shorter viewmodel animation, then immediately play the reload animation after... very hacky
		if self:DefaultReload(ACT_VM_ATTACH_SILENCER) then
			isReloading = true

			owner:SetAnimation(PLAYER_RELOAD)
			self:SendWeaponAnim(ACT_VM_RELOAD)
			owner:GetViewModel():SetPlaybackRate(1.475)
		end
	else
		-- Perform normal reload
		isReloading = self:DefaultReload(self.ReloadAnim)
	end

	if SERVER then owner:RemoveAmmo(1, self:GetPrimaryAmmoType()) end

	if isReloading then
		self:SetReloading(true)
	end

	self:SetIronsights(false)
	self:SetZoom(false)
end

function SWEP:Think()
	if self:GetReloading() then
		self:SetReloading(false)

		local owner = self:GetOwner()

		if IsValid(owner) and owner:IsPlayer() then
			local primaryAmmoId = self:GetPrimaryAmmoType()
			local ammoCount = owner:GetAmmoCount(primaryAmmoId)

			if ammoCount > 0 then
				owner:SetAmmo(ammoCount + self.Primary.ClipSize - self:Clip1(), primaryAmmoId)
			else
				self:SetClip1(self.Primary.ClipSize)
			end
		end
	end

	BaseClass.Think(self)
end

if SERVER then
	function SWEP:Equip(newOwner)
		self:SetReloading(false)

		BaseClass.Equip(self, newOwner)

		local jesterOwner = self:GetJesterOwner()
		local isTaken = IsValid(jesterOwner)

		if newOwner:IsPlayer() and newOwner:GetTeam() == TEAM_JESTER then
			if isTaken then
				if newOwner != jesterOwner then
					LANG.Msg(newOwner, "Another Jester has claimed this weapon. It rejects your power...", nil, MSG_MSTACK_PLAIN)
				end
			else
				self:SetJesterOwner(newOwner)

				newOwner:SetRole(ROLE_TRAITOR)
				SendFullStateUpdate()

				local traitors, others = {}, {}

				for k,v in ipairs(player.GetAll()) do
					if v:GetRole() == ROLE_TRAITOR then
						traitors[#traitors + 1] = v
					else
						others[#others + 1] = v
					end
				end

				LANG.Msg(traitors, "The Jester '{name}' has joined the traitors!\nThe others will be hunting them down...", { name = newOwner:Nick() }, MSG_MSTACK_ROLE)
				LANG.Msg(others, "Kill Jester.", nil, MSG_MSTACK_PLAIN)

				local screenFadeCol = newOwner:GetRoleColor()
				screenFadeCol = Color(screenFadeCol.r, screenFadeCol.g, screenFadeCol.b, 90)

				newOwner:ScreenFade(SCREENFADE.IN, screenFadeCol, 3, 0)

				roles.JESTER.SpawnJesterConfetti(newOwner)

				self:CallOnClient("OnBecomeJesterOwner")
			end
		end
	end

	hook.Add("PlayerTakeDamage", hookName, function(pl, infl, attacker, dmgAmt, dmgInfo)
		if not IsValid(attacker) or not attacker:IsPlayer() then return end

		local wep = infl == attacker and attacker:GetActiveWeapon() or infl

		if dmgInfo:IsDamageType(DMG_BULLET)
		and IsValid(wep)
		and wep:GetClass() == className
		and wep:GetJesterOwner() != attacker then
			-- Nullify Jester M16 damage (except when the turned jester uses it)
			dmgInfo:ScaleDamage(0)
			dmgInfo:SetDamage(0)
		else
			-- If someone holding the Jester M16 about to be killed (except the turned jester), consume the M16 and let them live
			wep = pl:GetActiveWeapon()

			if IsValid(wep) and wep:GetClass() == className and wep:GetJesterOwner() != pl then
				local dmgScaled = dmgInfo:GetDamage() * attacker:GetDamageFactor()

				-- If the victim is about to die from the shot, give them HP to negate it and handle everything
				if math.ceil(dmgScaled) >= pl:Health() then
					pl:SetHealth(math.floor(30 + dmgScaled))

					wep:Remove()

					roles.JESTER.SpawnJesterConfetti(pl)
					LANG.Msg(pl, "The Jester M16 popped in your hands and kept you alive!", nil, MSG_MSTACK_ROLE)
				end
			end
		end
	end)
else
	function SWEP:InitializeCustomModels()
		self:AddCustomViewModel("vmodel", {
            type = "Model",
            model = "models/balloons/balloon_dog.mdl",
            bone = "v_weapon.m4_Parent",
            rel = "",
            pos = Vector(-0.3, -2.2, -4),
            angle = Angle(-85, 90, 0),
            size = Vector(0.08, 0.05, 0.08),
            color = Color(255, 40, 195),
            surpresslightning = false,
            material = "",
            skin = 0,
            bodygroup = {},
        })
	end

	function SWEP:OnBecomeJesterOwner()
		EmitSound("physics/glass/glass_sheet_impact_hard1.wav", vector_origin, -2, CHAN_AUTO, 1, 0, 0, 30, 26)
		EmitSound("ambient/atmosphere/hole_hit5.wav", vector_origin, -2, CHAN_AUTO, 1, 0, 0, 100)

		LANG.Msg("You picked up a {name} - it strips your Jester powers and supercharges itself in your hands! It's yours and yours only.", { name = self.PrintName }, MSG_MSTACK_ROLE)

		self.PrintName = self.PrintName .. " (Yours)"
	end
end