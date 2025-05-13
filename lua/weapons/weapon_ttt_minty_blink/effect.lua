-- SPDX-License-Identifier: BSD-3-Clause

AddCSLuaFile()

local _m = {}

-- Functions
function _m.SpawnMimicRagdoll( player, position )
    if CLIENT then return nil end
    if not IsValid( player ) then return nil end

    local ragdoll = ents.Create( "prop_ragdoll" )
    if not IsValid( ragdoll ) then return nil end

    local origin = player:GetPos()

    -- Set variables
    ragdoll.Owner = player
    ragdoll:SetOwner( player )

    ragdoll:SetColor( Color( 255, 255, 255, 100 ) )
    ragdoll:SetModel( player:GetModel() )
    ragdoll:SetPos( position or origin )
    ragdoll:SetAngles( player:GetAngles() )

    ragdoll:SetCollisionGroup( COLLISION_GROUP_DEBRIS_TRIGGER )
    ragdoll:SetGravity( 0 )
    ragdoll:SetMaxHealth( 100 )
    ragdoll:SetHealth( 100 )
    
    -- Spawn ragdoll
    ragdoll:Spawn()
    ragdoll:Activate()

    -- Copy pose and freeze bones
    for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        local phys = ragdoll:GetPhysicsObjectNum( i )
        phys:Wake()

        if IsValid( phys ) then
            local pos, ang = player:GetBonePosition( player:TranslatePhysBoneToBone( i ) )

            phys:EnableGravity( false )

            if ( pos and ang ) then
                if position then
                    pos = pos + ( position - origin )
                end

                phys:SetPos( pos )
                phys:SetAngles( ang )
            end
        end

        phys:EnableMotion( false )
        timer.Simple( 0.1, function() if IsValid( phys ) then phys:Sleep() end end )
    end

    return ragdoll
end

function _m.Dissolve( player, position )
    if CLIENT then return false end
    if not IsValid( player ) then return false end

    -- Spawn and dissolve ragdoll
    local ragdoll = _m.SpawnMimicRagdoll( player, position )
    if not IsValid( ragdoll ) then return false end

    ragdoll:Dissolve( 3 )

    return true
end

function _m.FOV( player )
    if CLIENT then return false end
    if not IsValid( player ) then return false end

    local fov = player:GetFOV()
    player:SetFOV( fov * 1.5, 0 )
    player:SetFOV( fov, 0.25 )

    return true
end

function _m.Particles( emitter, count, radius, size, origin, velocity, origin_randomness, velocity_randomness, velocity_push_pull, phi )
    if SERVER then return end
    
    -- Defaults
    velocity = velocity or Vector( 0, 0, 0 )
    origin_randomness = origin_randomness or 0
    velocity_randomness = velocity_randomness or 0
    velocity_push_pull = velocity_push_pull or 0
    phi = phi or 0

    -- Particles
    for i = 1, count do
        local theta = 2.0 * math.pi * ( ( i - 1 ) / ( count - 1 ) )

        local x = math.sin( theta + phi ) * radius
        local y = math.cos( theta + phi ) * radius

        local particle = emitter:Add( "effects/spark", origin + Vector( x, y, 0 ) + VectorRand() * origin_randomness )

        if particle then
            particle:SetDieTime( 0.25 )

            particle:SetStartAlpha( 255 )
            particle:SetEndAlpha( 0 )

            particle:SetStartSize( size )
            particle:SetEndSize( 0 )

            particle:SetAngleVelocity( AngleRand() * 0.10 )
            particle:SetVelocity( velocity + Vector( x, y, 0 ) * velocity_push_pull + VectorRand() * velocity_randomness )
            
            local blueness = math.random( 0, 50 )
            particle:SetColor( 255 - blueness * 2, 255 - blueness, 255 )
        end
    end
end

function _m.Marker( player, rate, size )
    if SERVER then return end
    if ( player ~= LocalPlayer() and player ~= LocalPlayer():GetObserverTarget() ) then return end

    local weapon = player:GetActiveWeapon()
    if not IsValid( weapon ) then return end
    if not weapon.Timer or not weapon.Warp then return end
    if not weapon.Timer.Particle then weapon.Timer.Particle = 0 end

    if ( CurTime() - weapon.Timer.Particle ) < rate then return end

    local emitter = weapon.Emitter
    if not IsValid( emitter ) then return end

    local marker = weapon.Warp.Marker
    local target = weapon.Warp.Target
    if not marker or not target then return end

    local direction = ( target - marker ):GetNormalized()

    local up = Vector( 0, 0, 1 )
    local phi = 2.0 * math.pi * CurTime()

    -- Reticle
    _m.Particles( emitter, 2, 0, size, marker, direction * 250, 2.5, 1.25 )

    -- Ground cone
    _m.Particles( emitter, 8, size * 2, size, target, up * 50, 2.5, 50, -5, -phi )

    -- Ground splat
    _m.Particles( emitter, 6, size * 0.375, size, target, up * -50, 2.5, 5, 50, phi )

    -- Column
    _m.Particles( emitter, 4, size, size, target, up * 250, 2.5, 5, 0, phi * 2 )

    -- Reset timer
    weapon.Timer.Particle = CurTime()
end

return _m