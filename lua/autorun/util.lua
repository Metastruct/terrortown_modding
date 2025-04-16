-- Extra util functions to use for various custom TTT things, like weapons

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