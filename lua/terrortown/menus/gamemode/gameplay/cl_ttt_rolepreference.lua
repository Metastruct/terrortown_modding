CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"

CLGAMEMODESUBMENU.priority = 50
CLGAMEMODESUBMENU.title = "Role Preferences"
CLGAMEMODESUBMENU.icon = Material("vgui/ttt/vskin/helpscreen/roles")

LANG.AddToLanguage("en", "submenu_rolepreference_desc",
	"Role Preferences allow you to choose how likely you are to be assigned a specific role, or to avoid being assigned a specific role entirely.")

---@param parent Panel
function CLGAMEMODESUBMENU:Populate(parent)
	local form = vgui.CreateTTT2Form(parent, "Role Avoidance")

	form:MakeHelp({ label = "submenu_rolepreference_desc" })

	local roleList = {}
	for _, role in pairs(roles.roleList) do
		if role.index ~= nil and role.index ~= roles.INNOCENT.index and not role.notSelectable then
			roleList[#roleList + 1] = role
		end
	end

	-- Sort the roles by name
	table.sort(roleList, function(a, b)
		return a.name < b.name
	end)

	for _, role in ipairs(roleList) do
		local roleName = role.name

		form:MakeSlider({
			label = roleName,
			convar = "ttt2_rolepreference_" .. roleName,
			min = 0,
			max = 1,
			decimal = 2,
			default = 1,
		})
	end
end
