CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"

CLGAMEMODESUBMENU.priority = 200
CLGAMEMODESUBMENU.title = "submenu_roleavoid_title"
CLGAMEMODESUBMENU.icon = Material("vgui/ttt/vskin/helpscreen/roles")

local roleConvarsCreated = false

---@param parent Panel
function CLGAMEMODESUBMENU:Populate(parent)
	local form = vgui.CreateTTT2Form(parent, "header_roleavoid")

	---@type {[1]: string, [2]: number}[]
	local roleList = {}
	for _, role in next, roles.roleList do
		roleList[#roleList + 1] = { role.name, role.index }
	end

	-- Sort the roles by name
	table.sort(roleList, function(a, b)
		return a[1] < b[1]
	end)

	for _, role in ipairs(roleList) do
		local roleName = role[1]
		local roleIndex = role[2]

		if roleName ~= nil and roleIndex ~= nil then
			form:MakeCheckBox({
				label = roleName,
				serverConvar = "ttt2_avoidrole_" .. roleIndex,
			})

			if not roleConvarsCreated then
				CreateClientConVar("ttt2_avoidrole_" .. roleIndex, "0", true, true)
			end
		end
	end

	roleConvarsCreated = true
end
