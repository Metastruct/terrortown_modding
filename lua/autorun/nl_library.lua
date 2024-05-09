// The tazer is a dependancy at this point //
NLL = {}

//NetworkStrings//
if SERVER then
	util.AddNetworkString("nllsendhealth")
	util.AddNetworkString("nllplayercond")
	util.AddNetworkString("nllupdatebuddha")

net.Receive("nllupdatebuddha",function(len,ply)
	ply.CovertBuddha = net.ReadInt(4)
end)

// Block speaking while sleeping or stunned
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

// Handles updating the displayed health on bodies.
hook.Add("Think", "TG_NLL", function()
	for k,v in pairs(player.GetAll()) do
		if IsValid(v.nllragdoll) then
			//Send new health. The normal health sending is somehow broken when ragdolled.
			if v:Health() != v.lasthp then
				net.Start("nllsendhealth")
					net.WriteEntity(v)
					net.WriteInt(v:Health(),32)
				net.Broadcast()
				v.lasthp = v:Health()
			end
			
			local rag = v.nllragdoll
			local phys = rag:GetPhysicsObjectNum(0)
			if phys:IsValid() and v.condition == "STN" then // This player is painfully stunned, not asleep, shake them a LITTLE bit.
				phys:AddAngleVelocity(Vector(0,math.sin(CurTime() * 2) * 100,0))
			end
		end
	end
end)

//Stores the players weaponclasses and ammo in a table.
function NLL.PlyStoreWeapons(ply)
	ply.storeweps = {}
	for k,v in pairs(ply:GetWeapons()) do
		table.insert(ply.storeweps, {cl = v:GetClass(), c1 = v:Clip1(), c2 = v:Clip2()})
	end
end

//Retrieves the stored weapons
function NLL.PlyRetrieveWeapons(ply)
	for k,v in pairs(ply.storeweps or {}) do
		ply:Give(v.cl)
		local wep = ply:GetWeapon(v.cl)
		if IsValid(wep) then
			wep:SetClip1(v.c1)
			wep:SetClip2(v.c2)
		end
	end
end

/*
Makes a hull trace the size of a player.
*/
local data = {}
function NLL.PlayerHullTrace(pos, ply, filter)
	data.start = pos
	data.endpos = pos
	data.filter = filter
	
	return util.TraceEntity( data, ply )
end

/*
Attemps to place the player at this position or as close as possible.
*/
// Directions to check
local directions = {
	Vector(0,0,0), Vector(0,0,1), //Center and up
	Vector(1,0,0), Vector(-1,0,0), Vector(0,1,0), Vector(0,-1,0) //All cardinals
}

for deg=45,315,90 do //Diagonals
	local r = math.rad(deg)
	table.insert(directions, Vector(math.Round(math.cos(r)), math.Round(math.sin(r)), 0))
end

local magn = 15 // How much increment for each iteration
local iterations = 2 // How many iterations
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
				ply:SetPos(pos) // We've done as many checks as we wanted, lets just force him to get stuck then.
				return false
			end
		end
		
		tr = NLL.PlayerHullTrace(dirvec + pos, ply, filter)
	until tr.Hit == false
	
	ply:SetPos(pos + dirvec)
	return true
end


/*
Sets the player invisible/visible
*/
function NLL.PlayerInvis( ply, bool )
	ply:SetNoDraw(bool)
	ply:DrawShadow(not bool)

	if pac and pac.TogglePartDrawing then
		pac.TogglePartDrawing(ply, not bool)
	end
end


/*
Deploy player ragdoll, Sleeping Variants can be woken up with E.
*/
function NLL.Ragdoll( ply, pushdir, stuntype)
	local plyphys = ply:GetPhysicsObject()
	local plyvel = Vector(0,0,0)
	if plyphys:IsValid() then
		plyvel = plyphys:GetVelocity()
	end
	
	ply.nlldroppos = ply:GetPos() // Store pos incase the ragdoll is missing when we're to unrag him.
	
	local rag = ents.Create("prop_ragdoll")
		rag:SetModel(ply:GetModel())
		rag:SetPos(ply:GetPos())
		rag:SetAngles(Angle(0,ply:GetAngles().y,0))
		//FromPlyColor(ply:GetPlayerColor())) //Clothes get correct color, but the head gets pitchblack. :(
		rag:SetColor(ply:GetColor())
		rag:SetMaterial(ply:GetMaterial())
		rag:Spawn()
		rag:Activate()
	
	if not IsValid(rag:GetPhysicsObject()) then
		MsgN("A slept player didn't get a valid ragdoll. Model ("..ply:GetModel()..")!")
		SafeRemoveEntity(rag)
		return false
	end
	
	//Lower inertia makes the ragdoll have trouble rolling. Citizens have 1,1,1 as default, while combines have 0.2,0.2,0.2.
	rag:GetPhysicsObject():SetInertia(Vector(1,1,1)) 
	
	//Push him back abit
	plyvel = plyvel + pushdir*200
	rag:GetPhysicsObject():SetVelocity(plyvel)
		
	//Stop firing of weapons
	NLL.PlyStoreWeapons(ply)
	ply:StripWeapons()
	
	//Makes him not collide with anything, including traces.
	ply:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
	
	//Make him follow the ragdoll, if the player gets away from the ragdoll he won't get stuff rendered properly.
	ply:SetParent(rag)
	
	//Make the player invisible.
	NLL.PlayerInvis(ply, true)

	ply.nllragdoll = rag
	rag.nllplayer = ply
	ply.condition = stuntype
		
	ply:SetNWEntity("nllviewrag", rag)
	rag:SetNWEntity("nllplyowner", ply)
	
	ply.lasthp = ply:Health()
	net.Start("nllsendhealth")
		net.WriteEntity(ply)
		net.WriteInt(ply:Health(),32)
	net.Broadcast()
	net.Start("nllplayercond")
	net.WriteEntity(ply)
	net.WriteString(stuntype)
	net.Broadcast()
	
	return true
