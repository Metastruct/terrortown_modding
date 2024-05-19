if SERVER then
	AddCSLuaFile()
	resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_bomber.vmt")
end

roles.InitCustomTeam(ROLE.name, {
	icon = "vgui/ttt/dynamic/roles/icon_bomber",
	color = Color(209, 179, 78)
})

function ROLE:PreInitialize()
	self.color = Color(209, 179, 78)
	self.abbr = "bomber"
	self.surviveBonus = 0

	self.score = {
		aliveTeammatesBonusMultiplier = 1,
		allSurviveBonusMultiplier = 0,
		bodyFoundMuliplier = 1,
		killsMultiplier = 2,
		suicideMultiplier = -1,
		surviveBonusMultiplier = 0,
		survivePenaltyMultiplier = 0,
		teamKillsMultiplier = -8,
		timelimitMultiplier = 0
	}

	self.preventTraitorAloneCredits = true
	self.preventWin = false
	self.unknownTeam = false
	self.defaultTeam = TEAM_INNOCENT

	self.karma = {
		enemyHurtBonusMultiplier = 1,
		enemyKillBonusMultiplier = 1,
		teamHurtPenaltyMultiplier = 0,
		teamKillPenaltyMultiplier = 0
	}

	self.conVarData = {
		credits = 0,
		maximum = 1,
		minPlayers = 7,
		pct = 0.15,
		random = 33,
		shopFallback = "DISABLED",
		togglable = true
	}
end

function ROLE:Initialize()
	roles.SetBaseRole(self, ROLE_INNOCENT)
end

if SERVER then
	hook.Add("TTT2PostPlayerDeath", "ttt_role_bomber", function(ply)
		if ply:GetSubRole() == roles.BOMBER.id then
			local c4 = ents.Create("ttt_c4")
			c4:SetPos(ply:EyePos() + Vector(0, 0, 10))
			c4:Spawn()
			c4:DropToFloor()

			c4:Arm(ply, 5) -- 5 seconds
			c4:SetRadius(300) -- reduce radius
			c4:SetRadiusInner(150)

			function c4:Defusable() return false end -- no defuse
		end
	end)
end