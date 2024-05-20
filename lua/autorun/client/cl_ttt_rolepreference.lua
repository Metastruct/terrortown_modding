hook.Add("TTTPrepareRound", "ttt2_rolepreference", function(ply)
	for _, role in pairs(roles.roleList) do
		if role.index ~= nil and role.index ~= roles.INNOCENT.index and not role.notSelectable then
			CreateClientConVar("ttt2_rolepreference_" .. role.name, "1", true, true)
		end
	end
end)
