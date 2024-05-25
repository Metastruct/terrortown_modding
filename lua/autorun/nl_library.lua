-- The tazer is no longer a dependancy :^) --
AllowedWake = { -- these conditions can be removed when a friend presses +use
	["ZZZ"] = true,
	["---"] = true,
	["PLV"] = false
}

NLL = {}

if SERVER then

util.AddNetworkString("nllinfopayload") -- establish payload netstring

hook.Add("PlayerSay", "TG_NLL", function(ply, str)
	if ply.nllismuted then return "" end
end)

hook.Add("PlayerCanSeePlayersChat", "TG_NLL", function(text, teamOnly, listener, talker)
	if talker.nllismuted then
		return false
	end
end)

hook.Add("PlayerCanHearPlayersVoice", "TG_NLL", function(listener, talker)
	if talker.nllismuted then
		return false,false
	end
end)

NLL.ConditionStorage = {} -- Magical table that stores all players with conditions. Better than ply.condition

function NLL.GetCondtion(ply) -- Function that returns the player's table value or "NIL" as string.
	return NLL.ConditionStorage[ply] or "NIL"
end
function NLL.SetCondition(ply,string) -- Function that sets the player's table value or "NIL" as string.
	NLL.ConditionStorage[ply] = string or "NIL"
	return
end
function NLL.WipeCondition(ply) -- Function that removes a specified key and it's value
	NLL.ConditionStorage[ply] = nil
	return
end

-- Handles a few unique stun types.
hook.Add("Think", "TG_NLL", function()
	for k,v in pairs(NLL.ConditionStorage) do -- We don't need to getall anymore we have a table for that.
		if IsValid(k.nllragdoll) then
			if not k:Alive() or k:GetParent() != k.nllragdoll then return NLL.UnRagdoll( k ) end
			
			local rag = k.nllragdoll
			local phys = rag:GetPhysicsObjectNum(0) -- pelvis(?)
			
			if v == "PLV" then -- Annihilate bone structure.
				for c=0, rag:GetPhysicsObjectCount() - 1 do
					phys = k.nllragdoll:GetPhysicsObjectNum(c)
					if not phys:IsValid() then continue end
					phys:ApplyForceCenter( Vector( math.random(-800,800),math.random(-800,800),math.random(-800,800) ) )
				end
				continue
			end
			if phys:IsValid() and v == "STN" then -- This player is painfully stunned, not asleep, shake them a LITTLE bit.
				phys:AddAngleVelocity(Vector(0,math.sin(CurTime() * 2) * 100,0))
				continue
			end
			if phys:IsValid() and v == "TZE" then -- This player is being rapidly shocked! Shake them violently.
				phys:AddAngleVelocity(Vector(0,math.sin(CurTime() * 40) * 250,0))
				continue
			end
			return
		end
		NLL.WipeCondition(ply) -- You don't have a ragdoll... get the fuck out of my table.
	end
end)

--Stores the players weaponclasses and ammo in a table.
function NLL.PlyStoreWeapons(ply)
	ply.storeweps = {}
	for k,v in pairs(ply:GetWeapons()) do
		table.insert(ply.storeweps, {cl = v:GetClass(), c1 = v:Clip1(), c2 = v:Clip2()})
	end
end

--Retrieves the stored weapons
function NLL.PlyRetrieveWeapons(ply)
	for k,v in pairs(ply.storeweps or {}) do
		ply:Give(v.cl)
		local wep = ply:GetWeapon(v.cl)
		if IsValid(wep) then
			wep:SetClip1(v.c1)
			wep:SetClip2(v.c2)
		end
	end
	ply.storeweps = {}
end

--[[
Makes a hull trace the size of a player.
]]--
local data = {}
function NLL.PlayerHullTrace(pos, ply, filter)
	data.start = pos
	data.endpos = pos
	data.filter = filter
	
	return util.TraceEntity( data, ply )
end

--[[
Attemps to place the player at this position or as close as possible.
]]--
-- Directions to check
local directions = {
	Vector(0,0,0), Vector(0,0,1), --Center and up
	Vector(1,0,0), Vector(-1,0,0), Vector(0,1,0), Vector(0,-1,0) --All cardinals
}

