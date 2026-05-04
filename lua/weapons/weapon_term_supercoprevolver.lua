-- nerf accuracy at range?
-- make sniping more last resort

AddCSLuaFile()

SWEP.PrintName = "O'l Reliable."
SWEP.Spawnable = false
SWEP.AdminOnly = true
SWEP.Author = "Straw W Wagen"
SWEP.Purpose = "Shoot without asking!"

SWEP.ViewModel = "models/weapons/v_357.mdl"
SWEP.WorldModel = "models/weapons/w_357.mdl"
SWEP.Weight = 11564674

if CLIENT then
    killicon.AddFont( "weapon_term_supercoprevolver", "HL2MPTypeDeath", ".", Color( 255, 80, 0 ) )
    language.Add( "weapon_term_supercoprevolver", SWEP.PrintName )

end

SWEP.terminator_IgnoreWeaponUtility = true

SWEP.Primary = {
    Ammo = "357",
    ClipSize = 6,
    DefaultClip = 6,
}

SWEP.Secondary = {
    Ammo = "None",
    ClipSize = -1,
    DefaultClip = -1,
}

function SWEP:Initialize()
    self:SetHoldType( "revolver" )

end

function SWEP:CanPrimaryAttack()
    return CurTime() >= self:GetNextPrimaryFire() and self:Clip1() > 0 and self:GetHoldType() == "revolver"

end

function SWEP:CanSecondaryAttack()
    return false
end

local bulletMissSounds = {
    "weapons/fx/nearmiss/bulletLtor03.wav",
    "weapons/fx/nearmiss/bulletLtor04.wav",
    "weapons/fx/nearmiss/bulletLtor06.wav",
    "weapons/fx/nearmiss/bulletLtor07.wav",
    "weapons/fx/nearmiss/bulletLtor09.wav",
    "weapons/fx/nearmiss/bulletLtor10.wav",
    "weapons/fx/nearmiss/bulletLtor13.wav",
    "weapons/fx/nearmiss/bulletLtor14.wav"
}

