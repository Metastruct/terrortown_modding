local tag = "TTTOutfitterRagdoll"

if SERVER then
	util.AddNetworkString(tag)

	-- Tell clients there is a corpse being created
	hook.Add("TTTOnCorpseCreated", tag, function(rag, pl)
		net.Start(tag)
		net.WritePlayer(pl)
		net.WriteUInt(rag:EntIndex(), 13)
		net.Broadcast()
	end)
else
	local ragdollClassName = "prop_ragdoll"

	local function HideBaseRagdoll(rag)
		rag:SetNoDraw(true)
		rag:SetModel("models/player/kleiner.mdl")
		rag:SetLOD(4)
	end

	local function CreateOutfitterRagdoll(pl, rag)
		if not IsValid(pl) or not pl.outfitter_mdl then return end

		local mdl = ClientsideModel(pl.outfitter_mdl)

		local plColor = pl:GetPlayerColor()

		mdl:SetSkin(pl:GetSkin())
		function mdl:GetPlayerColor() return plColor end

		mdl:SetParent(rag)
		mdl:SetLocalPos(vector_origin)
		mdl:AddEffects(EF_BONEMERGE)
		mdl:AddEffects(EF_BONEMERGE_FASTCULL)

		mdl:SetNoDraw(false)
		mdl:DrawShadow(true)

		mdl.RagdollParent = rag

		HideBaseRagdoll(rag)

		function mdl:RenderOverride()
			local rag = self.RagdollParent

			if not IsValid(rag) then
				self:Remove()
				return
			end

			if not rag:IsDormant() and self:GetParent() != rag then
				self:SetParent(rag)
				self:SetLocalPos(vector_origin)

				HideBaseRagdoll(rag)
			end

			self:DrawModel()
			self:CreateShadow()
		end
	end

	-- Sometimes the client is told about corpses they aren't aware of yet - catch when they appear and apply the outfitter model
	local pendingOutfitterRagdolls = {}

	hook.Add("OnEntityCreated", tag, function(ent)
		local entId = IsValid(ent) and ent:EntIndex() or nil

		if pendingOutfitterRagdolls[entId] then
			local pl = pendingOutfitterRagdolls[entId]

			pendingOutfitterRagdolls[entId] = nil

			if IsValid(pl) and ent:GetClass() == ragdollClassName then
				CreateOutfitterRagdoll(pl, ent)
			end
		end
	end)

	-- Clear out the pending table when the round changes
	hook.Add("TTTPrepareRound", tag, function()
		pendingOutfitterRagdolls = {}
	end)

	-- A corpse has been created - if the player has an outfitter model, try applying it to their corpse
	net.Receive(tag, function()
		local pl = net.ReadPlayer()
		if not IsValid(pl) or not pl.outfitter_mdl then return end

		local ragId = net.ReadUInt(13)
		if not ragId then return end

		local rag = Entity(ragId)

		if not IsValid(rag) then
			pendingOutfitterRagdolls[ragId] = pl
			return
		end

		if rag:GetClass() != ragdollClassName then return end

		CreateOutfitterRagdoll(pl, rag)
	end)
end