for deg=45,315,90 do -- Diagonals
	local r = math.rad(deg)
	table.insert(directions, Vector(math.Round(math.cos(r)), math.Round(math.sin(r)), 0))
end

local magn = 15 -- How much increment for each iteration
local iterations = 2 -- How many iterations
function NLL.PlayerSetPosNoBlock( ply, pos, filter )
	local tr
	
	local dirvec
	local m = magn
	local i = 1
	local its = 1
	repeat
		dirvec = directions[i] * m
		i = i + 1
		if i > #directions then
			its = its + 1
			i = 1
			m = m + magn
			if its > iterations then
				ply:SetPos(pos) -- We've done as many checks as we wanted, lets just force him to get stuck then.
				return false
			end
		end
		
		tr = NLL.PlayerHullTrace(dirvec + pos, ply, filter)
	until tr.Hit == false
	
	ply:SetPos(pos + dirvec)
	return true
end


--[[
Sets the player invisible/visible
]]--
function NLL.PlayerInvis( ply, bool )
	ply:SetNoDraw(bool)
	ply:DrawShadow(not bool)

	if pac and pac.TogglePartDrawing then
		pac.TogglePartDrawing(ply, not bool)
	end
end


--[[
Deploy player ragdoll, Sleeping Variants can be woken up with E.
]]--
function NLL.Ragdoll( ply, pushdir, stuntype)
	if not ply:Alive() or IsValid(ply.nllragdoll) then return end -- you already have a body
	local plyphys = ply:GetPhysicsObject()
	local plyvel = Vector(0,0,0)
	if plyphys:IsValid() then
		plyvel = plyphys:GetVelocity()
	end
	
	ply.nlldroppos = ply:GetPos() -- Store pos incase the ragdoll is missing when we're to unrag him.
	
	local rag = ents.Create("prop_ragdoll")
		rag:SetModel(ply:GetModel())
		rag:SetPos(ply:GetPos())
		rag:SetAngles(Angle(0,ply:GetAngles().y,0))
		rag:SetColor(ply:GetColor())
		rag:SetMaterial(ply:GetMaterial())
		rag:Spawn()
		rag:Activate()
	
	if not IsValid(rag:GetPhysicsObject()) then
		MsgN("A slept player didn't get a valid ragdoll. Model ("..ply:GetModel()..")!")
		SafeRemoveEntity(rag)
		return false
	end
	
	--Lower inertia makes the ragdoll have trouble rolling. Citizens have 1,1,1 as default, while combines have 0.2,0.2,0.2.
	rag:GetPhysicsObject():SetInertia(Vector(1,1,1)) 
	
	--Push him back abit
	plyvel = plyvel + pushdir*200
	rag:GetPhysicsObject():SetVelocity(plyvel)
		
	--Stop firing of weapons
	NLL.PlyStoreWeapons(ply)
	ply:StripWeapons()
	
	--Makes him not collide with anything, including traces.
	ply:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
	
	--Make him follow the ragdoll, if the player gets away from the ragdoll he won't get stuff rendered properly.
	ply:SetParent(rag)
	
	--Make the player invisible.
	NLL.PlayerInvis(ply, true)

	ply.nllragdoll = rag
	rag.nllplayer = ply
	ply.condition = stuntype
		
	ply:SetNWEntity("nllviewrag", rag)
	rag:SetNWEntity("nllplyowner", ply)
	
	net.Start("nllinfopayload")
		net.WriteString("healthcond")
		net.WriteTable({["subject"] = ply,["health"] = ply:Health(),["condition"] = stuntype})
	net.Broadcast()

	NLL.SetCondition(ply,stuntype)
	
	return true
end

