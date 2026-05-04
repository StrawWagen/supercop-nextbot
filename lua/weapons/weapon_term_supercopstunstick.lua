AddCSLuaFile()

SWEP.PrintName = "Arm of the law."
SWEP.Spawnable = false
SWEP.AdminOnly = true
SWEP.Author = "Straw W Wagen"
SWEP.Purpose = "It's nuclear powered!"

SWEP.ViewModel = "models/weapons/v_stunbaton.mdl"
SWEP.WorldModel = "models/weapons/w_stunbaton.mdl"
SWEP.Weight = 3214214

if CLIENT then
    killicon.AddFont( "weapon_term_supercopstunstick", "HL2MPTypeDeath", "!", Color( 255, 80, 0 ) )
    language.Add( "weapon_term_supercopstunstick", SWEP.PrintName )
end

SWEP.Melee = true
SWEP.Range = 75
SWEP.HitMask = MASK_SOLID

SWEP.terminator_IgnoreWeaponUtility = true

local function LockBustSound( ent )
    ent:EmitSound( "doors/vent_open1.wav", 100, 80, 1, CHAN_STATIC )
    ent:EmitSound( "physics/metal/metal_solid_strain3.wav", 100, 200, 1, CHAN_STATIC )

end

local function SparkEffect( SparkPos )
    local Sparks = EffectData()
    Sparks:SetOrigin( SparkPos )
    Sparks:SetMagnitude( 2 )
    Sparks:SetScale( 1 )
    Sparks:SetRadius( 6 )
    util.Effect( "Sparks", Sparks )

end

function SWEP:StickEffect( effectPos, normal, scale )
    local effect = EffectData()
    effect:SetOrigin( effectPos )
    effect:SetScale( 1 * scale )
    effect:SetNormal( normal )
    util.Effect( "StunstickImpact", effect )

end

function SWEP:Initialize()
    self:SetHoldType( "melee" )

end

function SWEP:CanPrimaryAttack()
    return CurTime() >= self:GetNextPrimaryFire()
end

function SWEP:CanSecondaryAttack()
    return false
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end

    self:SetNextPrimaryFire( CurTime() + 0.25 )
    self:SetLastShootTime()

    if not SERVER then return end

    local owner = self:GetOwner()

    owner:EmitSound( "Weapon_StunStick.Swing", 100, math.random( 80, 90 ), 1, CHAN_STATIC, bit.bor( SND_CHANGE_PITCH, SND_CHANGE_VOL ) )

    timer.Simple( 0.15, function()
        if not IsValid( self ) then return end
        self:DoDamage()

    end )

end

local damageHull = Vector( 10, 10, 8 )
local lockOffset = Vector( 0, 42.6, -10 )

