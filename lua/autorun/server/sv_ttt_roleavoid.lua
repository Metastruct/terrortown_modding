---@param ply Player
---@param role number
---@return boolean
local function getPlayerAvoidsRole(ply, role)
	return ply:GetInfoNum("ttt2_avoidrole_" .. role, 0) == 1
end

---@param roleMap {[Player]: number}
local function ReallocateRoles(roleMap)
	local NO_ROLE_ASSIGNED = -1

	-- Get all the roles that are in-play for this round, and a list of players
	---@type Player[]
	local players = {}
	---@type number[]
	local availableRoles = {}
	for ply, v in next, roleMap do
		if v ~= roles.INNOCENT.id then
			availableRoles[#availableRoles + 1] = v
		end
		players[#players + 1] = ply
		roleMap[ply] = NO_ROLE_ASSIGNED
	end

	-- Assign roles to players
	for _, role in next, availableRoles do
		local roleName = roles.GetByIndex(role).name
		local forced = false

		-- Get a list of players that can be assigned this role
		---@type Player[]
		local validPlayers = {}
		for _, ply in next, players do
			if not getPlayerAvoidsRole(ply, role) and roleMap[ply] == NO_ROLE_ASSIGNED then
				validPlayers[#validPlayers + 1] = ply
			end
		end

		-- If there are no players that can be assigned this role, consider
		-- everyone and send a message to them
		if #validPlayers == 0 then
			validPlayers = players
			forced = true
		end

		-- Assign the role to a random player
		local ply = validPlayers[math.random(#validPlayers)]
		print("Giving role " ..
			roleName ..
			" to " .. ply:Nick() .. " (forced: " .. tostring(forced) .. ") (candidates: " .. #validPlayers .. ")")
		roleMap[ply] = role

		-- Send a message to the player if they were forced into the role
		if forced then
			ply:ChatPrint("Sorry; there were no players that could be assigned the role " ..
				roleName .. ", so you were forced into it.")
		end
	end

	-- Everyone that wasn't assigned a role is now an innocent
	for _, ply in next, players do
		if roleMap[ply] == NO_ROLE_ASSIGNED then
			roleMap[ply] = roles.INNOCENT.id
		end
	end
end

hook.Add("TTT2ModifyFinalRoles", "meta_avoid_roles", ReallocateRoles)