function NLL.UnRagdoll( ply )
	ply.nllismuted = false -- to prevent perma mute, sometimes we unragdoll the player for emergency reasons
	local ragvalid = IsValid(ply.nllragdoll)
	local pos
	if ragvalid then -- Sometimes the ragdoll is missing when we want to unrag, not good!
		if ply.nllragdoll.hasremoved then return end -- It has already been removed.
		
		pos = ply.nllragdoll:GetPos()
		ply:SetModel(ply.nllragdoll:GetModel())
		ply.nllragdoll.hasremoved = true
	else
		pos = ply.nlldroppos -- Put him at the place he got sleepd, works great.
	end
	ply:SetParent()
	
	NLL.PlayerSetPosNoBlock(ply, pos, {ply, ply.nllragdoll})
	
	ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
	
	timer.Simple(0,function()
		if not IsValid(ply) then return end
		SafeRemoveEntity(ply.nllragdoll)
		NLL.PlayerInvis(ply, false)
	end)
	
	timer.Simple(.1, function()
		if not IsValid(ply) then return end
		NLL.PlyRetrieveWeapons(ply)
	end)
	
	NLL.WipeCondition(ply)
end


hook.Add("EntityTakeDamage", "NLLDamageHandler", function(ent, dmginfo)
	if ent:IsPlayer() and IsValid(ent.nllragdoll) and not ent.ragdolldamage then -- If we're hitting the player somehow we won't let, the ragdoll should take the damage.
		dmginfo:SetDamage(0)
		return
	end
	
	if IsValid(ent.nllplayer) and (dmginfo:GetAttacker() ~= game.GetWorld()) then -- Worldspawn appears to be very eager to damage ragdolls. Don't!		
		local ply = ent.nllplayer
		ply.ragdolldamage = true
		net.Start("nllinfopayload")
			net.WriteString("health")
			net.WriteTable({["subject"] = ply,["health"] = ply:Health()}) -- sinces this runs BEFORE damage....
		net.Broadcast()
		print(ply:Health())
		if ply:Health() <= 0 then
			NLL.PlyRetrieveWeapons(ply) -- rest in peace soldier, but lets make sure you drop your stuff.
		end
		ply:TakeDamageInfo(dmginfo)
		ply.ragdolldamage = false
	end
end)

ROLE_ALLCALL = -66 -- Blacklisting this role means that they cannot kill any role.
IllegalCovertKill = { -- [Killer] = {[Victim] = Message} When Killer kills Victim, block and show Message in chat.
	[ROLE_TRAITOR] = {[ROLE_TRAITOR] = "Nope, you can't kill a traitor."},
	[ROLE_INNOCENT] = {[ROLE_DETECTIVE] = "Nope, you can't kill a detective."}, --,[ROLE_DEFECTIVE] = "Nope, you can't kill a detective."},
	[ROLE_DETECTIVE] = {[ROLE_DETECTIVE] = "Nope, you can't kill a detective."} --,[ROLE_DEFECTIVE] = "Nope, you can't kill a detective."},
	--[ROLE_JESTER] = {[ROLE_ALLCALL] = "Nope, you can't kill as jester."}
}
hook.Add( "PlayerUse", "NLLRagdollWakeAttempt", function( ply, ent )
    if IsValid(ent) and IsValid(ent.nllplayer) then
	if not AllowedWake[ent.nllplayer.condition] and not ply:IsWalking() then return end -- allow 'waking' if the victim needs to be killed
	if ply:IsWalking() then -- this entire block checks if the kill is "legal" :innocent:
		local BlacklistResult = "This kill is actually allowed"
		if IllegalCovertKill[ply:GetRole()] then
			for k,v in pairs(IllegalCovertKill[ply:GetRole()]) do -- Faction goes first
				if k == ent.nllplayer:GetRole() or k == ent.nllplayer:GetSubRole() then
					BlacklistResult = v
				end
			end
		end
		if IllegalCovertKill[ply:GetSubRole()] then
			for k,v in pairs(IllegalCovertKill[ply:GetSubRole()]) do -- Roles go next, for special interactions
				if k == ent.nllplayer:GetSubRole() or k == ent.nllplayer:GetSubRole() or k == ROLE_ALLCALL then
					BlacklistResult = v -- the significance of subrole going next means you can display specific messages
				end
			end
		end
		if BlacklistResult ~= "This kill is actually allowed" then
			if not ply.lastCovertAttempt then ply.lastCovertAttempt = 0 end
			if ply.lastCovertAttempt + 0.25 < SysTime() then
				ply:ChatPrint( BlacklistResult ) -- an informative message :^)
				ply.lastCovertAttempt = SysTime()
			end
			return -- no
		end
	end
        plytarg = ent.nllplayer
        NLL.UnRagdoll(plytarg)
	plytarg.nllismuted = false
        if timer.Exists("NLLUnragdoll".. plytarg:UserID()) then
            timer.Remove( "NLLUnragdoll".. plytarg:UserID())
        end
        
	if ply:IsWalking() then -- alt + e to kill instead of waking
	    if ply:GetInfoNum("ttt_nll_covertbuddha", 0) == 1 then
		plytarg:SetHealth(1)
		return
	    end
            local dmgtable = DamageInfo()
            dmgtable:SetDamage((plytarg:Health())*1.5)
            dmgtable:SetAttacker(ply)
            dmgtable:SetDamageForce(Vector(0,0,-1))
            dmgtable:SetDamagePosition(plytarg:GetPos())
            dmgtable:SetDamageType(4)
            dmgtable:SetInflictor(ply)
            timer.Create("NLLKillTarget".. plytarg:UserID(), 0.2, 1, function()
                plytarg:TakeDamageInfo( dmgtable )
            end)
        end
    end
