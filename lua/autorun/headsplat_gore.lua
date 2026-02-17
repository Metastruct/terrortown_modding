-- Headsplat gore by Twist

local tag = "TTTHeadsplatGore"

if SERVER then
	resource.AddFile("materials/vgui/ttt/icon_headless.vmt")

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

	local function shouldHeadExplode(pl, attacker, dmgInfo)
		if not pl._ignoreHeadExplode
			and cvarEnabled:GetBool()
			and pl.was_headshot
			and dmgInfo:GetDamage() >= cvarDamageThreshold:GetInt()
		then
			local inflictor = dmgInfo:GetInflictor()

			if inflictor == attacker and attacker.GetActiveWeapon then
				inflictor = attacker:GetActiveWeapon()
			end

			return IsValid(inflictor) and not inflictor.IsSilent
		end

		return false
	end

	local function explodeHead(rag, pl)
		if IsValid(rag) and IsValid(pl) then
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

				util.Effect("ttt_headshot_gore", ef, true)
			end
		end
	end

	hook.Add("DoPlayerDeath", tag, function(pl, attacker, dmgInfo)
		local explode = shouldHeadExplode(pl, attacker, dmgInfo)

		if explode then
			pl._shouldHeadExplode = explode
		end
	end)

	hook.Add("TTTOnCorpseCreated", tag, function(rag, pl)
		if pl._shouldHeadExplode then
			explodeHead(rag, pl)
		end
	end)

	TTTHeadSplats = TTTHeadSplats or {}
	TTTHeadSplats.ShouldHeadExplode = shouldHeadExplode
	TTTHeadSplats.ExplodeHead = explodeHead
else
	hook.Add("TTTBodySearchPopulate", tag, function(searchAdd, raw, scoreboard)
		local rag = raw.rag
		if not IsValid(rag) or not rag:GetNWBool("ttt_headsplatted") then return end

		searchAdd.headsplat_info = {
			p = 2,
			order = 3,
			img = "vgui/ttt/icon_headless",
			title = "Missing head",
			text = "Damnnnn, this dude's head was blown smoove off!"
		}
	end)
end