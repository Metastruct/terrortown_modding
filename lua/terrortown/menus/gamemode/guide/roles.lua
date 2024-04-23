local Key = Key
local TryT = LANG.TryTranslation
local GetPT = LANG.GetParamTranslation
local cos = math.cos
local abs = math.abs

local function BindKey(bindName)
	local binding = tonumber(bind.Find(bindName))

	if binding and binding != KEY_NONE then
		return string.upper(input.GetKeyName(binding))
	else
		return "NONE"
	end
end

local highlightColor = Color(28, 93, 201)

local mg = 5 -- margin
local pd = 10 -- padding
local iconSize = 72

local namedTeams

local roleEnabledConVars = {}

local fallbackSpecialCases = {
	["traitor"] = function(params) return GetPT("info_popup_traitor_alone", params) end,
	["executioner"] = function(params) return GetPT("ttt2_desc_executioner", params) end,
	["sacrifice"] = function(params) return GetPT("ttt2_desc_sacrifice", params) end,
}

-- Custom role explanations table (filled out at the bottom of the file)
local customExplanations = {}

-- Derma Code
CLGAMEMODESUBMENU.base = "base_gamemodesubmenu"

CLGAMEMODESUBMENU.priority = 99
CLGAMEMODESUBMENU.title = "submenu_guide_roles_title"

function CLGAMEMODESUBMENU:Populate(parent)
	self.Parent = parent

	parent:GetCanvas():DockPadding(10, 10, 10, 10)

	self:CreateRoleList()

	self:AddHook()
end

