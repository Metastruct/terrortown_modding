local function getPlayerRolePreference(pl, roleName)
	-- Bots always return 0 for GetInfoNum, no matter what the default value is
	if pl:IsBot() then return 1 end

	return math.Clamp(pl:GetInfoNum("ttt2_rolepreference_" .. roleName, 1), 0, 1)
end

local function ReallocateRoles(roleMap)
	local innocentId = ROLE_INNOCENT

	local innocentInfo = {}
	local rolesToPassOn = {}

	for pl, roleId in pairs(roleMap) do
		if roleId == innocentId then
			innocentInfo[#innocentInfo + 1] = {
				pl = pl,
				weights = pl:GetRoleWeightTable()
			}

			continue
		end

		local role = roles.GetByIndex(roleId)

		local pref = getPlayerRolePreference(pl, role.name)
		if pref >= 1 then continue end

		local shouldSwapRole = pref <= 0 or math.random() <= pref
		if not shouldSwapRole then continue end

		-- Make them an innocent, add them to the innocents pool, and add the role to the list to pass on
		roleMap[pl] = innocentId

		innocentInfo[#innocentInfo + 1] = {
			pl = pl,
			weights = pl:GetRoleWeightTable()
		}

		rolesToPassOn[#rolesToPassOn + 1] = {
			id = role.index,
			name = role.name,
			originalOwner = pl
		}
	end

	if #rolesToPassOn > 0 then
		local minWeight = roleselection.cv.ttt_role_derandomize_min_weight:GetInt()

		local rolesToForce = {}

		for i = 1, #rolesToPassOn do
			local roleInfo = rolesToPassOn[i]

			local totalWeight = 0
			local availables = {}

			for x = 1, #innocentInfo do
				local innoInfo = innocentInfo[x]

				-- Don't attempt to give the role back to who originally had it
				if roleInfo.originalOwner == innoInfo.pl then continue end

				local pref = getPlayerRolePreference(innoInfo.pl, roleInfo.name)
				if pref > 0 then
					local weight = (innoInfo.weights[roleInfo.index] or minWeight) * pref

					totalWeight = totalWeight + weight
					availables[#availables + 1] = {
						pl = innoInfo.pl,
						weight = weight
					}
				end
			end

			if #availables > 0 then
				table.sort(availables, function(a, b) return a.weight > b.weight end)

				local chosenValue = math.random() * totalWeight
				local progressWeight = 0

				for x = 1, #availables do
					local avInfo = availables[x]

					progressWeight = progressWeight + avInfo.weight

					if progressWeight > chosenValue then
						-- Pass the role onto this player using weighted chance (based on weight * preference scale)
						roleMap[avInfo.pl] = roleInfo.id

						-- Take this player out the innocents pool
						for y = 1, #innocentInfo do
							if innocentInfo[y].pl == avInfo.pl then
								table.remove(innocentInfo, y)
								break
							end
						end

						print(string.format("[RolePreference] Passed '%s' role to another player", roleInfo.name))

						break
					end
				end
			else
				rolesToForce[#rolesToForce + 1] = roleInfo
			end
		end

		for i = 1, #rolesToForce do
			local roleInfo = rolesToForce[i]

			local chosenId = math.random(#innocentInfo)
			local pl = innocentInfo[chosenId].pl

			-- Force the orphan role on this player, let them know it was forced, and take them out the innocents pool
			roleMap[pl] = roleInfo.id

			table.remove(innocentInfo, chosenId)

			pl:ChatPrint("Due to no-one wanting to take this role, you've been randomly chosen to take it. Sorry!")
			print(string.format("[RolePreference] FORCED '%s' role to another player", roleInfo.name))
		end
	end

	-- We want to use the meta version not to break anything
	hook.Run("TTT2MetaModifyFinalRoles", roleMap)
end

hook.Add("TTT2ModifyFinalRoles", "meta_avoid_roles", ReallocateRoles)