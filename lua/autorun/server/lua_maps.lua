local whitelisted = {
	["ttt_clue_se"] = true,
}

local HAS_WARNED = false
local map = game.GetMap()
hook.Add("CanLuaRunEntity", "TTTMaps", function(ent)
	if whitelisted[map] then
		if not HAS_WARNED then
			Msg("[Warning] ") print("Allowed lua execution for: lua_run[" .. ent:EntIndex() .. "] on " .. map)
			HAS_WARNED = true
		end

		return true
	end
end)