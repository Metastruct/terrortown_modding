RunConsoleCommand("sv_allowcslua", "0")

timer.Simple(1, function()
	RunConsoleCommand("sv_allowcslua", "0")
end)

timer.Simple(123, function()
	RunConsoleCommand("sv_allowcslua", "0")
end)