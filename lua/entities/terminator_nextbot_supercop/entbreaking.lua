
if not terminator_Extras then return end

local function LockBustSound( ent )
    ent:EmitSound( "doors/vent_open1.wav", 100, 80, 1, CHAN_STATIC )
    ent:EmitSound( "physics/metal/metal_solid_strain3.wav", 100, 200, 1, CHAN_STATIC )

end

local function SparkEffect( SparkPos )
    timer.Simple( 0, function() -- wow wouldnt it be cool if effects worked on the first tick personally i think that would be really cool
        local Sparks = EffectData()
        Sparks:SetOrigin( SparkPos )
        Sparks:SetMagnitude( 2 )
        Sparks:SetScale( 1 )
        Sparks:SetRadius( 6 )
        util.Effect( "Sparks", Sparks )

    end )

end

local function ModelBoundSparks( ent )
    local randpos = ent:WorldSpaceCenter() + VectorRand() * ent:GetModelRadius()
    randpos = ent:NearestPoint( randpos )

    -- move them a bit in from the exact edges of the model
    randpos = ent:WorldToLocal( randpos )
    randpos = randpos * 0.8
    randpos = ent:LocalToWorld( randpos )

    SparkEffect( randpos )

end

local lockOffset = Vector( 0, 42.6, -10 )

local slidingDoors = {
    ["func_movelinear"] = true,
    ["func_door"] = true,

}

function terminator_Extras.Supercop_HandleDoor( maker, tr )
    if CLIENT or not IsValid( tr.Entity ) then return end
    local door = tr.Entity
    if door.realDoor then
        door = door.realDoor

    end
    local owner = maker:GetOwner()
    local class = door:GetClass()

    -- let nails do their thing
    if door.huntersglee_breakablenails then return end

    local doorsLocked = door:GetInternalVariable( "m_bLocked" ) == true

    local doorsObj = door:GetPhysicsObject()
    local isProperDoor = class == "prop_door_rotating"
    local isSlidingDoor = slidingDoors[class]
    local isBashableSlidDoor
    if isSlidingDoor then
        isBashableSlidDoor = doorsObj:GetVolume() < 48880 -- magic number! 10x mass of doors on terrortrain

    end

    if isSlidingDoor and doorsLocked then
        local lockHealth = door.terminator_lockHealth
        if not door.terminator_lockHealth then
            local initialHealth = 200
            if doorsObj and doorsObj:IsValid() then
                initialHealth = math.max( initialHealth, doorsObj:GetVolume() / 1250 )

            end
            lockHealth = initialHealth
            door.terminator_lockMaxHealth = initialHealth

        end

        local lockDamage = 200

        lockHealth = lockHealth + -lockDamage

        if lockHealth <= 0 then
            lockHealth = nil
            door:Fire( "unlock", "", .01 )
            terminator_Extras.DoorHitSound( door )
            LockBustSound( door )

            util.ScreenShake( owner:GetPos(), 80, 10, 1, 1500 )

            for _ = 1, 20 do
                ModelBoundSparks( door )

            end

        else
            terminator_Extras.DoorHitSound( door )
            if lockHealth < door.terminator_lockMaxHealth * 0.45 then
                ModelBoundSparks( door )
                util.ScreenShake( owner:GetPos(), 10, 10, 0.5, 600 )
                local pitch = math.random( 175, 200 ) + math.Clamp( -lockHealth, -100, 0 )
                door:EmitSound( "physics/metal/metal_box_break1.wav", 90, pitch, 1, CHAN_STATIC )

            end
        end

        door.terminator_lockHealth = lockHealth

    elseif class == "func_door_rotating" or isProperDoor or isBashableSlidDoor then

        if terminator_Extras.CanBashDoor( door ) == false then
            terminator_Extras.DoorHitSound( door )

        else
            terminator_Extras.DehingeDoor( maker, door, true )

            if doorsLocked and isProperDoor then
                SparkEffect( door:GetPos() + -lockOffset )
                LockBustSound( door )

            end
        end
    end
end