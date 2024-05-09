CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"

CLGAMEMODESUBMENU.priority = 200
CLGAMEMODESUBMENU.title = "submenu_roleavoid_title"
CLGAMEMODESUBMENU.icon = Material("vgui/ttt/vskin/helpscreen/roles")

---@param parent Panel
function CLGAMEMODESUBMENU:Populate(parent)
	local form = vgui.CreateTTT2Form(parent, "header_roleavoid")

	---@type {[1]: string, [2]: number}[]
	local roles = {}
	for _, role in next, roles.roleList do
		roles[#roles + 1] = { role.name, role.index }
	end

	-- Sort the roles by name
	table.sort(roles, function(a, b)
		return a[1] < b[1]
	end)

	for _, role in ipairs(roles) do
		local roleName = role[1]
		local roleIndex = role[2]

		form:MakeCheckBox({
			label = roleName,
			serverConvar = "ttt2_avoidrole_" .. roleIndex,
		})
	end
end
