-- Extra util functions to use for various custom TTT things, like weapons

local utilTraceHull = util.TraceHull

-- Ported from TF2's Spy Knife source code:
-- https://github.com/ValveSoftware/source-sdk-2013/blob/0565403b153dfcde602f6f58d8f4d13483696a13/src/game/shared/tf/tf_weapon_knife.cpp#L447
function util.IsBehindAndFacingTarget(pl, target)
	local normalToTarget = target:WorldSpaceCenter() - pl:WorldSpaceCenter()
	normalToTarget.z = 0
	normalToTarget:Normalize()

	local targetForward = target:EyeAngles():Forward()
	targetForward.z = 0
	targetForward:Normalize()

	local plForward = pl:EyeAngles():Forward()
	plForward.z = 0
	plForward:Normalize()

	-- Player is behind, facing, and aiming at target's back
	return normalToTarget:Dot(targetForward) > 0 and normalToTarget:Dot(plForward) > 0.5 and targetForward:Dot(plForward) > -0.3
end

if SERVER then
	-- Stuck detection and position restore functions for Prop Disguiser and Ragdolling
	local testMaxsSize = 0.3
	local trTab = {
		start = nil,
		endpos = nil,
		mins = nil,
		maxs = nil,
		mask = MASK_PLAYERSOLID,
		filter = nil
	}

	local utilTraceLine = util.TraceLine

	function util.IsHullStuck(pos, hullMins, hullMaxs, pl)
		trTab.start = pos
		trTab.endpos = pos
		trTab.mins = hullMins
		trTab.maxs = hullMaxs
		trTab.filter = pl

		local tr = utilTraceHull(trTab)

		return tr.StartSolid
	end

	local isHullStuck = util.IsHullStuck

	function util.FindBestRestorePos(pl, pos, standingViewOffset)
		-- Before doing any of our epic checking, check if we're stuck in a playerclip first - just "respawn" us if we are
		local pointContents = util.PointContents(pos)
		if bit.band(pointContents, CONTENTS_PLAYERCLIP) != 0 then
			local spawnPoint = plyspawn.GetRandomSafePlayerSpawnPoint(pl)

			if spawnPoint then
				print("util.FindBestRestorePos:", pl, "position started inside a playerclip! Moved them to a spawnpoint for safety!")
				return spawnPoint.pos
			end

			print("util.FindBestRestorePos:", pl, "position started inside a playerclip and a suitable spawnpoint wasn't found somehow! They might be fucked!")
		end

		local newPos = pos * 1

		local hullMins, hullMaxs = pl:GetHullDuck()

		local checkHullMins, checkHullMaxs = hullMins * 1, hullMaxs * 1

		checkHullMins.z = 0
		checkHullMaxs.z = testMaxsSize

		trTab.start = pos
		trTab.endpos = pos - (vector_up * ((standingViewOffset or 64) + 1))
		trTab.mins = checkHullMins
		trTab.maxs = checkHullMaxs
		trTab.filter = pl

		local tr = utilTraceHull(trTab)

		if tr.Hit then
			newPos = tr.HitPos + vector_up
		end

		if tr.StartSolid then
			-- Check we aren't still stuck after that

			checkHullMins.z = hullMins.z
			checkHullMaxs.z = hullMaxs.z

			if isHullStuck(newPos, hullMins, hullMaxs, pl) then
				-- We are stuck... try pushing our position away from any nearby walls in each direction

				-- Reuse this vector object
				local testVec = Vector()

				local testDirs = {
					{hullMins.x, 0},
					{hullMaxs.x, 0},
					{0, hullMins.y},
					{0, hullMaxs.y}
				}

				for i = 1, #testDirs do
					local dir = testDirs[i]

					testVec.x = dir[1]
					testVec.y = dir[2]

					if testVec.x > 0 then
						checkHullMins.x = -testMaxsSize
						checkHullMaxs.x = 0
					elseif testVec.x < 0 then
						checkHullMins.x = 0
						checkHullMaxs.x = testMaxsSize
					else
						checkHullMins.x = hullMins.x
						checkHullMaxs.x = hullMaxs.x
					end

					if testVec.y > 0 then
						checkHullMins.y = -testMaxsSize
						checkHullMaxs.y = 0
					elseif testVec.y < 0 then
						checkHullMins.y = 0
						checkHullMaxs.y = testMaxsSize
					else
						checkHullMins.y = hullMins.y
						checkHullMaxs.y = hullMaxs.y
					end

					trTab.start = newPos
					trTab.endpos = newPos + testVec
					trTab.mins = checkHullMins
					trTab.maxs = checkHullMaxs
					trTab.filter = pl

					tr = utilTraceHull(trTab)

					if tr.Hit and not tr.AllSolid then
						local correction
						if tr.HitNormal != vector_origin then
							correction = tr.HitNormal * ((hullMaxs.x * (1 - tr.Fraction)) + 0.5)
						else
							correction = testVec
						end

						newPos = newPos + correction
					end

					if not isHullStuck(newPos, hullMins, hullMaxs, pl) then return newPos end
				end

				-- Pushing against walls hasn't worked, try finding two good directions and creep towards them
				local maxTestRange = 64
				local desiredDirs = {}

				testDirs = {
					{1, 0},
					{-1, 0},
					{0, 1},
					{0, -1}
				}

				for i = 1, #testDirs do
					local dir = testDirs[i]

					testVec.x = dir[1] * maxTestRange
					testVec.y = dir[2] * maxTestRange

					trTab.start = newPos
					trTab.endpos = newPos + testVec

					tr = utilTraceLine(trTab)

					local len = maxTestRange * tr.Fraction
					len = len > hullMaxs.x and len or 0

					if len > 0 then
						desiredDirs[#desiredDirs + 1] = {Dir = dir, Len = len}
					end
				end

				if #desiredDirs > 0 then
					table.sort(desiredDirs, function(a, b) return a.Len > b.Len end)

					local dir1, dir2 = desiredDirs[1], desiredDirs[2]
					dir1, dir2 = dir1 and dir1.Dir, dir2 and dir2.Dir

					local dir1X, dir1Y, dir2X, dir2Y

					-- Lift the traces off the ground a bit, restore it after
					testVec.z = newPos.z + 8

					for i = 1, maxTestRange do
						dir1X, dir1Y = dir1[1] * i, dir1[2] * i

						testVec.x = newPos.x + dir1X
						testVec.y = newPos.y + dir1Y

						if not isHullStuck(testVec, hullMins, hullMaxs, pl) then
							testVec.z = newPos.z
							return testVec
						end

						if dir2 then
							dir2X, dir2Y = dir2[1] * i, dir2[2] * i

							testVec.x = newPos.x + dir2X
							testVec.y = newPos.y + dir2Y

							if not isHullStuck(testVec, hullMins, hullMaxs, pl) then
								testVec.z = newPos.z
								return testVec
							end

							if (dir1X - dir2X) != 0 and (dir1Y - dir2Y) != 0 then
								testVec.x = newPos.x + dir1X + dir2X
								testVec.y = newPos.y + dir1Y + dir2Y

								if not isHullStuck(testVec, hullMins, hullMaxs, pl) then
									testVec.z = newPos.z
									return testVec
								end
							end
						end
					end
				else
					-- We have no good directions, try lifting us upwards instead...

					testVec.x = newPos.x
					testVec.y = newPos.y

					for i = 1, maxTestRange do
						testVec.z = newPos.z + i

						if not isHullStuck(testVec, hullMins, hullMaxs, pl) then return testVec end
					end
				end
			end
		end

		return newPos
	end
end