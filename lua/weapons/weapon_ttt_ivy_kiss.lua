if SERVER then
	AddCSLuaFile()
	resource.AddFile("materials/vgui/ttt/icon_ivy_kiss.vmt")
end

DEFINE_BASECLASS("weapon_ttt2_kiss")

SWEP.Kind = WEAPON_EQUIP
SWEP.CanBuy = { ROLE_TRAITOR }
SWEP.LimitedStock = true

if CLIENT then
	SWEP.PrintName = "Ivy Kiss"

	SWEP.EquipMenuData = {
		name = "Ivy Kiss",
		desc = "Show your love to someone in a deadly fashion.",
		type = "item_weapon"
	}

	SWEP.Icon = "vgui/ttt/icon_ivy_kiss"
end

local all_timers = {}
function SWEP:Kiss()
	local victim = self:GetKissVictim()
	if not IsValid(victim) then return end

	if SERVER then
		local owner = self:GetOwner()
		local dmg_info = DamageInfo()
		dmg_info:SetAttacker(owner)
		dmg_info:SetDamageType(DMG_POISON)
		dmg_info:SetInflictor(self)
		dmg_info:SetDamage(5)

		local timer_name = ("ivy_poison_[%d]"):format(victim:EntIndex())
		timer.Simple(5, function()
			table.insert(all_timers, timer_name)
			timer.Create(timer_name, 2, 0, function()
				if not IsValid(victim) or not victim:Alive() then
					timer.Remove(timer_name)
					return
				end

				victim:TakeDamageInfo(dmg_info)
			end)
		end)
	end

	self:SetHoldType("normal")
end

if SERVER then
	hook.Add("TTTEndRound", "weapon_ttt_ivy_kiss", function()
		for _, timer_name in ipairs(all_timers) do
			timer.Remove(timer_name)
		end
	end)

	hook.Add("TTTPlayerUsedHealthStation", "weapon_ttt_ivy_kiss", function(ply)
		local timer_name = ("ivy_poison_[%d]"):format(ply:EntIndex())
		timer.Remove(timer_name)
	end)
end