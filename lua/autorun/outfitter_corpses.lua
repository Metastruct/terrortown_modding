local tag = "TTTOutfitterRagdoll"

if SERVER then
	util.AddNetworkString(tag)

	local function IsModelCharple(mdl)
		return (mdl:find("charple")) != nil
	end

	-- Tell clients there is a corpse being created
	hook.Add("TTTOnCorpseCreated", tag, function(rag, pl)
		if not IsValid(rag) or IsModelCharple(rag:GetModel()) then return end

		net.Start(tag)
		net.WritePlayer(pl)
		net.WriteUInt(rag:EntIndex(), 13)
		net.Broadcast()
	end)
else
	local outfitterRagdollList = {}

	local function NormaliseBaseRagdoll(rag)
		rag:SetLOD(4)
		rag:SetModel("models/player/kleiner.mdl")
	end

	local function ForceNormaliseBaseRagdoll(rag)
		NormaliseBaseRagdoll(rag)

		local timerId = tag .. tostring(rag:EntIndex())

		-- Sorry, there doesn't seem to be a proper way of detecting if the base ragdoll has successfully been hidden
		-- And it may be ping dependent, so we can only spam it... very epic!
		timer.Create(timerId, 0.03, 10, function()
			if not IsValid(rag) then
				timer.Remove(timerId)
				return
			end

			NormaliseBaseRagdoll(rag)
		end)
	end

	local function CreateOutfitterRagdoll(pl, rag)
		if not IsValid(pl) or not pl.outfitter_mdl then return end

		local mdl = ClientsideModel(pl.outfitter_mdl)

		local plColor = pl:GetPlayerColor()

		mdl:SetSkin(pl:GetSkin())
		function mdl:GetPlayerColor() return plColor end

		local bodygroups = pl:GetBodyGroups()
		for i = 1, #bodygroups do
			local group = bodygroups[i]
			mdl:SetBodygroup(group.id, pl:GetBodygroup(group.id))
		end

		mdl:SetParent(rag)
		mdl:SetLocalPos(vector_origin)
		mdl:AddEffects(EF_BONEMERGE)
		mdl:AddEffects(EF_BONEMERGE_FASTCULL)

		mdl:SetNoDraw(false)

		mdl.outfitterRagdollParent = rag
		rag.outfitterChildMdl = mdl

		outfitterRagdollList[#outfitterRagdollList + 1] = mdl

		ForceNormaliseBaseRagdoll(rag)

		function mdl:RenderOverride()
			local rag = self.outfitterRagdollParent

			if not IsValid(rag) then
				self:Remove()
				return
			end

			if self:GetParent() == rag then
				self:DrawModel()
				self:CreateShadow()
			end
		end

		function rag:RenderOverride()
			if not IsValid(self.outfitterChildMdl) then
				self:DrawModel()
				self:CreateShadow()
			end
		end

		rag:CallOnRemove(tag, function(ent)
			if IsValid(ent.outfitterChildMdl) then
				ent.outfitterChildMdl:Remove()
			end
		end)
	end

	-- Sometimes the client is told about corpses they aren't aware of yet - catch when they appear and apply the outfitter model
	local pendingOutfitterRagdolls = {}

	hook.Add("NetworkEntityCreated", tag, function(ent)
		local entId = IsValid(ent) and ent:EntIndex() or nil

		if pendingOutfitterRagdolls[entId] then
			local pl = pendingOutfitterRagdolls[entId]

			pendingOutfitterRagdolls[entId] = nil

			if IsValid(pl) and ent:IsRagdoll() then
				CreateOutfitterRagdoll(pl, ent)
			end
		end
	end)

	hook.Add("NotifyShouldTransmit", tag, function(ent, transmit)
		if not transmit then return end

		if IsValid(ent) and ent:IsRagdoll() and IsValid(ent.outfitterChildMdl) then
			ent.outfitterChildMdl:SetParent(ent)
			ent.outfitterChildMdl:SetLocalPos(vector_origin)

			ForceNormaliseBaseRagdoll(ent)
		end
	end)

	-- Clear out the pending table when the round changes
	hook.Add("TTTPrepareRound", tag, function()
		pendingOutfitterRagdolls = {}

		for k, v in pairs(outfitterRagdollList) do
			if IsValid(v) then
				v:Remove()
			end
		end

		outfitterRagdollList = {}
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

		if not rag:IsRagdoll() then return end

		CreateOutfitterRagdoll(pl, rag)
	end)
end