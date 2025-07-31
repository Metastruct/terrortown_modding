-- Headsplat gore by Twist

local tag = "TTTHeadsplatGore"

if SERVER then
	local cvarEnabled = CreateConVar("ttt_headsplat_enable", 1, FCVAR_ARCHIVE + FCVAR_NOTIFY, "Enables head splatting and gibbing on headshots.")
	local cvarDamageThreshold = CreateConVar("ttt_headsplat_dmgthreshold", 50, FCVAR_ARCHIVE + FCVAR_NOTIFY, "The final headshot must do at least this much damage to splat someone's head.")

	local function scaleDownBoneAndChildren(ent, boneId)
		local children = ent:GetChildBones(boneId)

		for i = 1, #children do
			local childId = children[i]

			ent:ManipulateBoneScale(childId, vector_origin)

			scaleDownBoneAndChildren(ent, childId)
		end
	end

	hook.Add("DoPlayerDeath", tag, function(pl, attacker, dmgInfo)
		if cvarEnabled:GetBool() and pl.was_headshot and dmgInfo:GetDamage() >= cvarDamageThreshold:GetInt() then
			local inflictor = dmgInfo:GetInflictor()
			if inflictor == attacker then
				inflictor = attacker:GetActiveWeapon()
			end

			if IsValid(inflictor) then
				pl._shouldHeadExplode = not inflictor.IsSilent
			end
		end
	end)

	hook.Add("TTTOnCorpseCreated", tag, function(rag, pl)
		if IsValid(rag) and IsValid(pl) and pl._shouldHeadExplode then
			pl._shouldHeadExplode = nil

			local boneId = rag:LookupBone("ValveBiped.Bip01_Head1")
			if not boneId then return end

			rag:ManipulateBoneScale(boneId, vector_origin)
			scaleDownBoneAndChildren(rag, boneId)

			rag:SetNWBool("ttt_headsplatted", true)

			rag:EmitSound("npc/antlion_grub/squashed.wav", 66, math.random(90, 110))
			rag:EmitSound("physics/flesh/flesh_bloody_break.wav", 66, 100, 0.8)

			local boneMat = rag:GetBoneMatrix(boneId)
			if boneMat then
				local ef = EffectData()

				ef:SetOrigin(boneMat:GetTranslation())

				-- Use a custom made effect, can be found in the lua/effects/ folder
				util.Effect("ttt_headshot_gore", ef, true)
			end
		end
	end)
else
	-- Bodysearch stuff coming soon...
end