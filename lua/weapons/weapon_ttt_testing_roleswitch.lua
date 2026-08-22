if SERVER then
	AddCSLuaFile()
else
	SWEP.PrintName = "Role Switcher"
	SWEP.Author = "TW1STaL1CKY"
	SWEP.Slot = 8

	SWEP.DrawAmmo = false

	SWEP.ViewModelFlip = false
	SWEP.ViewModelFOV = 54
end

DEFINE_BASECLASS("weapon_tttbase")

SWEP.HoldType = "revolver"

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_pistol.mdl"
SWEP.WorldModel = "models/weapons/w_suitcase_passenger.mdl"
SWEP.idleResetFix = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = 0.2
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Delay = 0.05
SWEP.Secondary.Ammo = "none"

SWEP.DeploySpeed = 12

SWEP.Kind = WEAPON_EXTRA

SWEP.AllowDrop = false
SWEP.overrideDropOnDeath = DROP_ON_DEATH_TYPE_DENY
SWEP.NoSights = true

function SWEP:SetupDataTables()
	self:NetworkVar("Int", "SelectedRole")
end

function SWEP:Initialize()
	local allRoles = roles.GetList()

	table.sort(allRoles, function(a, b) return a.id < b.id end)

	local sortedRoles = {}
	for i = 1, #allRoles do
		local role = allRoles[i]

		sortedRoles[#sortedRoles + 1] = { id = role.id, name = role.name }
	end

	self.RoleList = sortedRoles
	self:SetSelectedRole(1)

	BaseClass.Initialize(self)
end

function SWEP:PrimaryAttack(worldsnd)
	-- This SWEP is for warmup mode only, clean self up if it isn't
	if not GetGlobal2Bool("ttt_warmup_mode", false) then
		if SERVER then
			self:Remove()
		end

		return
	end

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local now = CurTime()

	self:SetNextPrimaryFire(now + self.Primary.Delay)
	self:SetNextSecondaryFire(now + self.Secondary.Delay)

	local id = self:GetSelectedRole()
	local role = self.RoleList[id]

	if role.id == owner:GetSubRole() then return end

	owner:SetRole(role.id)

	if SERVER then
		local className = self:GetClass()

		SendFullStateUpdate()

		timer.Simple(0, function()
			if IsValid(owner) then
				local wep = owner:GetActiveWeapon()

				if not IsValid(wep) or wep:GetClass() != className then
					owner:SelectWeapon(className)
				end
			end
		end)
	else
		surface.PlaySound("weapons/m3/m3_insertshell.wav")
	end
end

function SWEP:SecondaryAttack()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	local delay = CurTime() + self.Secondary.Delay

	self:SetNextPrimaryFire(delay)
	self:SetNextSecondaryFire(delay)

	local currentId = self:GetSelectedRole()
	local maxId = #self.RoleList

	local newId = currentId + 1
	if newId > maxId then
		newId = 1
	end

	self:SetSelectedRole(newId)

	if CLIENT then
		self:UpdateHelpText()
	end
end

function SWEP:Reload() end

function SWEP:Deploy()
	if CLIENT then
		self:UpdateHelpText()
	end

	return true
end

if CLIENT then
	function SWEP:UpdateHelpText()
		local id = self:GetSelectedRole()
		local role = self.RoleList[id]

		local name = role and role.name or "---"

		self:AddTTT2HUDHelp("Swap to " .. name:upper(), "Cycle roles")
	end
end