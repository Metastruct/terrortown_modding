local ROUND = {}
ROUND.Name = "No-body"
ROUND.Description = "There are no bodies, no screams. Only the tolls of bells."

if SERVER then
	local hookName = "TTTChaosNoBodies"

	function ROUND:Start()
		hook.Add("TTT2PlayDeathScream", hookName, function() return false end)
		hook.Add("TTTCanSearchCorpse", hookName, function() return false end)

		hook.Add("TTTOnCorpseCreated", hookName, function(rag, pl)
			rag:SetNoDraw(true)
			rag:SetSolid(SOLID_NONE)

			local pos = rag:GetPos()

			local prop = ents.Create("prop_physics")

			prop:SetModel("models/Gibs/HGIBS.mdl")
			prop:SetPos(pos)
			prop:SetAngles(rag:GetAngles())

			prop:Spawn()
			prop:SetCollisionGroup(COLLISION_GROUP_WEAPON)

			local phys = prop:GetPhysicsObject()
			if IsValid(phys) then
				phys:SetVelocity(rag:GetVelocity())
			end

			SafeRemoveEntityDelayed(rag, 0)

			sound.Play(")ambient/misc/brass_bell_c.wav", pos, 70, 30, 0.7)
		end)
	end

	function ROUND:Finish()
		hook.Remove("TTT2PlayDeathScream", hookName)
		hook.Remove("TTTCanSearchCorpse", hookName)
		hook.Remove("TTTOnCorpseCreated", hookName)
	end
end

return RegisterChaosRound(ROUND)