local function superCopWhizPly( ply, start, endPos )
    local nextWhiz = ply.supercop_NextBulletWhiz or 0
    if nextWhiz > CurTime() then return end

    local dist, nearestPoint = util.DistanceToLine( start, endPos, ply:GetShootPos() )
    if dist > 200 then return end
    ply.supercop_NextBulletWhiz = CurTime() + 0.1

    local pitchAdd = dist / 5

    for _ = 1, 2 do
        local theSound = bulletMissSounds[math.random( 1, #bulletMissSounds )]
        sound.Play( theSound, nearestPoint, 85, math.random( 40, 50 ) + pitchAdd, 1 )

    end

    util.ScreenShake( nearestPoint, 100, 20, 0.5, 1000, nil )

    return true
end

local function olReliableTrace( start, endPos )
    local tracerEffect = EffectData()
    tracerEffect:SetStart( start )
    tracerEffect:SetOrigin( endPos )
    tracerEffect:SetScale( 18000 ) -- fast
    tracerEffect:SetFlags( 0x0001 ) --whiz!
    util.Effect( "AirboatGunTracer", tracerEffect, true, true ) -- BIG effect

    if not util.DistanceToLine then return end
    for _, ply in ipairs( player.GetAll() ) do
        if superCopWhizPly( ply, start, endPos ) then return end

    end

    util.ScreenShake( start, 20, 20, 0.1, 500, true )
    util.ScreenShake( endPos, 20, 20, 0.1, 500, true )

end

-- COPIED FROM CFCm9kmonorepo
-- https://github.com/CFC-Servers/m9k_monorepo/blob/main/lua/weapons/bobs_gun_base/shared.lua

--[[---------------------------------------------------------
   Name: SWEP:BulletCallback()
   Desc: A convenience func to handle bullet callbacks.
-------------------------------------------------------]]
local maxIterations = 100

local penetrationDepth = 20

local penetrationDamageMult = {
    [MAT_CONCRETE] = 0.3,
    [MAT_METAL] = 0.3,
    [MAT_WOOD] = 0.8,
    [MAT_PLASTIC] = 0.8,
    [MAT_GLASS] = 0.8,
    [MAT_FLESH] = 0.9,
    [MAT_ALIENFLESH] = 0.9
}

local easyPenMaterials = {
    [MAT_GLASS] = true,
    [MAT_PLASTIC] = true,
    [MAT_WOOD] = true,
    [MAT_FLESH] = true,
    [MAT_ALIENFLESH] = true

}

local spreadVec = Vector( 0, 0, 0 )

function SWEP:BulletCallback( iteration, attacker, bulletTrace, dmginfo, direction )
    if CLIENT then return end
    if bulletTrace.HitSky then return end

    iteration = iteration and iteration + 1 or 0
    if iteration > maxIterations then return end

    direction = direction or bulletTrace.Normal

    terminator_Extras.Supercop_HandleDoor( self, bulletTrace )

    local penetrated = self:BulletPenetrate( iteration, attacker, bulletTrace, dmginfo, direction )
    if penetrated then return end

    local ricochet = self:BulletRicochet( iteration, attacker, bulletTrace, dmginfo, direction )
    if ricochet then return end

end

function SWEP:BulletPenetrate( iteration, attacker, bulletTrace, dmginfo, direction )
    local penDepth = penetrationDepth or 5
    local penDirection = direction * penDepth
    if easyPenMaterials[bulletTrace.MatType] then
        penDirection = direction * penDepth * 2
    end

    local hitEnt = bulletTrace.Entity
    local penTrace = nil

    for _ = 1, math.abs( iteration - maxIterations ) do
        penTrace = util.TraceLine( {
            endpos = bulletTrace.HitPos,
            start = bulletTrace.HitPos + penDirection,
            mask = MASK_SHOT,
            filter = function( ent )
                return ent == hitEnt
            end
        } )

        if penTrace.AllSolid and penTrace.HitWorld then continue end
        if not penTrace.Hit then continue end
        if penTrace.Fraction >= 0.99 or penTrace.Fraction <= 0.01 then continue end

    end

    if not penTrace then return end

    --debugoverlay.Line( bulletTrace.HitPos + penDirection, penTrace.HitPos, 10, Color( 255, 0, 0 ), true )

    --debugoverlay.Text( penTrace.HitPos, "Pen:" .. tostring( iteration ), 10 )
    local damageMult = penetrationDamageMult[penTrace.MatType] or 0.5
    local bullet = {
        Num = 1,
        Src = penTrace.HitPos,
        Dir = direction,
        Spread = spreadVec,
        Tracer = 1,
        TracerName = "m9k_effect_mad_penetration_trace_mod",
        Force = 5,
        Damage = dmginfo:GetDamage() * damageMult,
        Callback = function( a, b, c )
            if not IsValid( self ) then return end
            olReliableTrace( penTrace.HitPos, b.HitPos )
            self:BulletCallback( iteration, a, b, c, direction )
        end
    }

    timer.Simple( 0, function()
        if not IsValid( attacker ) then return end
        attacker:FireBullets( bullet )
    end )

    return true
end

function SWEP:BulletRicochet( iteration, attacker, bulletTrace, dmginfo, direction )
    if bulletTrace.MatType ~= MAT_METAL and math.random( 1, 100 ) < 50 then
        if self.Tracer == 0 or self.Tracer == 1 or self.Tracer == 2 then
            local effectdata = EffectData()
            effectdata:SetOrigin( bulletTrace.HitPos )
            effectdata:SetNormal( bulletTrace.HitNormal )
            effectdata:SetScale( 20 )
            util.Effect( "AR2Impact", effectdata )
        elseif self.Tracer == 3 then
            local effectdata = EffectData()
            effectdata:SetOrigin( bulletTrace.HitPos )
            effectdata:SetNormal( bulletTrace.HitNormal )
            effectdata:SetScale( 20 )
            util.Effect( "StunstickImpact", effectdata )
        end

        return false
    end

    local dotProduct = bulletTrace.HitNormal:Dot( direction * -1 )
    local bullet = {
        Num = 1,
        Src = bulletTrace.HitPos + bulletTrace.HitNormal,
        Dir = ( ( 2 * bulletTrace.HitNormal * dotProduct ) + direction ) + ( VectorRand() * 0.05 ),
        Spread = spreadVec,
        Tracer = SERVER and 1 or 0,
        TracerName = "m9k_effect_mad_ricochet_trace_mod",
        Force = dmginfo:GetDamage() * 0.15,
        Damage = dmginfo:GetDamage() * 0.5,
        Callback = function( a, b, c )
            if not IsValid( self ) then return end
            olReliableTrace( bulletTrace.HitPos + bulletTrace.HitNormal, b.HitPos )
            self:BulletCallback( iteration, a, b, c )

        end
    }

    --debugoverlay.Line( bulletTrace.HitPos, bulletTrace.HitPos + bullet.Dir * 100, 10, SERVER and Color( 255, 0, 0 ) or Color( 0, 255, 0 ), true )

    timer.Simple( 0, function()
        attacker:FireBullets( bullet )
    end )

    return true
end

local MAX_TRACE_LENGTH    = 56756
local vec3_origin        = vector_origin

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end

    local owner = self:GetOwner()
    local reallyMad = IsValid( owner ) and owner.IsReallyAngry and owner:IsReallyAngry()
    owner.SupercopBlockShooting = CurTime() + 1.5
    self:SetWeaponHoldType( "revolver" )

    local damageDealt = 5000
    if reallyMad then
        damageDealt = 5000000

    end

    owner:FireBullets( {
        Num = 1,
        Src = owner:GetShootPos(),
        Dir = owner:GetAimVector(),
        Spread = vec3_origin,
        Distance = MAX_TRACE_LENGTH,
        Damage = damageDealt,
        Tracer = 0,
        Force = damageDealt * 0.15,
        Attacker = owner,
        Callback = function( attacker, traceData, damageInfo )
            local muzzleDat = self:GetAttachment( self:LookupAttachment( "muzzle" ) )
            local startPos = muzzleDat and muzzleDat.Pos or self:WorldSpaceCenter() -- custom models? idk
            olReliableTrace( startPos, traceData.HitPos )
            self:BulletCallback( 0, attacker, traceData, damageInfo )

            local hitSomething = IsValid( traceData.Entity )
            local hitEnt = traceData.Entity
            local oldCount = traceData.Entity.supercopHitCounts or 0

            -- kill combine metallic npcs!
            if reallyMad and hitSomething and not hitEnt:IsPlayer() then
                damage = DamageInfo()
                damage:SetDamage( damageDealt )
                damage:SetDamageType( DMG_BLAST )
                damage:SetAttacker( owner )
                damage:SetInflictor( self )
                damage:SetDamagePosition( traceData.HitPos )
                hitEnt:TakeDamageInfo( damage )

                util.BlastDamage( self, owner, traceData.HitPos, 150, damageDealt )
                -- strider hack, they take severely reduced damage from non-players
                if hitEnt.Health and hitEnt:Health() > 1 then
                    hitEnt:SetHealth( 1 )

                end
                if oldCount >= 8 then
                    local fallbackSplode = ents.Create( "env_explosion" )
                    fallbackSplode:SetPos( traceData.HitPos )
                    fallbackSplode:SetKeyValue( "iMagnitude", damageDealt )
                    fallbackSplode:SetKeyValue( "iRadiusOverride", 300 )
                    fallbackSplode:Fire( "Explode" )

                end
            end
            if hitSomething and owner.GetEnemy and IsValid( owner:GetEnemy() ) and hitEnt == owner:GetEnemy() then
                if oldCount >= 3 then owner:ReallyAnger( 15 ) end

                hitEnt.supercopHitCounts = oldCount + 1

                if not owner:GetEnemy():IsPlayer() and oldCount > 25 then
                    owner.termIgnoreOverrides = owner.termIgnoreOverrides or {}
                    owner.termIgnoreOverrides[hitEnt] = true

                end
            end
        end
    } )

    self:DoMuzzleFlash()

    self:SetClip1( self:Clip1() - 1 )
    self:SetNextPrimaryFire( CurTime() + 0.74 )
    self:SetLastShootTime()

    if not SERVER then return end

    util.ScreenShake( owner:GetPos(), 5, 20, 0.25, 1000, true )
    util.ScreenShake( owner:GetPos(), 1, 20, 0.45, 4000, true )

    local filterAllPlayers = RecipientFilter()
    filterAllPlayers:AddAllPlayers()

    if owner.SuperGunSound then
        owner.SuperGunSound:Stop()

    end

    owner.SuperGunSound = CreateSound( owner, "Weapon_357.Single", filterAllPlayers )
    owner.SuperGunSound:PlayEx( 1, 88 )

    timer.Simple( 0.05, function()
        if not IsValid( self ) then return end
        if not IsValid( owner ) then return end
        -- ECHO!
        local superGunEcho = CreateSound( self, "Weapon_357.Single", filterAllPlayers )
        superGunEcho:SetDSP( 22 )
        superGunEcho:SetSoundLevel( 120 )
        superGunEcho:PlayEx( 0.6, math.Rand( 55, 60 ) )

        sound.EmitHint( SOUND_COMBAT, owner:GetShootPos(), 6000, 1, owner )

    end )
end

hook.Add( "terminator_blocktarget", "supercop_ignoreunkillables", function( supercop, target )
    local ignoreOverrides = supercop.termIgnoreOverrides
    if not ignoreOverrides then return end
    if ignoreOverrides[ target ] then return true end

end )

function SWEP:DoMuzzleFlash()
    if not SERVER then return end
    local muzzleDat = self:GetAttachment( self:LookupAttachment( "muzzle" ) )
    local ef = EffectData()
    ef:SetEntity( self )
    ef:SetOrigin( muzzleDat.Pos )
    ef:SetAngles( muzzleDat.Ang )
    ef:SetScale( 2 )
    util.Effect( "MuzzleEffect", ef, false )

end

if CLIENT then
    net.Receive( "weapon_term_supercoprevolver.muzzleflash", function( len )
        local ent = net.ReadEntity()

        if IsValid( ent ) and ent.DoMuzzleFlash then
            ent:DoMuzzleFlash()
        end
    end )
end

function SWEP:SecondaryAttack()
    if not self:CanSecondaryAttack() then return end
end

function SWEP:Equip()
end

function SWEP:OwnerChanged()
end

function SWEP:OnDrop()
end

function SWEP:Reload()
    self:SetClip1( self.Primary.ClipSize )
    self:SetNextPrimaryFire( CurTime() + 1.25 )

end

function SWEP:CanBePickedUpByNPCs()
    return true
end

function SWEP:GetNPCBulletSpread( prof )
    local base = 0
    local owner = self:GetOwner()
    if IsValid( owner ) and owner.GetEnemy and owner.SupercopMaxUnequipRevolverDist and owner.DistToEnemy > ( owner.SupercopMaxUnequipRevolverDist * 1.5 ) then
        base = 0.3

    end

    local spread = { base + 2, base + 1.5, base + 1, base + 0.5, base }
    return spread[ prof + 1 ]
end

function SWEP:GetNPCBurstSettings()
    return 1,1,1.5
end

function SWEP:GetNPCRestTimes()
    return 1.5,1.5
end

function SWEP:GetCapabilities()
    return CAP_WEAPON_RANGE_ATTACK1
end

function SWEP:DrawWorldModel()
    self:DrawModel()
end