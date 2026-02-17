TTTRagdolling = TTTRagdolling or {}

TTTRagdolling._hookName = "TTTTwistRagdolling"
TTTRagdolling._nwRagdoll = "TTTTwistRagdollEnt"
TTTRagdolling._dtRagdollOwnerId = 10

local utilTraceLine = util.TraceLine

function TTTRagdolling.GetRagdollOwner(rag)
	return (IsValid(rag) and rag:IsRagdoll()) and rag:GetDTEntity(TTTRagdolling._dtRagdollOwnerId) or NULL
end

function TTTRagdolling.GetPlayerRagdoll(pl)
	return pl:IsPlayer() and pl:GetNWEntity(TTTRagdolling._nwRagdoll) or NULL
end

function TTTRagdolling.IsPlayerRagdolling(pl)
	return pl:IsPlayer() and IsValid(pl:GetNWEntity(TTTRagdolling._nwRagdoll))
end

hook.Add("PlayerSwitchWeapon", TTTRagdolling._hookName, function(pl, oldWep, newWep)
	if TTTRagdolling.IsPlayerRagdolling(pl) then return true end
end)

hook.Add("StartCommand", TTTRagdolling._hookName, function(pl, cm)
	if not pl:IsTerror() or not TTTRagdolling.IsPlayerRagdolling(pl) then return end

	-- Disable weapon usage
	local buttons = bit.band(cm:GetButtons(), bit.bnot(IN_ATTACK), bit.bnot(IN_ATTACK2), bit.bnot(IN_RELOAD))

	cm:SetButtons(buttons)
end)

hook.Add("SetupMove", TTTRagdolling._hookName, function(pl, mv, cm)
	local rag = pl:IsTerror() and TTTRagdolling.GetPlayerRagdoll(pl) or NULL
	if not IsValid(rag) then return end

	-- Prevent jumping (just in case), force ducking
	local buttons = bit.bor(bit.band(mv:GetButtons(), bit.bnot(IN_JUMP)), IN_DUCK)

	mv:SetButtons(buttons)
	mv:SetVelocity(vector_origin)

	local center = rag:WorldSpaceCenter()
	if CLIENT then
		-- The client wants a position local to the prop, otherwise the clientside player position goes apeshit and makes using traitor buttons while disguised impossible
		center = rag:WorldToLocal(center)
	end

	mv:SetOrigin(center)

	if SERVER then
		local now = CurTime()
		local updateLastPos = true

		if now >= (rag._RagdollingNextCheck or 0) then
			if rag._RagdollingLastPos then
				rag._RagdollingNextCheck = now + 0.08

				local phys = rag:GetPhysicsObject()
				local velSqr = phys:GetVelocity():LengthSqr()

				if velSqr > 0 then
					local velLen = math.sqrt(velSqr)
					local score = ((center - rag._RagdollingLastPos):Length() / math.max(velLen, 100)) * 2

					-- If score is below 1, continue checking for playerclips, otherwise assume we've teleported and don't check
					if score < 1 then
						local tr = utilTraceLine({
							start = rag._RagdollingLastPos,
							endpos = center,
							mask = CONTENTS_PLAYERCLIP
						})

						if tr.Hit then
							updateLastPos = false

							rag:ForcePlayerDrop()

							-- We're being held by a magneto-stick which is unaffected by ForcePlayerDrop, find it and force it to drop
							if rag:IsPlayerHolding() then
								local carryClass = "weapon_zm_carry"

								for k, v in player.Iterator() do
									local vWep = v:GetActiveWeapon()

									if IsValid(vWep) and vWep:GetClass() == carryClass and vWep:GetCarryTarget() == p then
										vWep:Reset(true)
										break
									end
								end
							end

							phys:SetPos(rag._RagdollingLastPos + (rag:GetPos() - center))
							phys:SetVelocityInstantaneous(tr.HitNormal * math.max(velLen, 250))
						end
					end
				end
			end

			if updateLastPos then
				rag._RagdollingLastPos = center
			end
		end
	end
end)