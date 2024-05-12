CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"

CLGAMEMODESUBMENU.priority = 50
CLGAMEMODESUBMENU.title = "Role Avoidance"
CLGAMEMODESUBMENU.icon = Material("vgui/ttt/vskin/helpscreen/roles")

LANG.AddToLanguage("en", "submenu_avoidrole_desc",
	"Role Avoidance allows you to avoid being assigned a specific role. Selecting a role here will attempt to assign that role to someone else first, and only assign it to you if no one else can take it. (You'll receive a message if you're forced into a role.)")

local roleConvarsCreated = false

---@param parent Panel
function CLGAMEMODESUBMENU:Populate(parent)
	local form = vgui.CreateTTT2Form(parent, "Role Avoidance")

	form:MakeHelp({ label = "submenu_avoidrole_desc" })

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

		if not roleConvarsCreated then
			CreateClientConVar("ttt2_avoidrole_" .. roleName, "0", true, true)
		end

		form:MakeCheckBox({
			label = roleName,
			convar = "ttt2_avoidrole_" .. roleName,
		})
	end

	roleConvarsCreated = true
end