end)

function NLL.PlayerZZZ( ply, pushdir, stuntype, timebefore, timedur )
	local id = ply:UserID()
        
	if stuntype == "ZZZ" or stuntype == "KSR" then -- Kissers cannot be woke
		if timebefore < 5 then ply.nllismuted = true end -- Instantly mute a player if they happen to get struck by a 'critical tranq'
		if timer.Exists("NLLSleepIn"..id) then
			if timer.TimeLeft( "NLLSleepIn"..id ) < 3 then return end
			local newdelay = math.min( timebefore/3, timer.TimeLeft( "NLLSleepIn"..id )/2 )
			timer.Remove("NLLSleepIn"..id)
			timer.Create("NLLSleepIn"..id, newdelay, 1, function()
				NLL.Ragdoll(ply, pushdir,stuntype)
				ply.nllismuted = true
				timer.Create("NLLUnragdoll"..id, timedur, 1, function()
					NLL.UnRagdoll(ply)
					ply.nllismuted = false
				end)
			end)
			
			ply.DrowsyDuration = newdelay
			net.Start("nllinfopayload")
				net.WriteString("drowsy")
				net.WriteTable({["drowsy"] = newdelay})
			net.Send(ply)
			return
		end
		timer.Create("NLLSleepIn"..id, timebefore, 1, function()
			NLL.Ragdoll(ply, pushdir,stuntype)
			ply.nllismuted = true
			timer.Create("NLLUnragdoll"..id, timedur, 1, function()
				NLL.UnRagdoll(ply)
				ply.nllismuted = false
			end)
		end)
		ply.DrowsyDuration = timebefore
		net.Start("nllinfopayload")
			net.WriteString("drowsy")
			net.WriteTable({["drowsy"] = timebefore})
		net.Send(ply)
		return
	end
	if stuntype == "STN" or stuntype == "TZE" then -- Taze shakes more violently than Stun
		if not ply.nllstnpr then ply.nllstnpr = 0 end
		ply.nllstnpr = ply.nllstnpr + timebefore -- Stun Damage
		if ply.nllstnpr < 100 then // Not above 100 Stun Damage, don't do anything.
			if timer.Exists("NLLSTNHeal"..id) then timer.Remove("NLLSTNHeal"..id) end
			timer.Create("NLLSTNHeal"..id,15,1,function()
				ply.nllstnpr = 0 -- They haven't been hit by stun for 15 seconds, heal that stun damage
			end)
			return
		end
		timer.Create("NLLSleepIn"..id,0,1,function()
			ply.nllstnpr = 0
			NLL.Ragdoll(ply, pushdir,stuntype)
			ply.nllismuted = true
			timer.Create("NLLUnragdoll"..id, timedur, 1, function()
				NLL.UnRagdoll(ply)
				ply.nllismuted = false
			end)
		end)
		return
	end
	if stuntype == "---" then -- "Surrender". Supposed to allow self ragdolling, unused for now.
		NLL.Ragdoll(ply, pushdir,"---")
		ply.nllismuted = false -- You're still awake, you shouldn't be muted while surrendering.
		timer.Create("NLLUnragdoll"..id, timedur, 1, function()
			NLL.UnRagdoll(ply)
			ply.nllismuted = false
		end)
		return
	end
	if stuntype == "PLV" then -- Pulverize, bone anihilation method
		NLL.Ragdoll(ply, pushdir,"PLV")
		ply.nllismuted = true
		timer.Create("NLLUnragdoll"..id, timedur, 1, function()
			NLL.UnRagdoll(ply)
			ply.nllismuted = false
		end)
		return
	end