function SWEP:DoDamage()
    if not SERVER then return end
    local owner = self:GetOwner()
    if not IsValid( owner ) then return end

    util.ScreenShake( self:GetOwner():GetPos(), 10, 1, 0.4, 400 ) -- strong for nearby
    util.ScreenShake( self:GetOwner():GetPos(), 0.5, 1, 2, 3000 ) -- weak for far away

    local tr = util.TraceLine( {
        start = owner:GetShootPos(),
        endpos = owner:GetShootPos() + owner:GetAimVector() * self.Range,
        filter = owner,
        mask = bit.bor( self.HitMask ),
    } )

    if not IsValid( tr.Entity ) then
        tr = util.TraceHull( {
            start = owner:GetShootPos(),
            endpos = owner:GetShootPos() + owner:GetAimVector() * self.Range,
            filter = owner,
            maxs = damageHull,
            mins = -damageHull,
            mask = bit.bor( self.HitMask ),
        } )
    end
    if tr.Hit then

        terminator_Extras.Supercop_HandleDoor( self, tr )
        local reallyMad = IsValid( owner ) and owner.IsReallyAngry and owner:IsReallyAngry()

        local hitEnt = tr.Entity

        local dmg = DamageInfo()
        dmg:SetDamageForce( owner:GetAimVector() * 150000 )
        dmg:SetDamagePosition( tr.HitPos )
        if reallyMad then
            dmg:SetDamageType( DMG_BLAST )

        else
            dmg:SetDamageType( DMG_SHOCK )

        end

        dmg:SetAttacker( owner )
        dmg:SetInflictor( self )

        -- bypass godmode...
        if hitEnt.HasGodMode and hitEnt:HasGodMode() then
            dmg:SetDamageType( DMG_SHOCK )
            hitEnt:GodDisable()

            dmg:SetDamage( hitEnt:GetMaxHealth() * math.Rand( 0.01, 0.1 ) )
            hitEnt:TakeDamageInfo( dmg )
            hitEnt:GodEnable()

        else
            dmg:SetDamage( 150000 )
            hitEnt:TakeDamageInfo( dmg )

        end

        -- lazy pngbot
        if hitEnt.LastPathingInfraction and hitEnt.TauntSounds then
            hitEnt:OnKilled( dmg )
            SafeRemoveEntity( hitEnt )

        end

        self:StickEffect( tr.HitPos, tr.HitNormal, 1 )

        util.ScreenShake( owner:GetPos(), 80, 20, 0.5, 1000, true )
        util.ScreenShake( owner:GetPos(), 5, 20, 1, 3000, true )

        if hitEnt:GetInternalVariable( "m_bLocked" ) == true then
            hitEnt:Fire( "unlock", "", .01 )
            SparkEffect( hitEnt:GetPos() + -lockOffset )
            LockBustSound( hitEnt )

        end

        local filterAllPlayers = RecipientFilter()
        filterAllPlayers:AddAllPlayers()

        if owner.stunStickSound then
            owner.stunStickSound:Stop()

        end

        owner.stunStickSound = CreateSound( owner, "Weapon_StunStick.Melee_Hit", filterAllPlayers )
        owner.stunStickSound:SetSoundLevel( 95 )
        owner.stunStickSound:PlayEx( 1, 88 )

        timer.Simple( 0.05, function()
            if not IsValid( self ) then return end
            if not IsValid( owner ) then return end
            -- ECHO!
            local stunStickEcho = CreateSound( self, "Weapon_StunStick.Melee_Hit", filterAllPlayers )
            stunStickEcho:SetDSP( 22 )
            stunStickEcho:SetSoundLevel( 100 )
            stunStickEcho:PlayEx( 0.6, math.Rand( 55, 60 ) )

            sound.EmitHint( SOUND_COMBAT, owner:GetShootPos(), 4000, 1, owner )
        end )
        if IsValid( hitEnt ) then
            local phys = hitEnt:GetPhysicsObject()
            local punchForce = owner:GetAimVector()
            if IsValid( phys ) then
                punchForce = punchForce * math.Clamp( phys:GetMass() / 500, 0.25, 1 )
                punchForce = punchForce * 100000
                phys:ApplyForceOffset( punchForce, tr.HitPos )

            end
        end
        if hitEnt:IsPlayer() or hitEnt:IsNPC() or hitEnt:IsNextBot() then
            hitEnt:EmitSound( "npc/vort/foot_hit.wav", 75, math.random( 45, 65 ), 1, CHAN_STATIC )

        end
    else
        owner:EmitSound( "weapons/slam/throw.wav", 100, math.random( 40, 50 ), 0.65, CHAN_STATIC )

    end

    util.ScreenShake( owner:GetPos(), 2.5, 10, 0.45, 4000, true )

end

function SWEP:SecondaryAttack()
    if not self:CanSecondaryAttack() then return end
end

function SWEP:Equip()
    if not SERVER then return end
    self:GetOwner():EmitSound( "Weapon_StunStick.Activate" )
    local attachments = self:GetOwner():GetAttachments()
    local rHandId
    for _, attach in ipairs( attachments ) do
        if attach.name ~= "RHand" then continue end
        rHandId = attach.id

    end
    if not rHandId then return end
    local pos = self:GetOwner():GetAttachment( rHandId ).Pos
    self:StickEffect( pos, VectorRand(), 0.25 )

end

function SWEP:OwnerChanged()
end

function SWEP:OnDrop()
end

function SWEP:Reload()
    self:SetClip1( self.Primary.ClipSize )
end

function SWEP:CanBePickedUpByNPCs()
    return true
end

function SWEP:GetNPCBulletSpread( prof )
    local spread = { 3, 2.5, 2, 1.5, 1 }
    return spread[ prof + 1 ]
end

function SWEP:GetNPCBurstSettings()
    return 1,1,0.75
end

function SWEP:GetNPCRestTimes()

    local owner = self:GetOwner()

    local reallyMad = IsValid( owner ) and owner.IsReallyAngry and owner:IsReallyAngry()
    local maxTime = 1
    local minTime = 0.75
    if reallyMad then
        maxTime = 0.6
        minTime = 0.5

    end

    return minTime, maxTime
end

function SWEP:GetCapabilities()
    return CAP_WEAPON_MELEE_ATTACK1
end

function SWEP:DrawWorldModel()
    self:DrawModel()
end