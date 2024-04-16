--- @ignore

CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"

CLGAMEMODESUBMENU.priority = 99
CLGAMEMODESUBMENU.title = "submenu_guide_roles_title"

local Key = Key
local TryT = LANG.TryTranslation
local GetPT = LANG.GetParamTranslation
local cos = math.cos
local abs = math.abs

local highlightColor = Color(0, 255, 0)

local mg = 10 -- margin
local pd = 10 -- padding
local iconSize = 112

local specialCases = {
	["traitor"] = function(params) return GetPT("info_popup_traitor_alone", params) end,
	["executioner"] = function(params) return GetPT("ttt2_desc_executioner", params) end,
	["sacrifice"] = function(params) return GetPT("ttt2_desc_sacrifice", params) end,
}
local namedTeams = {
	["nones"] = 0
}

for k,v in ipairs(roles.GetAvailableTeams()) do
	namedTeams[v] = k
end

function CLGAMEMODESUBMENU:Populate(parent)
	self.Parent = parent

	parent:GetCanvas():DockPadding(10, 10, 10, 10)

	self:CreateRoleList()

	self:AddHook()
end

function CLGAMEMODESUBMENU:CreateRoleList()
	local parent = self.Parent

	parent:Clear()

	local menukey = Key("+menu_context", "C")

	local sortedRoles = roles.GetList()
	local lply = LocalPlayer()
	self.CurrentPlayerRole = lply:GetRole()
	local currentRole = self.CurrentPlayerRole
	table.sort(sortedRoles, function(a, b)
		if a.index == currentRole then return true end
		if b.index == currentRole then return false end
		if namedTeams[a.defaultTeam] == namedTeams[b.defaultTeam] then return a.index < b.index end
		return namedTeams[a.defaultTeam] < namedTeams[b.defaultTeam]
	end)

	for _, role in ipairs(sortedRoles) do
		if role.notSelectable then continue end

		local container = parent:Add("DContentPanelTTT2")
		container:Dock(TOP)
		container:SetHeight(iconSize)
		container:DockMargin(0, 0, 0, mg)
		container:DockPadding(pd, pd, pd, pd)
		container.Paint = function(s, w, h)
			draw.RoundedBox(8, 0, 0, w, h, vskin.GetBackgroundColor())

			if currentRole == role.index then
				highlightColor.a = 8 + 4 * abs(cos(RealTime() * 6))

				draw.RoundedBox(8, 0, 0, w, h, highlightColor)
			end
		end

		local roleIcon = container:Add("DRoleImageTTT2")
		roleIcon:Dock(LEFT)
		roleIcon:SetWidth(iconSize - mg - mg)
		roleIcon:SetMaterial(role.iconMaterial)
		roleIcon:SetColor(role.color)
		roleIcon:DockMargin(0, 0, mg, 0)
		roleIcon:SetTooltip(TryT(role.defaultTeam))

		local name = container:Add("DLabel")
		name:Dock(TOP)
		name:SetFont("DermaLarge")
		name:SetTextColor(vskin.GetTitleTextColor())
		name:SetText(TryT(role.name))
		name:SizeToContents()
		name:DockMargin(0, 0, 0, 5)

		local descContainer = container:Add("DScrollPanelTTT2")
		descContainer:Dock(FILL)
		descContainer:SetVerticalScrollbarEnabled(true)

		local desc = descContainer:Add("DLabel")
		desc:SetFont("HudHintTextLarge")
		desc:Dock(TOP)
		desc:SetWrap(true)
		desc:SetAutoStretchVertical(true)

		local descTextParams = { menukey = menukey }
		local defaultDescText = GetPT("info_popup_" .. role.name, descTextParams)
		local descText = isfunction(specialCases[role.name]) and specialCases[role.name](descTextParams) or defaultDescText
		desc:SetText(descText)
	end
end

function CLGAMEMODESUBMENU:AddHook()
	hook.Add("PreDrawHUD", "TTT2RoleGuideUpdate", function()
		if not IsValid(self.Parent) then hook.Remove("PreDrawHUD", "TTT2RoleGuideUpdate") end

		local lply = LocalPlayer()
		local newRole = lply:GetRole()

		if self.CurrentPlayerRole ~= newRole then
			self:CreateRoleList()
		end
	end)
end
