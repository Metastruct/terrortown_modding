local ROUND = {}
ROUND.Name = "Very Quiet Hill"
ROUND.Description = "Where did all this fog come from...?"

local TAG = "ttt_chaos_veryquiethill"

function ROUND:Start()
	if CLIENT then
		local startDist, endDist = -120, 500
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