end
else -- clientside code

local condcolors = { -- Will add the ability to customize condcolors later
	["ZZZ"] = {Color(150,150,255),"sleeping","wake up"},
	["STN"] = {Color(255,150,150),"stunned"},
	["KSR"] = {Color(255,0,255),"a floorkisser"},
	["PLV"] = {Color(255,0,0),"suffering","make it stop"},
	["---"] = {Color(150,150,150),"surrendering","make at ease"}
}

function NLL_BuddhaKillUpdate(ply,cmd,args)
	if args[1] ~= "0" then
		net.Start("nllupdatebuddha")
		net.WriteInt(1,4)
		net.SendToServer()
		return
	end
	net.Start("nllupdatebuddha")
	net.WriteInt(0,4)
	net.SendToServer()
	return
end

local NLL_COVERT_BUDDHA = CreateClientConVar("ttt_nll_covertbuddha", "0", true, true, "If nonzero, covertly killing will drop your target's hp to 1",0,1)

net.Receive("nllinfopayload", function()
	local payloadtype = net.ReadString()
	local payload = net.ReadTable()
	if string.find( payloadtype, "health", 1, false ) then
		payload["subject"].newhp = payload["health"]
	end
	if string.find( payloadtype, "cond", 1, false ) then
		payload["subject"].condition = payload["condition"]
	end
	if string.find( payloadtype, "drowsy", 1, false ) then -- only network drowsy directly to the player who needs it
		LocalPlayer().DrowsyDuration = payload["drowsy"]
	end
end)

hook.Add("PlayerBindPress", "TG_NLL", function(ply,bind,pressed)
	if IsValid(ply:GetNWEntity("nllviewrag")) then
		if bind == "+duck" then
			if ply.nllthirdpersonview == nil then ply.nllthirdpersonview = false end
			
			ply.nllthirdpersonview = not ply.nllthirdpersonview
		end
	end
end)
local dist = 200
local view = {}
hook.Add("CalcView", "TG_NLL", function(ply, origin, angles, fov)
	local rag = ply:GetNWEntity("nllviewrag")
	if IsValid(rag) then
		local bid = rag:LookupBone("ValveBiped.Bip01_Head1")
		if bid then
			local dothirdperson = false
			dothirdperson = ply.nllthirdpersonview
			
			if dothirdperson then
				local ragpos = rag:GetBonePosition(bid)
				
				local pos = ragpos - (ply:GetAimVector()*dist)
				local ang = (ragpos - pos):Angle()
				
				--Do a traceline so he can't see through walls
				local trdata = {}
				trdata.start = ragpos
				trdata.endpos = pos
				trdata.filter = rag
				local trres = util.TraceLine(trdata)
				if trres.Hit then
					pos = trres.HitPos + (trres.HitWorld and trres.HitNormal * 3 or vector_origin)
				end
				
				view.origin = pos
				view.angles = ang
			else
				local pos,ang = rag:GetBonePosition(bid)
				pos = pos + ang:Forward() * 7
				ang:RotateAroundAxis(ang:Up(), -90)
				ang:RotateAroundAxis(ang:Forward(), -90)
				pos = pos + ang:Forward() * 1
				
				view.origin = pos
				view.angles = ang
			end
			
			return view
		end
	end
end)
local w,h = ScrW(), ScrH()
local w2,h2 = w/2,h/2
local function IsOnScreen(pos)
	return pos.x > 0 and pos.x < w and pos.y > 0 and pos.y < h
end
local function GrabPlyInfo(ply)

	local text, color
	if ply:GetNWBool("disguised", false) then
		if LocalPlayer():IsTraitor() or LocalPlayer():IsSpec() then
			text = ply:Nick() .. LANG.GetUnsafeLanguageTable().target_disg
		else
			-- Do not show anything
			return
		end
		color = COLOR_RED
	else
		text = ply:Nick()
	end
	
	return text, (color or COLOR_WHITE), "TargetID"
