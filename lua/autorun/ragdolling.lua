if SERVER then
	AddCSLuaFile("ragdolling/sh_init.lua")
	AddCSLuaFile("ragdolling/cl_init.lua")
end

include("ragdolling/sh_init.lua")

if SERVER then
	include("ragdolling/sv_init.lua")
else
	include("ragdolling/cl_init.lua")
end