function CLGAMEMODESUBMENU:CreateRoleList()
	if not namedTeams then
		namedTeams = {
			["nones"] = math.huge
		}

		for k,v in ipairs(roles.GetAvailableTeams()) do
			namedTeams[v] = k
		end
	end

	local parent = self.Parent

	local titleTextColor = vskin.GetTitleTextColor()
	local bgColor = vskin.GetBackgroundColor()

	parent:Clear()

	local descTextParams = {
		menukey = Key("+menu_context", "C"),
		scorekey = Key("+showscores", "TAB"),
		teamvoicekey = BindKey("ttt2_voice_team"),
		vampirebatkey = BindKey("vamptranstoggle"),
		impostorkillkey = BindKey("ImpostorSendInstantKillRequest"),
		impostorcyclekey = BindKey("ImpostorSabotageCycle"),
		impostorsabotagekey = BindKey("ImpostorSendSabotageRequest"),
	}

	local sortedRoles = roles.GetList()
	local pl = LocalPlayer()

	self.CurrentPlayerRole = pl:GetSubRole()
	local currentRole = self.CurrentPlayerRole

	table.sort(sortedRoles, function(a, b)
		if a.index == currentRole then return true end
		if b.index == currentRole then return false end
		if namedTeams[a.defaultTeam] == namedTeams[b.defaultTeam] then return a.index < b.index end
		return namedTeams[a.defaultTeam] < namedTeams[b.defaultTeam]
	end)

	parent.RolePanelHeaders = {}

	local titleBox = parent:Add("DContentPanelTTT2")
	titleBox:Dock(TOP)
	titleBox:SetHeight(32)
	titleBox:DockMargin(0, 0, 0, mg)
	titleBox:DockPadding(pd, pd, pd, pd)
	titleBox.Paint = function(s, w, h)
		draw.RoundedBox(8, 0, 0, w, h, bgColor)
	end

	local title = titleBox:Add("DLabel")
	title:Dock(FILL)
	title:SetFont("DermaTTT2Button")
	title:SetTextColor(titleTextColor)
	title:SetText("Click on a role to learn more about it!")
	title:SetContentAlignment(5)

	for _, role in ipairs(sortedRoles) do
		if role.name == "none" then continue end

		local enabledConVar = roleEnabledConVars[role.name]
		if not enabledConVar then
			roleEnabledConVars[role.name] = GetConVar("ttt_" .. role.name .. "_enabled") or true

			enabledConVar = roleEnabledConVars[role.name]
		end

		if enabledConVar != true and not enabledConVar:GetBool() then continue end

		local baseContainer = parent:Add("DContentPanelTTT2")
		baseContainer:Dock(TOP)
		baseContainer:SetHeight(iconSize)
		baseContainer:DockMargin(0, 0, 0, mg)
		baseContainer.Paint = function(s, w, h)
			draw.RoundedBox(8, 0, 0, w, h, bgColor)

			surface.SetDrawColor(68, 74, 81)
			surface.DrawRect(pd, iconSize + 1, w - (pd * 2), 1)
		end

		baseContainer.DescriptionLabels = {}

		local header = baseContainer:Add("DContentPanelTTT2")
		header:Dock(TOP)
		header:DockPadding(pd, pd, pd, pd)
		header:SetHeight(iconSize)
		header:SetCursor("hand")

		header.Paint = function(s, w, h)
			local hovered = s:IsHovered() or s:IsChildHovered()
			local isRole = currentRole == role.index

			if hovered or isRole then
				highlightColor.a = hovered and 8 or 0
				highlightColor.a = isRole and highlightColor.a + 4 + 12 * abs(cos(RealTime() * 3)) or highlightColor.a

				draw.RoundedBox(8, 0, 0, w, h, highlightColor)
			end
		end
		header.CalcExpandHeight = function(s)
			baseContainer:SetTall(9999)
			baseContainer:InvalidateLayout(true)

			local totalHeight = iconSize + (pd * 3) + baseContainer.TeamLabel:GetTall()

			for i = 1, #baseContainer.DescriptionLabels do
				local desc = baseContainer.DescriptionLabels[i]
				if not IsValid(desc) then continue end

				totalHeight = totalHeight + desc:GetTall()
			end

			s.ExpandHeight = totalHeight
		end
		header.Toggle = function(s, closeOthers)
			if closeOthers then
				for k,v in ipairs(parent.RolePanelHeaders) do
					if IsValid(v) and v != s and v.Expanded then
						v:Toggle()
					end
				end
			end

			s.Expanded = not s.Expanded

			if s.Expanded then
				s:CalcExpandHeight()

				-- Sometimes the scrollbar appearing is just enough for text to wrap onto a new line, check for this roughly 2 ticks later
				timer.Simple(0.025, function()
					if IsValid(s) and s.Expanded then
						s:CalcExpandHeight()
						baseContainer:SetTall(s.ExpandHeight)
					end
				end)
			end

			baseContainer:SetTall(s.Expanded and s.ExpandHeight or iconSize)
		end
		header.OnMousePressed = function(s, mcode)
			if mcode != MOUSE_LEFT then return end

			s:Toggle(true)
		end

		local roleName = TryT(role.name)

		local roleIcon = header:Add("DRoleImageTTT2")
		roleIcon:Dock(LEFT)
		roleIcon:SetWidth(iconSize - pd - pd)
		roleIcon:DockMargin(0, 0, pd * 1.5, 0)
		roleIcon:SetMaterial(role.iconMaterial)
		roleIcon:SetColor(role.color)
		roleIcon:SetCursor("hand")

		local name = header:Add("DLabel")
		name:Dock(FILL)
		name:SetFont("DermaTTT2Title")
		name:SetTextColor(titleTextColor)
		name:SetText(roleName)
		name:SetContentAlignment(4)

		local descContainer = baseContainer:Add("DPanel")
		descContainer:Dock(FILL)
		descContainer:DockMargin(pd, pd, pd, pd)
		descContainer.Paint = function() end

		local teamColor = TEAMS[role.defaultTeam] and TEAMS[role.defaultTeam].color
		local teamText = role.defaultTeam == "nones"
			and "You side with no one."
			or string.format("You side with the %s.", role.defaultTeam)

		local teamFade = 0.6
		local teamTextColor = teamColor
			and Color(
				teamColor.r + (255 - teamColor.r) * teamFade,
				teamColor.g + (255 - teamColor.g) * teamFade,
				teamColor.b + (255 - teamColor.b) * teamFade)
			or titleTextColor

		local teamDesc = descContainer:Add("DLabel")
		teamDesc:Dock(TOP)
		teamDesc:SetFont("DermaTTT2Title")
		teamDesc:SetText(teamText)
		teamDesc:SetTextColor(teamTextColor)
		teamDesc:SetAutoStretchVertical(true)
		teamDesc:DockMargin(0, 0, 0, mg)

		local descText = customExplanations[role.index]

		if descText and descText != "" then
			-- Show the custom explanation with the proper key bindings
			descText = string.Interpolate(descText, descTextParams)
		else
			-- There's no custom explanation, show the role's description text instead
			descText = "(This role has no custom help written for it yet.)\n\n" ..
				(isfunction(fallbackSpecialCases[role.name])
				and fallbackSpecialCases[role.name](descTextParams)
				or GetPT("info_popup_" .. role.name, descTextParams))
		end

		-- Because labels have text limits, we need to split them up when appropriate - determine the split points
		local descSplits = {}
		local descSeek = 1
		while descSeek < #descText do
			local start = descText:find("\n", descSeek, true)
			if not start then break end

			descSeek = start + 1
			descSplits[#descSplits + 1] = start
		end

		local descTexts = {}
		local stepCharLimit = 1000

		descSeek = 1

		if #descText > stepCharLimit then
			local descSeekTo = stepCharLimit

			while #descText > descSeekTo do
				for i = #descSplits, 1, -1 do
					local split = descSplits[i]

					if split <= descSeekTo then
						descTexts[#descTexts + 1] = descText:sub(descSeek, split - 1)
						descSeek = split + 1
						break
					end
				end

				descSeekTo = descSeek + stepCharLimit
			end
		end

		descTexts[#descTexts + 1] = descText:sub(descSeek, #descText)

		for i = 1, #descTexts do
			local desc = descContainer:Add("DLabel")
			desc:Dock(TOP)
			desc:SetFont("DermaTTT2Button")
			desc:SetTextColor(titleTextColor)
			desc:SetWrap(true)
			desc:SetAutoStretchVertical(true)
			desc:SetText(descTexts[i])

			baseContainer.DescriptionLabels[#baseContainer.DescriptionLabels + 1] = desc
		end

		baseContainer.TeamLabel = teamDesc

		-- Have the current role's box expanded by default
		if role.index == currentRole then
			header:Toggle()
		end

		parent.RolePanelHeaders[#parent.RolePanelHeaders + 1] = header
	end
end

function CLGAMEMODESUBMENU:AddHook()
	hook.Add("PreDrawHUD", "TTT2RoleGuideUpdate", function()
		if not IsValid(self.Parent) then hook.Remove("PreDrawHUD", "TTT2RoleGuideUpdate") end

		local pl = LocalPlayer()
		local newRole = pl:GetSubRole()

		if self.CurrentPlayerRole ~= newRole then
			self:CreateRoleList()
		end
	end)
end

-- Custom role explanation definitions
local function AddCustomExplanation(roleId, text)
	if roleId then
		customExplanations[roleId] = text
	end
end

AddCustomExplanation(ROLE_INNOCENT,
[[You are an ordinary innocent. Your goal is to work with your fellow innocents to figure out who the traitors are. Kill all the traitors to win!

Remember, everyone is suspicious of you like you are of them! Try not to jump to conclusions without solid evidence! If you mistakenly kill another innocent, you'll lower your odds of winning!

You can prove to everyone you're innocent by successfully killing traitors and confirming their corpses.]])

AddCustomExplanation(ROLE_TRAITOR,
[[You are a traitor among the innocents. Your goal is to eliminate all the innocents with the help of your traitor buddies... if you have any.

You can open the scoreboard with [{scorekey}] to see who you're teamed up with.
Voice chat with only the traitors using [{teamvoicekey}].

You can buy equipment using credits by pressing [{menukey}] to help with your onslaught. Be careful not to raise any unwanted suspicion with your equipment!

You'll start with a few credits - you can gain more credits by killing enough innocents, killing detectives, and by looting any unused credits off corpses.
You can also give credits to other people using the Transfer tab in the [{menukey}] menu.]])

AddCustomExplanation(ROLE_DETECTIVE,
[[You are a detective, sent out to help the innocents track down traitors using your detective resources.

Everyone knows you're a detective - you have the hat and everything! Including a DNA Scanner that can analyse DNA found on corpses, weapons and bombs to locate potential suspects.

You can buy equipment using credits by pressing [{menukey}].

You'll start with a few credits - you can get more credits by killing traitors, and by looting unused credits off corpses.]])

AddCustomExplanation(ROLE_JESTER,
[[You are a harmless jester, you cannot damage anyone!
But it would be so funny if someone killed you... it's your goal to have that happen! :)

Trick someone into shooting you by acting suspicious, but don't make it too obvious or you'll be called out as a jester and avoided.

Everyone is alerted when a jester is present at the start of a round, but only the traitors know it's you. Generally, the traitors will keep this knowledge to themselves and just avoid shooting you.

If you die without the aid of another player (like falling to your death), it won't be funny enough and you'll lose.
Blast and fire damage caused by a player will hurt you, but you'll always be left with at least 1 HP from it.]])

AddCustomExplanation(ROLE_SWAPPER,
[[You are a cheeky swapper! You want to create chaos by letting someone kill you...
When someone does kill you, you and your killer will swap roles. You'll also be revived instantly.

Since dying doesn't mean you win like the jester does, your victory will come from swapping to the innocents side or the traitors side, then fulfilling their goal.

Trick someone into shooting you by acting suspicious, but don't make it too obvious or you'll be called out as a "jester" and avoided.

Everyone is alerted that a "jester" is present at the start of a round, but only the traitors know it's you. Generally, the traitors will keep this knowledge to themselves and just avoid shooting you.

If you die without the aid of another player (like falling to your death), you won't be able to swap with anything and you'll accept your demise.]])

AddCustomExplanation(ROLE_UNKNOWN,
[[...yet. You are the unknown. You need someone to slay you so you can receive their role. It doesn't matter to you whose side you end up on.

When you die, you'll be revived in the next few seconds with the same role as your killer. They will need to stay alive until then, otherwise your revive will fail!
If you die without the aid of another player (like falling to your death), you won't be able to revive.

Be careful, some people can get cautious of you suddenly being alive again. If you revive onto the traitors side in front of some innocents, you could be in trouble.]])

AddCustomExplanation(ROLE_GAMBLER,
[[You are a gambling traitor. You've rolled the dice and got a randomised set of equipment! Have you gotten lucky?
Like the usual traitor, your goal is to eliminate all the innocents with the help of your traitor buddies.

Voice chat with only the traitors using [{teamvoicekey}].

You get no credits whatsoever, so no shopping for you. However, you do immediately start with a big pool of items than all other traitors! You can get to slaughtering right away! ...right?]])

AddCustomExplanation(ROLE_SHANKER,
[[You are a shanker ready to stab with your trusty shank knife.
Like the usual traitor, your goal is to eliminate all the innocents with the help of your traitor buddies.

Your shank knife is fast, silent, and does moderate damage from the front. You can backstab people for an instant kill.

Voice chat with only the traitors using [{teamvoicekey}].

You can buy equipment using credits by pressing [{menukey}] to help with your onslaught, if you manage to get some.

You start with no credits, but you can get some by killing detectives, and by looting any unused credits off corpses.
You can also give credits to other people using the Transfer tab in the [{menukey}] menu.]])

AddCustomExplanation(ROLE_EXECUTIONER,
[[You are an executioner. You gain a damage bonus towards your randomly selected target.
Like the usual traitor, your goal is to eliminate all the innocents with the help of your traitor buddies.

You can see the name of your randomly selected target in the bottom-left corner. Once you kill your target, you'll immediately get a new one. If you kill someone who isn't your target, you will have no target and no damage bonus for a small amount of time.

Voice chat with only the traitors using [{teamvoicekey}].

You can buy equipment using credits by pressing [{menukey}] to help with your onslaught.

You start with one credit - you can gain more by killing detectives, and by looting any unused credits off corpses.
You can also give credits to other people using the Transfer tab in the [{menukey}] menu.]])

AddCustomExplanation(ROLE_MESMERIST,
[[You are a traitor with mesmerist powers. You can revive someone to become your thrall.
Like the usual traitor, your goal is to eliminate all the innocents with the help of your traitor buddies.

You have a mesmerist defib! Find a corpse that has an intact brain (ie. they haven't been headshot to death), then revive them with your defib to gain a traitor buddy!

Look out for witnesses before you use your defib. People will get quite suspicious if they see you revive someone.

Voice chat with only the traitors using [{teamvoicekey}].

You can buy equipment using credits by pressing [{menukey}] to help with your onslaught.

You start with one credit - you can get more by killing detectives, and by looting any unused credits off corpses.
You can also give credits to other people using the Transfer tab in the [{menukey}] menu.]])

AddCustomExplanation(ROLE_THRALL,
[[You've been resurrected as a traitor by the mesmerist! Help them kill the innocents!
Like the usual traitor, your goal is to eliminate all the innocents with the help of your traitor buddies.

Voice chat with only the traitors using [{teamvoicekey}].

If you were already confirmed dead, you may want to keep quiet to avoid being asked how you're alive again.

Don't worry if your mesmerist dies, your life isn't tied to them so you can keep going. Avenge them!

You get one credit to spend! Perhaps your mesmerist will be kind enough to send more credits your way?]])

AddCustomExplanation(ROLE_DEFECTOR,
[[You've picked up a Jihad Bomb from a traitor and converted to their side! Sacrificing yourself sounds fun!

As a defector, you can ONLY deal damage using the bomb you picked up. This means shooting people won't work!

Use it wisely, it will kill you too! For the best results, wait for people to crowd around one spot.

Voice chat with only the traitors using [{teamvoicekey}].]])

AddCustomExplanation(ROLE_DEFECTIVE,
[[You are an EVIL traitorous detective - a defective! You look like a regular detective to the innocents. Gain their trust and get the real detectives killed!
Like the usual traitor, your goal is to eliminate all the innocents with the help of your traitor buddies.

You and the other detectives cannot harm each other while there are innocents still alive. You need to convince them to kill their detectives for you... or have your traitor friends take them down.

Voice chat with only the traitors using [{teamvoicekey}].

You can buy detective equipment using credits by pressing [{menukey}].

You'll start with a few credits - you can get more by killing enough innocents, and by looting unused credits off corpses. Additionally, you will get an extra credit when a real detective is killed.
You can also give credits to other people using the Transfer tab in the [{menukey}] menu.]])

AddCustomExplanation(ROLE_VAMPIRE,
[[You are a traitor vampire! Your thirst for blood is insatiable, you will slowly waste away without it...
Harm people in any way to fulfill your bloodlust.
Like the usual traitor, your goal is to eliminate all the innocents with the help of your traitor buddies.

If you melee someone, you will consume their blood and heal up!
You can overheal a sizeable amount if you're already at max health. Don't worry, other people will still see you as "Healthy" while you're overhealed.

Press [{vampirebatkey}] to turn into a "bat", letting you fly around quickly and escape from danger! You can change this bind in the F1's Key Bindings menu.

To control your "bat" form:
▪ Hold no movement keys to let yourself glide.
▪ Hold forward movement while looking around to move in that direction, including up and down.
▪ Jump to launch off the ground. Press jump in mid-air to flap yourself upwards.

Voice chat with only the traitors using [{teamvoicekey}].

You can buy equipment using credits by pressing [{menukey}] to help with your onslaught.

You'll start with one credit - you can get more by killing detectives, and by looting any unused credits off corpses.
You can also give credits to other people using the Transfer tab in the [{menukey}] menu.]])

AddCustomExplanation(ROLE_IMPOSTOR,
[[Impostor. Among Us. That's your role.
Like the usual traitor, your goal is to eliminate all the innocents with the help of your traitor buddies.

You deal slightly less damage than normal, so if you're going to shoot someone, make it count!
Stand near a player and press [{impostorkillkey}] to instantly kill them. Like in Among Us, this has a lengthy cooldown.

You have a "Vent" weapon in your inventory that lets you place vents to quickly traverse around later. These vents are invisible until they have been used at least once.

You are unable to buy equipment. Instead, you can sabotage lights, comms, oxygen, and the reactor. This can be confusing to control at first, so here's a quick run-down:
▪ Press [{impostorcyclekey}] to cycle through your sabotaging tools. Keep an eye on the bottom-left corner.
▪ Press [{impostorsabotagekey}] to sabotage what you've selected.
▪ You can choose where the sabotage will happen by using the Station Manager. Press [{impostorsabotagekey}] on a crewmate icon to set the sabotage spot there. You can create a new spot by pressing [{impostorsabotagekey}] on a player too.

Voice chat with only the traitors using [{teamvoicekey}].]])

AddCustomExplanation(ROLE_HAUNTED,
[[You are a haunting traitor! If you are killed by someone, you will haunt their soul until you can take it over...
Like the usual traitor, your goal is to eliminate all the innocents with the help of your traitor buddies.

Being killed marks your killer with dark smoke. If they are killed, you will steal their soul and be revived at your ragdoll!

Your fellow traitors should focus taking out your haunted killer. Hope that the innocents aren't protecting them.

Voice chat with only the traitors using [{teamvoicekey}].

Due to your haunting abilities, you get no credits and cannot buy equipment.]])

AddCustomExplanation(ROLE_MEDIC,
[[You are a medic that's been sent to provide aid to everyone in the field!
You don't care what's really going on - making sure your patients are healthy is all that matters to you!

Use your technologically advanced medigun to heal people by attaching a healing beam to them.

If someone important has gone down, you can revive them with your one-time use defib!

Try not to get yourself involved by killing someone! If you break your oath, you will be stripped of your medical supplies and lose some karma!]])

AddCustomExplanation(ROLE_AMNESIAC,
[[You are suffering from amnesia and don't remember what role you are. Finding and confirming an unidentified body will surely jog your memory.

Once you've confirmed a body, you will discretely become that body's role.

While you are an amnesiac, you are on neither side. You can still contribute to the killing, but you could weaken the side you end up joining...]])

AddCustomExplanation(ROLE_WRATH,
[[You are an innocent with a short fuse. If you are wrongly killed, you will come back with a vengeance.

Being killed by another innocent vexes you, thus you will awaken as a traitor. Kill the fuckers.

You aren't aware of your wrath nature. You will only discover it in death. Unless, of course, a traitor kills you.]])

AddCustomExplanation(ROLE_CUPID,
[[You are Cupid! You want to make two people fall in love and work together! Til death do them part...

Take out your Cupid Crossbow and shoot someone to mark them for love. You can then either choose to shoot another person to make those two people lovers, or you can shoot yourself to become lovers with that person!

Lovers are bound by their hearts. If one takes damage, the other will take damage too. If one dies, the other will soon die from shock.

If one lover is a traitor, the other non-traitor lover will help them as their current role. Love wins!

Once you have used up your crossbow, you will act as an ordinary innocent.]])

AddCustomExplanation(ROLE_NOVA,
[[You are an innocent about to blow. You'll explode at a random time. Unless you're killed, then you'll explode right away!

Avoid hanging near crowds of people if you don't want to lose a ton of karma!

If you suspect someone is a traitor and don't want to risk losing a gunfight to them, you can try sticking to them.]])

AddCustomExplanation(ROLE_SACRIFICE,
[[You are an innocent who is willing to trade their life for someone more important.

You have a special defib that can bring someone back to life, killing you in the process! Be sure to make the right choice!]])

AddCustomExplanation(ROLE_SEANCE,
[[You are an innocent that can see spirits - could the dead be trying to tell you something?

You will see yellow floating orbs around where dead players are spectating. If you see many orbs in one area, there's probably something interesting there!
You can try calling out to the spirits to have them relay information!

You can feel when someone has died. This can be useful information for your team if they haven't noticed yet.]])