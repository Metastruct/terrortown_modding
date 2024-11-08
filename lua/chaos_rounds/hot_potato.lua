local ROUND = {}
ROUND.Name = "Hot Potato"
ROUND.Description = "Someone starts with a ticking bomb. Pass it to others (melee only) before it explodes! Last survivor wins."

-- Configuration
local BOMB_TIMER = 60 -- Initial time before explosion
local TIMER_REDUCTION = 3 -- Seconds reduced from timer on each pass
local MIN_TIMER = 10 -- Minimum seconds before explosion
local EXPLOSION_RADIUS = 300 -- Units for explosion radius

if SERVER then
    util.AddNetworkString("TTT_HotPotato_Holder")
    util.AddNetworkString("TTT_HotPotato_Explosion")

    function ROUND:Start()
        -- Select random initial player
        local players = player.GetHumans()
        local initial_holder = players[math.random(#players)]
        self.current_holder = initial_holder
        self.time_left = BOMB_TIMER
        self.passes = 0

        -- Give bomb to initial player
        net.Start("TTT_HotPotato_Holder")
        net.WriteEntity(initial_holder)
        net.WriteFloat(self.time_left)
        net.Broadcast()

        -- Start countdown timer
        timer.Create("HotPotatoTimer", 1, 0, function()
            self.time_left = self.time_left - 1

            if self.time_left <= 0 then
                self:ExplodeBomb()
            end
        end)

        -- Hook player damage to handle bomb passing
        hook.Add("EntityTakeDamage", "HotPotatoPass", function(target, dmg)
            if not IsValid(target) or not target:IsPlayer() then return end

            local attacker = dmg:GetAttacker()
            if not IsValid(attacker) or not attacker:IsPlayer() then return end
            -- Only allow passing via melee
            if dmg:GetDamageType() ~= DMG_CLUB then return end

            -- Check if attacker is current holder
            if attacker == self.current_holder then
                self:PassBomb(target)
                dmg:SetDamage(0)
            end
        end)
    end

    function ROUND:PassBomb(new_holder, reinitialize_timer)
        -- Update holder
        self.current_holder = new_holder
        self.passes = self.passes + 1
        -- Reduce timer
        self.time_left = reinitialize_timer and BOMB_TIMER / 2 or math.max(MIN_TIMER, self.time_left - TIMER_REDUCTION)

        -- Notify clients
        net.Start("TTT_HotPotato_Holder")
        net.WriteEntity(new_holder)
        net.WriteFloat(self.time_left)
        net.Broadcast()
        -- Play pass sound
        new_holder:EmitSound("weapons/c4/c4_beep1.wav")
    end

    function ROUND:ExplodeBomb()
        if not IsValid(self.current_holder) then return end
        -- Create explosion effect
        local explosion = ents.Create("env_explosion")
        explosion:SetPos(self.current_holder:GetPos())
        explosion:SetOwner(self.current_holder)
        explosion:Spawn()
        explosion:SetKeyValue("iMagnitude", "100")
        explosion:Fire("Explode", 0, 0)

        -- Kill holder and nearby players
        for _, ply in ipairs(player.GetAll()) do
            if ply:GetPos():Distance(self.current_holder:GetPos()) <= EXPLOSION_RADIUS then
                ply:Kill()
            end
        end

        -- Notify clients
        net.Start("TTT_HotPotato_Explosion")
        net.WriteVector(self.current_holder:GetPos())
        net.Broadcast()

        -- Check for round end
        local alive = 0
        for _, ply in ipairs(player.GetAll()) do
            if ply:IsTerror() then
                alive = alive + 1
            end
        end

        if alive <= 1 then
            timer.Remove("HotPotatoTimer")
        else
            -- Select new random holder if players remain
            local players = {}
            for _, ply in ipairs(player.GetAll()) do
                if ply:IsTerror() then
                    table.insert(players, ply)
                end
            end

            self:PassBomb(players[math.random(#players)], true)
        end
    end

    function ROUND:Finish()
        timer.Remove("HotPotatoTimer")
        hook.Remove("EntityTakeDamage", "HotPotatoPass")
    end
end

if CLIENT then
    local bomb_holder = nil
    local time_left = 0
    local time_ms = 0  -- Add millisecond tracking

    net.Receive("TTT_HotPotato_Holder", function()
        bomb_holder = net.ReadEntity()
        time_left = net.ReadFloat()
        time_ms = time_left * 1000  -- Convert to milliseconds
    end)

    -- Replace the old timer with a more precise one
    timer.Create("HotPotatoTimer", 0.05, 0, function()  -- Run every 50ms
        time_ms = math.max(0, time_ms - 50)
        time_left = math.ceil(time_ms / 1000)
    end)

    net.Receive("TTT_HotPotato_Explosion", function()
        local pos = net.ReadVector()
        -- Add explosion effects
        local effect = EffectData()
        effect:SetOrigin(pos)
        util.Effect("Explosion", effect)
    end)

    function ROUND:Start()
        hook.Add("HUDPaint", "HotPotatoHUD", function()
            if not IsValid(bomb_holder) then return end

            -- Draw red square with timer for bomb holder
            if bomb_holder == LocalPlayer() then
                local screenW, screenH = ScrW(), ScrH()
                local timerText = string.format("TICK TOCK... %.1f SECONDS LEFT!", time_ms / 1000)  -- Show one decimal place

                surface.SetFont("DermaLarge")
                local textW, textH = surface.GetTextSize(timerText)
                local textX, textY = screenW / 2, screenH / 3

                local padding = 10
                local boxW, boxH = textW + padding * 2, textH + padding * 2
                local boxX = textX - boxW / 2
                local boxY = textY - boxH / 2

                surface.SetDrawColor(0, 0, 0, 200)
                surface.DrawRect(boxX, boxY, boxW, boxH)
                surface.SetDrawColor(255, 0, 0, 255)
                surface.DrawOutlinedRect(boxX, boxY, boxW, boxH, 2)

                draw.SimpleText(timerText, "DermaLarge", textX, textY, Color(255, 0, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            else
                -- Draw holder indicator with timer
                if bomb_holder:Alive() then
                    local pos = bomb_holder:WorldSpaceCenter()
                    local screenPos = pos:ToScreen()
                    local text = string.format("BOMB [%.1fs]", time_ms / 1000)  -- Show one decimal place
                    draw.SimpleText(text, "DermaLarge", screenPos.x, screenPos.y, Color(255, 0, 0), TEXT_ALIGN_CENTER)
                end
            end
        end)
    end

    function ROUND:Finish()
        hook.Remove("HUDPaint", "HotPotatoHUD")
        bomb_holder = nil
    end
end

return ROUND