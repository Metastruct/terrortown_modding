hook.Add("PreDrawViewModel", TTTRagdolling._hookName, function(vm, pl)
	if pl == LocalPlayer() and TTTRagdolling.IsPlayerRagdolling(pl) then return true end
end)

local eyesAttachment = "eyes"
local headBone = "ValveBiped.Bip01_Head1"

hook.Add("CalcView", TTTRagdolling._hookName, function(pl, pos, ang, fov)
	local rag = TTTRagdolling.GetPlayerRagdoll(pl)
	if not IsValid(rag) then return end

	local eyesId = rag:LookupAttachment(eyesAttachment)
	if eyesId > 0 then
		local eyes = rag:GetAttachment(eyesId)

		pos = eyes.Pos
		ang = eyes.Ang
	else
		local boneId = rag:LookupBone(headBone)

		if boneId then
			local matrix = rag:GetBoneMatrix(boneId)

			pos = matrix:GetTranslation()
			ang = matrix:GetAngles()
		end
	end

	return {
		origin = pos,
		angles = ang,
		fov = fov
	}
end)

hook.Add("TTTRenderEntityInfo", TTTRagdolling._hookName, function(tData)
	local pl = LocalPlayer()
	if not IsValid(pl) then return end

	local ent = tData:GetEntity()

	local owner = TTTRagdolling.GetRagdollOwner(ent)
	if not IsValid(owner) then return end

	-- Disable outline and clear icons that might appear
	tData.params.drawOutline = nil
	tData.params.displayInfo.key = nil
	tData.params.displayInfo.icon = {}

	-- If targeting own ragdoll, don't render targetid
	if pl == owner then
		tData.params.drawInfo = nil
		return
	end

	-- Set entity to the ragdoll owner so we can render the usual player info on the ragdoll
	tData.data.ent = owner

	targetid.HUDDrawTargetIDPlayers(tData)

	-- Set entity back to the ragdoll just in case (fixes the outline if we render it)
	tData.data.ent = ent
end)