end

function NLL.UnRagdoll( ply )
	local ragvalid = IsValid(ply.nllragdoll)
	local pos
	if ragvalid then // Sometimes the ragdoll is missing when we want to unrag, not good!
		if ply.nllragdoll.hasremoved then return end // It has already been removed.
		
		pos = ply.nllragdoll:GetPos()
		ply:SetModel(ply.nllragdoll:GetModel())
		ply.nllragdoll.hasremoved = true
	else
		pos = ply.nlldroppos // Put him at the place he got sleepd, works great.
	end
	ply:SetParent()
	
	NLL.PlayerSetPosNoBlock(ply, pos, {ply, ply.nllragdoll})
	
	ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
	
	timer.Simple(0,function()
		SafeRemoveEntity(ply.nllragdoll)
		NLL.PlayerInvis(ply, false)
	end)
	
	timer.Simple(.1, function()
		NLL.PlyRetrieveWeapons(ply)
	end)
	
	net.Start("nllendview")
	net.Send(ply)
end


hook.Add("EntityTakeDamage", "NLLDamageHandler", function(ent, dmginfo)
	if ent:IsPlayer() and IsValid(ent.nllragdoll) and not ent.ragdolldamage then // If we're hitting the player somehow we won't let, the ragdoll should take the damage.
		dmginfo:SetDamage(0)
		return
	end
	
	if IsValid(ent.nllplayer) and (dmginfo:GetAttacker() != game.GetWorld()) then //Worldspawn appears to be very eager to damage ragdolls. Don't!		
		local ply = ent.nllplayer
		//To prevent infiniteloop and other trickery, we need to know if it was ragdamage.
		ply.ragdolldamage = true
		ply:TakeDamageInfo(dmginfo) // Apply all ragdoll damage directly to the player.
		ply.ragdolldamage = false
	end
end)

