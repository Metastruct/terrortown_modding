local ROUND = {}
ROUND.Name = "Very Quiet Hill"
ROUND.Description = "Everyone is nearly blind, but also has a radar!"

function ROUND:Start()
	if SERVER then
		-- Give everyone the radar item
		for _, ply in pairs(player.GetAll()) do
			ply:GiveEquipmentItem("item_ttt_radar")
		end
	else
		hook.Add("SetupWorldFog", "ttt_chaos_veryquiethill", function()
			render.FogMode(MATERIAL_FOG_LINEAR)
			render.FogStart(0)
			render.FogEnd(300)
			render.FogMaxDensity(1)
			render.FogColor(0, 0, 0)
			return true
		end)
		hook.Add("SetupSkyboxFog", "ttt_chaos_veryquiethill", function(sb)
			render.FogMode(MATERIAL_FOG_LINEAR)
			render.FogStart(0)
			render.FogEnd(300 * sb)
			render.FogMaxDensity(1)
			render.FogColor(0, 0, 0)
			return true
		end)
	end
end

function ROUND:Finish()
	if CLIENT then
		hook.Remove("SetupWorldFog", "ttt_chaos_veryquiethill")
	end
end

return RegisterChaosRound(ROUND)
