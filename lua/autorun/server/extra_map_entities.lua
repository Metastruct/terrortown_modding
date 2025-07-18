local dataFolderPath = "ttt2_extra_mapents/"

local TAB = {}

local function RollChance(chance)
	return not isnumber(chance) and true or math.random() <= chance
end

function TAB.GetMapFilePath()
	return dataFolderPath .. game.GetMap() .. ".dat"
end

--[[ DATA FORMAT:
{
	id = NUMBER -- group ID
	chance = NUMBER -- decimal chance for this group to spawn: 0-1 (only if group ID is not 0)
	ents = {
		class = STRING -- classname of the entity to spawn
		pos = VECTOR -- position
		ang = ANGLE -- angle
		model = STRING -- model path
		skin = NUMBER -- skin id
		scale = NUMBER -- model scale
		colgroup = NUMBER -- custom collision group id
		frozen = BOOL -- should freeze prop?
		chance = NUMBER -- decimal chance for this entity to spawn: 0-1 (only if group ID is 0)
	}
} ]]

function TAB.LoadDataAsync(func)
	file.AsyncRead(TAB.GetMapFilePath(), "DATA", function(fileName, gamePath, status, data)
		if status == FSASYNC_OK then
			TAB.MapData = util.JSONToTable(data)

			MsgN("[ExtraMapEnts] Loaded map data successfully")
		else
			MsgN("[ExtraMapEnts] Failed to load map data, FSASYNC status code ", status)
		end

		if isfunction(func) then
			func(fileName, gamePath, status, data)
		end
	end)
end

function TAB.SaveData()
	local mapData = TAB.MapData

	if istable(mapData) then
		local saveTable = {}

		-- Iterate through the map data table to ensure it is clean before saving it
		for _, v in pairs(mapData) do
			if not istable(v)
				or not istable(v.ents)
				or table.Count(v.ents) == 0
			then continue end

			local newTab = {
				id = isnumber(v.id) and v.id or 0,
				chance = isnumber(v.chance) and v.chance or nil,
				ents = {}
			}

			for _, x in pairs(v.ents) do
				if not isstring(x.class) or not isvector(x.pos) then continue end

				newTab.ents[#newTab.ents + 1] = {
					class = x.class,
					pos = x.pos,
					ang = isangle(x.ang) and x.ang or nil,
					model = isstring(x.model) and x.model or nil,
					skin = isnumber(x.skin) and x.skin != 0 and x.skin or nil,
					scale = isnumber(x.scale) and x.scale != 1 and x.scale or nil,
					colgroup = isnumber(x.colgroup) and x.colgroup != 0 and x.colgroup or nil,
					frozen = x.invisible == true or x.frozen == true or nil,
					invisible = x.invisible == true or nil,
					chance = isnumber(x.chance) and x.chance or nil
				}
			end

			if #newTab.ents > 0 then
				saveTable[#saveTable + 1] = newTab
			end
		end

		local json = util.TableToJSON(saveTable)

		file.CreateDir(string.Trim(dataFolderPath, "/"))
		file.Write(TAB.GetMapFilePath(), json)

		MsgN("[ExtraMapEnts] Map data saved successfully")
		return true
	end

	MsgN("[ExtraMapEnts] Failed to save map data, no TTT2ExtraMapEnts.MapData table found")
	return false
end

function TAB.AddEntity(ent, model, frozen, invisible, groupid, chance)
	if not IsValid(ent) then return false end

	if not istable(TAB.MapData) then
		TAB.MapData = {}
	end

	local id = isnumber(groupid) and groupid or 0

	local class = ent:GetClass()
	local scale = ent:GetModelScale()
	local skinId = ent:GetSkin()
	local colGroupId = ent:GetCollisionGroup()

	local newTab = {
		class = class,
		pos = ent:GetPos(),
		ang = ent:GetAngles(),
		model = model or (string.StartsWith(class, "prop_") and ent:GetModel() or nil),
		skin = skinId != 0 and skinId or nil,
		scale = scale != 1 and scale or nil,
		colgroup = colGroupId != 0 and colGroupId or nil,
		frozen = invisible or frozen,
		invisible = invisible,
		chance = id == 0 and isnumber(chance) and chance or nil
	}

	for _, v in pairs(TAB.MapData) do
		if v.id == id then
			if istable(v.ents) then
				v.ents[#v.ents + 1] = newTab
			else
				v.ents = { newTab }
			end

			return true
		end
	end

	TAB.MapData[#TAB.MapData + 1] = {
		id = id,
		chance = id != 0 and isnumber(chance) and chance or nil,
		ents = { newTab }
	}

	return true
end

function TAB.SpawnEntities(forceSpawnForDebug)
	local mapData = TAB.MapData
	if not istable(mapData) then return end

	for _, v in pairs(mapData) do
		if not istable(v)
			or not istable(v.ents)
			or table.Count(v.ents) == 0
		then continue end

		local isGroupZero = v.id == 0

		if forceSpawnForDebug or (isGroupZero or RollChance(v.chance)) then
			for _, x in pairs(v.ents) do
				if not isstring(x.class)
					or not isvector(x.pos)
					or (not forceSpawnForDebug and isGroupZero and not RollChance(x.chance))
				then continue end

				local ent = ents.Create(x.class)

				ent:SetPos(x.pos)

				if isangle(x.ang) then ent:SetAngles(x.ang) end
				if isstring(x.model) then ent:SetModel(x.model) end
				if isnumber(x.skin) then ent:SetSkin(x.skin) end

				ent:Spawn()

				if isnumber(x.scale) then
					ent:SetModelScale(x.scale, 0.00001)

					timer.Simple(0.03, function()
						if IsValid(ent) then
							ent:Activate()
						end
					end)
				end

				if isnumber(x.colgroup) then ent:SetCollisionGroup(x.colgroup) end

				if x.frozen then
					local phys = ent:GetPhysicsObject()
					if IsValid(phys) then
						phys:EnableMotion(false)
					end

					ent:SetMoveType(MOVETYPE_NONE)
				end

				-- If force spawning for debug, reveal invisible entities
				if x.invisible then
					if forceSpawnForDebug then
						ent:SetMaterial("vgui/progressbar")
					else
						ent:SetNoDraw(true)
					end
				end
			end
		end
	end
end

hook.Add("TTTPrepareRound", "TTT2ExtraMapEnts", function()
	TAB.SpawnEntities()
end)

TAB.LoadDataAsync()

TTT2ExtraMapEnts = TAB