hook.Add( "PlayerUse", "NLLRagdollWakeAttempt", function( ply, ent )
    if IsValid(ent) and IsValid(ent.nllplayer) then //Don't wake players that don't have their condition set to "ZZZ"
        if ent.nllplayer.condition != "ZZZ" and not ply:IsWalking() then return end // allow 'waking' if the victim is stunned and needs to be killed
        plytarg = ent.nllplayer
        NLL.UnRagdoll(plytarg)
	plytarg.nllismuted = false
        if timer.Exists("NLLUnragdoll".. plytarg:UserID()) then
            timer.Remove( "NLLUnragdoll".. plytarg:UserID())
        end
        
	if ply:IsWalking() then // alt + e to kill instead of waking
	    if ply.CovertBuddha == nil then ply.CovertBuddha = 0 end
	    if ply.CovertBuddha == 1 then
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
	

function NLL.PlayerZZZ( ply, pushdir, timebefore, timedur )
	local id = ply:UserID()
        
	if ply.isDrowsy then return end // don't fuck with drowsy players
	if timer.Exists("NLLSleepIn"..id) then
		if timer.TimeLeft( "NLLSleepIn"..id ) < 3 then return end
		local newdelay = math.min( timebefore/3, timer.TimeLeft( "NLLSleepIn"..id )/2 )
		timer.Remove("NLLSleepIn"..id)
		timer.Create("NLLSleepIn"..id, newdelay, 1, function()
			NLL.Ragdoll(ply, pushdir,"ZZZ")
			ply.nllismuted = true
			timer.Create("NLLUnragdoll"..id, timedur, 1, function()
				NLL.UnRagdoll(ply)
				ply.nllismuted = false
			end)
		end)
		return
	end
	timer.Create("NLLSleepIn"..id, timebefore, 1, function()
		NLL.Ragdoll(ply, pushdir,"ZZZ")
		ply.nllismuted = true
		timer.Create("NLLUnragdoll"..id, timedur, 1, function()
			NLL.UnRagdoll(ply)
			ply.nllismuted = false
		end)
	end)	
end
else // clientside code

function NLL_BuddhaKillUpdate(ply,cmd,args)
	if args[1] != "0" then
		net.Start("nllupdatebuddha")
		net.WriteInt(1,4)
		net.SendToServer()
	else
		net.Start("nllupdatebuddha")
		net.WriteInt(0,4)
		net.SendToServer()
	end
end

concommand.Add( "ttt_nl_buddhakill", function(ply,cmd,args) NLL_BuddhaKillUpdate(ply,cmd,args) end, nil, "If nonzero, covertly killing will instead set your victim's hp to 1", 0 )

net.Receive("nllplayercond", function()
	local ply = net.ReadEntity()
	ply.condition = net.ReadString()
end)
hook.Add("PlayerBindPress", "TG_NLL", function(ply,bind,pressed)
	if IsValid(ply:GetNWEntity("nllviewrag")) then
		if bind == "+duck" then
			if ply.nllthirdpersonview == nil then
				ply.nllthirdpersonview = false
			end
			
			ply.nllthirdpersonview = not ply.nllthirdpersonview
			//print(ply.nllthirdpersonview)
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
				
				//Do a traceline so he can't see through walls
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

hook.Add("HUDPaint", "TG_NLL", function()
	//Draws info about crouch able to switch between third and firstperson
	if IsValid(LocalPlayer():GetNWEntity("nllviewrag")) then
		local txt = string.format("Press %s to switch between third and firstperson view.", input.LookupBinding("+duck"))
		draw.SimpleText(txt, "TargetID", ScrW()/2 + 1, 10 + 1, Color(0,0,0,255), 1)
		draw.SimpleText(txt, "TargetID", ScrW()/2, 10, Color(200,200,200,255), 1)
	end
	
	local targ = LocalPlayer():GetEyeTrace().Entity
	if IsValid(targ) and IsValid(targ:GetNWEntity("nllplyowner")) and LocalPlayer():GetPos():Distance(targ:GetPos()) < 400 then
		local pos = targ:GetPos():ToScreen()
		if IsOnScreen(pos) then
			local ply = targ:GetNWEntity("nllplyowner")
			local nick,nickclr,font = GrabPlyInfo(ply)
			if not nick then return end // Someone doesn't want us to draw his info.
			
			draw.DrawText(nick, font, pos.x-1, pos.y - 51, Color(0,0,0), 1)
			draw.DrawText(nick, font, pos.x, pos.y - 50, nickclr, 1)
			
			draw.DrawText(ply.condition, font, pos.x+24, pos.y - 61, Color(0,0,0), 1)
			draw.DrawText(ply.condition, font, pos.x+25, pos.y - 60, Color(150,150,255), 1)
			
			local hp = (ply.newhp and ply.newhp or ply:Health())
			
			local txt,clr = util.HealthToString(hp) // Grab TTT Data
			txt = LANG.GetUnsafeLanguageTable()[txt] // Convert to whatever language
			draw.DrawText(txt, "TargetIDSmall2", pos.x-1, pos.y - 31, Color(0,0,0), 1)
			draw.DrawText(txt, "TargetIDSmall2", pos.x, pos.y - 30, clr, 1)
			if ply.condition == "ZZZ" then
				draw.DrawText(string.format("Press %s to wake up! Press %s %s to covertly kill.",input.LookupBinding("+use"),input.LookupBinding("+walk"),input.LookupBinding("+use")), "TargetIDSmall2", pos.x-1, pos.y - 11, Color(0,0,0), 1)
				draw.DrawText(string.format("Press %s to wake up! Press %s %s to covertly kill.",input.LookupBinding("+use"),input.LookupBinding("+walk"),input.LookupBinding("+use")), "TargetIDSmall2", pos.x, pos.y - 10, Color(255,255,200), 1)
			else
				draw.DrawText(string.format("This player is stunned! Press %s %s to covertly kill.",input.LookupBinding("+walk"),input.LookupBinding("+use")), "TargetIDSmall2", pos.x-1, pos.y - 11, Color(0,0,0), 1)
				draw.DrawText(string.format("This player is stunned! Press %s %s to covertly kill.",input.LookupBinding("+walk"),input.LookupBinding("+use")), "TargetIDSmall2", pos.x, pos.y - 10, Color(255,255,200), 1)
			end
		end
	end
end)

net.Receive("nllsendhealth", function()
	local ent = net.ReadEntity()
	local newhp = net.ReadInt(32)
	ent.newhp = newhp
end)

end