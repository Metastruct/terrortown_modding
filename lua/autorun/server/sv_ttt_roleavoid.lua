---@param ply Player
---@param roleName string
---@return number preference Between 0 and 1, inclusive
local function getPlayerRolePreference(ply, roleName)
	return math.Clamp(ply:GetInfoNum("ttt2_rolepreference_" .. roleName, 1), 0, 1)
end

---@param roleMap {[Player]: number}
local function ReallocateRoles(roleMap)
	local NO_ROLE_ASSIGNED = -1

	-- Get all the roles that are in-play for this round, and a list of players
	---@type Player[]
	local players = {}
	---@type number[]
	local availableRoles = {}
	for ply, v in pairs(roleMap) do
		if v ~= roles.INNOCENT.id then
			availableRoles[#availableRoles + 1] = v
		end
		players[#players + 1] = ply
		roleMap[ply] = NO_ROLE_ASSIGNED
	end

	-- Assign roles to players
	for _, role in pairs(availableRoles) do
		local roleName = roles.GetByIndex(role).name
		local forced = false

		-- Get a list of players and the cumulative preference for each player
		local preferenceSum = 0
		---@type {[1]: Player, [2]: number}[]
		local plyPreferences = {}
		for _, ply in pairs(players) do
			local preference = getPlayerRolePreference(ply, roleName)
			if preference > 0 and roleMap[ply] == NO_ROLE_ASSIGNED then
				preferenceSum = preferenceSum + preference
				plyPreferences[#plyPreferences + 1] = { ply, preference }
			end
		end

		---@type Player
		local ply = nil

		if preferenceSum == 0 then
			-- If there are no players that can be assigned this role, consider
			-- everyone and send a message to them
			forced = true
			ply = players[math.random(#players)]
		else
			-- Assign the role to a random player
			local choice = math.random() * preferenceSum
			for _, plyPreference in pairs(plyPreferences) do
				local potentialPly = plyPreference[1]
				local preference = plyPreference[2]
				if choice <= preference then
					ply = potentialPly
					break
				else
					choice = choice - preference
				end
			end
			if ply == nil then
				ErrorNoHalt("Failed to assign role " .. roleName .. " to a player ERROR")
				ply = plyPreferences[#plyPreferences][1]
			end
		end

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
	for _, ply in pairs(players) do
		if roleMap[ply] == NO_ROLE_ASSIGNED then
			roleMap[ply] = roles.INNOCENT.id
		end
	end

	-- we want to use the meta version not to break anything
	hook.Run("TTT2MetaModifyFinalRoles", roleMap)
end

hook.Add("TTT2ModifyFinalRoles", "meta_avoid_roles", ReallocateRoles)
