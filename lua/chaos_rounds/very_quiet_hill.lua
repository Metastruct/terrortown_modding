local ROUND = {}
ROUND.Name = "Very Quiet Hill"
ROUND.Description = "Everyone is nearly blind in this fog - you'll need a radar!"

local TAG = "ttt_chaos_veryquiethill"

function ROUND:Start()
	if SERVER then
		-- Give everyone the radar item using this hook
		for _, ply in ipairs(player.GetAll()) do
			ply:GiveEquipmentItem("item_ttt_radar")
		end
	else
		local startDist, endDist = -65, 650
		local fogShade, fogDensity = 160, 0.995

		hook.Add("SetupWorldFog", TAG, function()
			render.FogMode(MATERIAL_FOG_LINEAR)
			render.FogStart(startDist)
			render.FogEnd(endDist)
			render.FogMaxDensity(fogDensity)
			render.FogColor(fogShade, fogShade, fogShade)
			return true
		end)

		hook.Add("SetupSkyboxFog", TAG, function(sb)
			render.FogMode(MATERIAL_FOG_LINEAR)
			render.FogStart(startDist * sb)
			render.FogEnd(endDist * sb)
			render.FogMaxDensity(fogDensity)
			render.FogColor(fogShade, fogShade, fogShade)
			return true
		end)

		hook.Add("PostDraw2DSkyBox", TAG, function()
			render.OverrideDepthEnable(true, false)

			cam.Start2D()
				surface.SetDrawColor(fogShade, fogShade, fogShade)
				surface.DrawRect(0, 0, ScrW(), ScrH())
			cam.End2D()

			render.OverrideDepthEnable(false, false)
		end)
	end
end

function ROUND:Finish()
	if CLIENT then
		hook.Remove("SetupWorldFog", TAG)
		hook.Remove("SetupSkyboxFog", TAG)
		hook.Remove("PostDraw2DSkyBox", TAG)
	end
end

return RegisterChaosRound(ROUND)
