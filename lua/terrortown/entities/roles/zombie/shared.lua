if SERVER then
	AddCSLuaFile()

	resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_zombie.vmt")
end

roles.InitCustomTeam(ROLE.name, {
	icon = "vgui/ttt/dynamic/roles/icon_zombie",
	color = Color(165, 209, 78)
})

function ROLE:PreInitialize()
	self.color = Color(165, 209, 78)
	self.abbr = "zombie"
	self.surviveBonus = 0
	self.score.killsMultiplier = 2
	self.score.teamKillsMultiplier = 0
	self.score.bodyFoundMuliplier = 0
	self.preventFindCredits = true
	self.preventKillCredits = true
	self.preventTraitorAloneCredits = true
	self.preventWin = false
	self.unknownTeam = false
	self.defaultTeam = TEAM_TRAITOR

	self.conVarData = {
		pct = 0, -- necessary: percentage of getting this role selected (per player)
		maximum = 1, -- maximum amount of roles in a round
		minPlayers = 2, -- minimum amount of players until this role is able to get selected
		credits = 0, -- the starting credits of a specific role
		shopFallback = nil, -- granting the role access to the shop
		togglable = false, -- option to toggle a role for a client if possible (F1 menu)
		random = 33
	}
end