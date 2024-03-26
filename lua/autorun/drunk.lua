if SERVER then
	AddCSLuaFile()
	util.AddNetworkString("drunkfactor")

	local random_words = {"meme", "boi", "who is", "are you", "i never", "please", "door stuck", "dick", "cock", "pussy", "fuck", "fucking", "oh shit", "my shit", "balls", "bitches", "faggot", "wtf", "porno", "um", "uh", "hmm", "mmm", "haha", "okay", "no i", "i mean", "wait", "i love you", "im gay", "what", "girls", "admin", "yay", ":)", "XD", "!!!!!", "???", "orgasm", "anime", "hentai", "little girls", "spaghetti", "dildo", "hax", "meatspin", "squadilah", "spaghetti"}

	local function DrunkText(text, factor)
		-- drunk?
		if factor <= 10 then return end
		-- blow up our chat into words.
		local words = string.Explode(" ", text)

		if factor > 20 then
			-- swap out some words.
			local amt = math.Clamp((#words / 3) * (factor / 100), 1, 10)

			for i = 1, amt do
				local a = math.random(1, #words)
				local b = math.random(1, #words)
				local aword = words[a]
				local bword = words[b]
				words[a] = bword
				words[b] = aword
			end
		end

		if factor > 35 then
			-- inject words
			local amt = math.Clamp((#words / 6) * (factor / 100), 1, 10)

			for i = 1, amt do
				local num = math.random(1, #random_words)
				local pos = math.random(1, #words)
				local word = random_words[num]
				table.insert(words, pos, word)
			end
		end

		-- letters we want to slur.
		local letters = {'a', 'e', 'i', 'o', 'u', 'y', 'z', 's', 'h', 'A', 'E', 'I', 'O', 'U', 'Y', 'Z', 'S', 'H'}

		-- slur!SLURRRR!
		for i = 1, #words do
			local word = words[i]
			--local j

			for j = 1, string.len(word) do
				local letter = string.sub(word, j, j)

				if table.HasValue(letters, letter) and math.random(3) == 1 then
					local slur = math.ceil((factor / 100) * math.random(2, 5))
					local first = string.sub(word, 1, j - 1)
					local last = string.sub(word, j + 1)
					word = first .. string.rep(letter, slur) .. last
				end
			end

			words[i] = word
		end

		return table.concat(words, " ")
	end

	hook.Add("Think", "BeerThink", function()
		if math.random(10) == 1 then
			for key, ply in pairs(player.GetAll()) do
				ply.drunkfactor = ply.drunkfactor or 0
				local invert = math.Clamp(ply.drunkfactor * -1 + 100, 1, 100)

				if math.random(invert + 20) == 1 then
					if ply.drunkfactor >= 50 then
						ply:Puke()
					end

					ply.drunkfactor = math.max(ply.drunkfactor - 5, 0)
					ply:SetDrunkFactor(ply.drunkfactor)
				end
			end
		end
	end)

	local PLAYER = FindMetaTable("Player")

	function PLAYER:SetDrunkFactor(factor)
		self.drunkfactor = factor

		net.Start("drunkfactor")
		net.WriteInt(factor, 32)
		net.Send(self)
	end

	function PLAYER:GetDrunkFactor()
		return self.drunkfactor
	end

	hook.Add("PlayerSay", "BeerSay", function(ply, text)
		ply.drunkfactor = ply.drunkfactor or 0

		return DrunkText(text, math.min(ply.drunkfactor, 500))
	end)
end

if CLIENT then
	local factor = 0
	local smooth = Vector(0, 0, 0)

	net.Receive("drunkfactor", function()
		factor = net.ReadInt(32)
		smooth = Vector(0, 0, 0)
	end)

	hook.Add("RenderScreenspaceEffects", "beer.RenderScreenspaceEffects", function()
		if factor <= 0 then return end

		local fdec = factor / 100
		local params = {}
		params["$pp_colour_addr"] = 18 * 0.02 * math.min(fdec, 3)
		params["$pp_colour_addg"] = 18 * 0.02 * math.min(fdec, 3)
		params["$pp_colour_addb"] = 0
		params["$pp_colour_brightness"] = -0.2 * math.min(fdec, 3)
		params["$pp_colour_contrast"] = 1
		params["$pp_colour_colour"] = 1 - math.min(0.2 * fdec, 1.2)
		params["$pp_colour_mulr"] = 0
		params["$pp_colour_mulg"] = 0
		params["$pp_colour_mulb"] = 0

		DrawBloom(0.4 * fdec, 3.39 * fdec, 11.21, 9, 2, 1.96, 37 / 255, 48 / 255, 0)
		DrawColorModify(params)
		DrawMotionBlur(0.1, 1 * fdec, 0)
		DrawSharpen(5 * fdec, 0.2)
	end)

	hook.Add("CreateMove", "beer.CreateMove", function(ucmd)
		if factor > 0 then
			local random = VectorRand() * 0.1 * (factor / 100)
			smooth = smooth + ((random - smooth) * 0.0005)
			ucmd:SetViewAngles((ucmd:GetViewAngles():Forward() + smooth):Angle())
			ucmd:SetForwardMove(ucmd:GetForwardMove() + smooth.y * 100000)
			ucmd:SetSideMove(ucmd:GetSideMove() + smooth.x * 100000)
		end
	end)
end