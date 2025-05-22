local tag = "r_flushlod_fixed"

local function runfix()
	RunConsoleCommand("r_flushlod")
	hook.Remove("RenderScene", tag)
	return true
end

concommand.Add(tag, function()
	hook.Add("RenderScene", tag, runfix)
end, nil, "Runs r_flushlod but possibly prevents crashes caused by it", FCVAR_DONTRECORD)
-- This is a workaround for the r_flushlod command, which can cause crashes in some cases.