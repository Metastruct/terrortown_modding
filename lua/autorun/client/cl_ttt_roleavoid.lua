hook.Add("PlayerInitialSpawn", "ttt2_roleavoid", function(ply)
	for _, role in pairs(roles.roleList) do
		if role.index ~= nil and role.index ~= roles.INNOCENT.index and not role.notSelectable then
			CreateClientConVar("ttt2_avoidrole_" .. role.name, "0", true, true)
		end
	end
end)