end

function SimpleTextShadowed(txt, font, wpos, hpos, color, size)
	draw.SimpleText(txt, font, wpos - 1, hpos - 1, Color(0,0,0,255), size)
	draw.SimpleText(txt, font, wpos, hpos, color, size)
end

hook.Add("HUDPaint", "TG_NLL", function()
	--Draws info about crouch able to switch between third and firstperson
	if IsValid(LocalPlayer():GetNWEntity("nllviewrag")) then
		local txt = string.format("Press %s to switch between third and firstperson view.", input.LookupBinding("+duck"))
		SimpleTextShadowed(txt, "TargetID", w2, h/10, Color(200,200,200,255), 1)
	end
	
	local targ = LocalPlayer():GetEyeTrace().Entity
	if IsValid(targ) and IsValid(targ:GetNWEntity("nllplyowner")) and LocalPlayer():GetPos():Distance(targ:GetPos()) < 400 then
		local pos = targ:GetPos():ToScreen()
		if IsOnScreen(pos) then
			local ply = targ:GetNWEntity("nllplyowner")
			local nick,nickclr,font = GrabPlyInfo(ply)
			if not nick then return end -- Someone doesn't want us to draw his info.
			
			SimpleTextShadowed(nick, font, pos.x, pos.y - 50, nickclr, 1)
			if not condcolors[ply.condition] then conditionColor = Color(150,150,255) else conditionColor = condcolors[ply.condition][1] end
			SimpleTextShadowed(ply.condition, font, pos.x, pos.y - 70, conditionColor, 1)
			
			local hp = (ply.newhp and ply.newhp or ply:Health())
			
			local txt,clr = util.HealthToString(hp) -- Grab TTT Data
			txt = LANG.GetUnsafeLanguageTable()[txt] -- Convert to whatever language
			SimpleTextShadowed(txt, "TargetIDSmall2", pos.x, pos.y - 30, clr, 1)
			
			local textToShow = ""
			if not condcolors[ply.condition] then textToShow = string.format("This player is stunned! Press %s %s to covertly kill.",input.LookupBinding("+walk"),input.LookupBinding("+use")) else
				textToShow = "This player is "..condcolors[ply.condition][2].."!"
				if condcolors[ply.condition][3] then textToShow = textToShow..string.format(" Press %s to %s.",input.LookupBinding("+use"),condcolors[ply.condition][3]) end
				textToShow = textToShow .. string.format(" Press %s %s to covertly kill.",input.LookupBinding("+walk"),input.LookupBinding("+use"))
			end
			SimpleTextShadowed(textToShow, "TargetIDSmall2", pos.x, pos.y - 10, Color(255,255,200), 1)
		end
	end
end)

hook.Add( "RenderScreenspaceEffects", "MotionBlurEffect", function()
	if not LocalPlayer().DrowsyDuration then LocalPlayer().DrowsyDuration = 0 end
	if LocalPlayer().DrowsyDuration ~= 0 and not IsValid(LocalPlayer():GetNWEntity("nllviewrag")) then
		DrawMotionBlur( math.Clamp( -0.5 + LocalPlayer().DrowsyDuration/6,0.02,1), 1, 0.01 )
	end
end )

end


//shared
hook.Add( "Tick", "DrowsyVariableControl", function() // allows client to predict how drowsy they should be.
	for k,v in ipairs(SERVER and player.GetAll() or IsValid(LocalPlayer()) and {LocalPlayer()}) do
		
		if not v.DrowsyDuration then v.DrowsyDuration = 0 end
		v.DrowsyDuration = math.Clamp(v.DrowsyDuration - engine.TickInterval(),0,60)
	end
end)

hook.Add("TTTPlayerSpeedModifier","DrowsySpeedControl",function(ply, isSlowed, moveData, speedMultiplierModifier)
	if not ply.DrowsyDuration then ply.DrowsyDuration = 0 end
	if ply.DrowsyDuration ~= 0 then
		speedMultiplierModifier[1] = math.Clamp(0 + ply.DrowsyDuration/10,0.2,1)
	else
		speedMultiplierModifier[1] = 1
	end
end)

