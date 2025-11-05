-- DOES NOT SHOOT THRU FENCES!

AddCSLuaFile()

ENT.Base = "terminator_nextbot"
DEFINE_BASECLASS( ENT.Base )
ENT.PrintName = "The Supercop"
ENT.Spawnable = false
ENT.AdminOnly = true
list.Set( "NPC", "terminator_nextbot_supercop", {
    Name = "The Supercop",
    Class = "terminator_nextbot_supercop",
    Category = "Terminator Nextbot",
    AdminOnly = true,
} )

if CLIENT then
    language.Add( "terminator_nextbot_supercop", ENT.PrintName )

    local supercopsColor = Vector( 0.1, 0.1, 0.1 )
    --https://github.com/Facepunch/garrysmod/blob/master/garrysmod/lua/matproxy/player_color.lua
    function ENT:GetPlayerColor()
        return supercopsColor

    end

    return

else
    include( "entbreaking.lua" )

end

ENT.JumpHeight = 80
ENT.DefaultStepHeight = 18
ENT.StandingStepHeight = ENT.DefaultStepHeight * 1 -- used in crouch toggle in motionoverrides
ENT.CrouchingStepHeight = ENT.DefaultStepHeight * 0.9
ENT.StepHeight = ENT.StandingStepHeight
ENT.PathGoalToleranceFinal = 35
ENT.SpawnHealth = 5000000
ENT.WalkSpeed = 50
ENT.RunSpeed = 85
ENT.AccelerationSpeed = 1000
ENT.DeathDropHeight = 2000
ENT.InformRadius = 0

-- default is 500, setting this lower means supercop will ignore low priority enemies and focus on players, unless they're blocking his path
ENT.CloseEnemyDistance = 0
ENT.SupercopOnDamagedEnemyDistance = 65

ENT.DoMetallicDamage = true -- metallic fx like bullet ricochet sounds
ENT.MetallicMoveSounds = false
ENT.ReallyStrong = true
ENT.ReallyHeavy = true
ENT.DontDropPrimary = true

ENT.LookAheadOnlyWhenBlocked = true
ENT.alwaysManiac = true -- always create feuds between us and other terms/supercops, when they damage us
ENT.IsTerminatorSupercop = true

ENT.CanSpeak = true
ENT.ReallyStuckNeverRemove = true

local SUPERCOP_MODEL = "models/player/police.mdl"
ENT.ARNOLD_MODEL = SUPERCOP_MODEL

if not SERVER then return end

ENT.PhysgunDisabled = true
function ENT:CanProperty()
    return false

end
function ENT:CanTool()
    return false

end

ENT.FootstepClomping = false

ENT.Term_FootstepTiming = "perfect"
-- ENT.PerfectFootsteps_Up = Vector( 0, 0, 1 ) -- comment these out since the defaults are based on us
-- ENT.PerfectFootsteps_SteppingCriteria = 0.8
ENT.PerfectFootsteps_FeetBones = { "ValveBiped.Bip01_L_Foot", "ValveBiped.Bip01_R_Foot" } -- feet bones that match our model
ENT.Term_FootstepIgnorePAS = true

ENT.Term_FootstepMode = "custom"
ENT.Term_FootstepSound = {
    {
        path = "NPC_MetroPolice.RunFootstepLeft",
        lvl = 88,
        pitch = { 80, 90 },
        volume = 1,
        chan = CHAN_STATIC,
    },
    {
        path = "NPC_MetroPolice.RunFootstepRight",
        lvl = 88,
        pitch = { 80, 90 },
        volume = 1,
        chan = CHAN_STATIC,
    }
}
ENT.Term_FootstepShake = {
    amplitude = 1,
    frequency = 20,
    duration = 0.5,
    radius = 1500,
}

CreateConVar( "supercop_nextbot_forcedmodel", SUPERCOP_MODEL, bit.bor( FCVAR_ARCHIVE ), "Override the supercop nextbot's spawned-in model. Model needs to be rigged for player movement" )

local function supercopModel()
    local convar = GetConVar( "supercop_nextbot_forcedmodel" )
    local model = SUPERCOP_MODEL
    if convar then
        local varModel = convar:GetString()
        if varModel and util.IsValidModel( varModel ) then
            model = varModel

        end
    end
    return model

end

if not supercopModel() then
    RunConsoleCommand( "supercop_nextbot_forcedmodel", SUPERCOP_MODEL )

end

ENT.Models = { SUPERCOP_MODEL }

local function hitEffect( hitPos, scale )
    local effect = EffectData()
    effect:SetOrigin( hitPos )
    effect:SetMagnitude( 2 * scale )
    effect:SetScale( 1 )
    effect:SetRadius( 6 * scale )
    util.Effect( "Sparks", effect )

end

local rics = {
    "weapons/fx/rics/ric3.wav",
    "weapons/fx/rics/ric5.wav",

}

local function doRicsEnt( shotEnt )
    shotEnt:EmitSound( table.Random( rics ), 75, math.random( 92, 100 ), 1, CHAN_AUTO )

end
local function blockDamage( damaged, _, damageInfo )
    if not damaged.IsTerminatorSupercop then return end

    damaged:Anger( damageInfo:GetDamage() * 0.1 )
    local increased = damaged.SupercopEquipRevolverDist + ( damaged.EquipDistRampup / 4 )
    increased = math.Clamp( increased, 0, damaged.SupercopMaxUnequipRevolverDist + -250 )
    damaged.SupercopEquipRevolverDist = increased

    local attacker = damageInfo:GetAttacker()

    if IsValid( attacker ) and attacker ~= damaged and attacker:GetClass() == damaged:GetClass() then
        damageInfo:ScaleDamage( 2 )

    else
        damageInfo:ScaleDamage( 0 )

    end

    damaged:MakeFeud( attacker )

    damaged.CloseEnemyDistance = damaged.SupercopOnDamagedEnemyDistance
    local timerName = "supercop_fixcloseenemydist" .. damaged:GetCreationID()
    timer.Remove( timerName )
    timer.Create( timerName, 5, 1, function()
        if not IsValid( damaged ) then return end
        damaged.CloseEnemyDistance = 0

    end )

    if not damageInfo:IsBulletDamage() then return end
    doRicsEnt( damaged )
    hitEffect( damageInfo:GetDamagePosition(), 0.25 )

end

hook.Add( "ScaleNPCDamage", "supercop_nextbot_blockdamage", blockDamage )

function ENT:OnTakeDamage( damageInfo )
    blockDamage( self, nil, damageInfo )

end

-- does not flinch
function ENT:HandleFlinching()
end

local spottedEnemy = {
    "METROPOLICE_MOVE_ALONG_A0",
    "METROPOLICE_BACK_UP_A0",
    "METROPOLICE_BACK_UP_B0",
    "METROPOLICE_BACK_UP_C0",
    "METROPOLICE_IDLE_HARASS_PLAYER2",

}

local approachingEnemyVisible = {
    "METROPOLICE_IDLE_HARASS_PLAYER0",
    "METROPOLICE_IDLE_HARASS_PLAYER1",
    "METROPOLICE_IDLE_HARASS_PLAYER3",
    "METROPOLICE_IDLE_HARASS_PLAYER4",

    "METROPOLICE_MOVE_ALONG_A1",
    "METROPOLICE_MOVE_ALONG_A2",

    "METROPOLICE_MOVE_ALONG_B1",

    "METROPOLICE_MOVE_ALONG_C1",
    "METROPOLICE_MOVE_ALONG_C2",
    "METROPOLICE_MOVE_ALONG_C3",

    "METROPOLICE_BACK_UP_A1",
    "METROPOLICE_BACK_UP_A2",

    "METROPOLICE_BACK_UP_B1",

    "METROPOLICE_BACK_UP_C1",
    "METROPOLICE_BACK_UP_C3",

}

local weaponWarn = {
    "METROPOLICE_BACK_UP_C3",
    "METROPOLICE_MOVE_ALONG_C0",
    "METROPOLICE_MOVE_ALONG_C3",
    "METROPOLICE_BACK_UP_C4",
    "METROPOLICE_MONST_CITIZENS0",
    "METROPOLICE_HIT_BY_PHYSOBJECT2",
    "METROPOLICE_HIT_BY_PHYSOBJECT3",
    "METROPOLICE_HIT_BY_PHYSOBJECT4",

    "METROPOLICE_FREEZE0",
    "METROPOLICE_FREEZE1",

}

local approachingEnemyObscured = {
    "METROPOLICE_LOST_LONG0",
    "METROPOLICE_LOST_LONG1",
    "METROPOLICE_LOST_LONG2",
    "METROPOLICE_LOST_LONG3",
    "METROPOLICE_LOST_LONG4",
    "METROPOLICE_LOST_LONG5",

}

local playerDead = {
    "METROPOLICE_MOVE_ALONG_B0",

    "METROPOLICE_KILL_PLAYER0",
    "METROPOLICE_KILL_PLAYER1",
    "METROPOLICE_KILL_PLAYER2",
    "METROPOLICE_KILL_PLAYER3",
    "METROPOLICE_KILL_PLAYER4",
    "METROPOLICE_KILL_PLAYER5",

    "METROPOLICE_KILL_CITIZENS0",
    "METROPOLICE_KILL_CITIZENS1",
    "METROPOLICE_KILL_CITIZENS2",
    "METROPOLICE_KILL_CITIZENS3",

    "METROPOLICE_PLAYERHIT1",
    "METROPOLICE_PLAYERHIT2",
    "METROPOLICE_PLAYERHIT3",

}

local playerUnreachBegin = {
    "METROPOLICE_HIT_BY_PHYSOBJECT2",
    "METROPOLICE_ARREST_IN_POS1",

}

local stunstickEquip = {
    "METROPOLICE_ACTIVATE_BATON0",
    "METROPOLICE_ACTIVATE_BATON1",
    "METROPOLICE_ACTIVATE_BATON2",

}

-- needs this overridden, supercop hates everything by default
function ENT:GetDesiredEnemyRelationship( myTbl, ent, _entsTbl, _isFirst )
    local disp = D_HT
    local theirdisp = D_HT
    local priority = 1

    if ent:GetClass() == self:GetClass() then
        disp = D_LI
        theirdisp = D_LI

    end

    if ent:IsPlayer() then
        priority = 1000

    elseif ent:IsNPC() or ent:IsNextBot() then
        local obj = ent:GetPhysicsObject()
        -- invalid npc or something, happens alot with engine ents
        if not IsValid( obj ) then
            disp = D_NU
            priority = 0
            return disp,priority,theirdisp

        end

        local memories = {}
        if myTbl.awarenessMemory then
            memories = myTbl.awarenessMemory

        end
        local key = myTbl.getAwarenessKey( self, ent )
        local memory = memories[key]

        if memory == MEMORY_WEAPONIZEDNPC then
            priority = priority + 300

        else
            priority = priority + 100

        end
    end

    return disp,priority,theirdisp
end

local beatinStickClass = "weapon_term_supercopstunstick"
local olReliableClass = "weapon_term_supercoprevolver"

ENT.DefaultWeapon = olReliableClass
ENT.TERM_FISTS = beatinStickClass

function ENT:OnKilledPlayerEnemyLine()
    -- secret, funny pick up that can line
    if math.random( 0, 100 ) <= 5 and math.random( 0, 100 ) <= 15 and self.NextPickupTheCanLine < CurTime() then
        self.NextPickupTheCanLine = CurTime() + 55
        self.NextTermSpeak = CurTime() + 4
        timer.Simple( 1.5, function()
            if not IsValid( self ) then return end
            self:Term_SpeakSoundNow( "npc/metropolice/vo/pickupthecan3.wav" )

        end )

        timer.Simple( 2.75, function()
            if not IsValid( self ) then return end
            self:Term_SpeakSoundNow( "npc/metropolice/vo/chuckle.wav" )

        end )
    else
        self:Term_SpeakSentence( playerDead )

    end
end

function ENT:OnKilledGenericEnemyLine( enemyLost )
    -- killed other supercop, i am the the superior cop
    if IsValid( enemyLost ) and enemyLost:GetClass() == self:GetClass() then
        self:SetHealth( self:Health(), self:GetMaxHealth() / 2, self:GetMaxHealth() )

    end
end

-- re-override terminator's aimvector code
function ENT:GetAimVector()
    local dir = self:GetEyeAngles():Forward()

    if self:HasWeapon() then
        local deg = 0.01
        local active = self:GetActiveLuaWeapon()
        if isfunction( active.GetNPCBulletSpread ) then
            deg = active:GetNPCBulletSpread( self:GetCurrentWeaponProficiency() )
            deg = math.sin( math.rad( deg ) )
        end

        dir:Add( Vector( math.Rand( -deg, deg ), math.Rand( -deg, deg ),math.Rand( -deg, deg ) ) )
    end

    return dir
end

-- supercop is really angry for less time
function ENT:IsReallyAngry()
    local reallyAngryTime = self.terminator_ReallyAngryTime or CurTime()
    local checkIsReallyAngry = self.terminator_CheckIsReallyAngry or 0

    if checkIsReallyAngry < CurTime() then
        self.terminator_CheckIsReallyAngry = CurTime() + 1
        local enemy = self:GetEnemy()

        if enemy and enemy.isTerminatorHunterKiller then
            reallyAngryTime = reallyAngryTime + 60

        elseif self.isUnstucking then
            reallyAngryTime = reallyAngryTime + 2

        elseif self:inSeriousDanger() then
            reallyAngryTime = reallyAngryTime + 2

        elseif self:EnemyIsUnkillable() then
            reallyAngryTime = reallyAngryTime + 10

        end
    end

    local reallyAngry = reallyAngryTime > CurTime()
    self.terminator_ReallyAngryTime = math.max( reallyAngryTime, CurTime() )

    return reallyAngry

end


local spawnProtectionLength     = CreateConVar( "supercop_nextbot_spawnprot_copspawn",  10, bit.bor( FCVAR_ARCHIVE ), "Bot won't shoot until it's been alive for this long", 0, 60 )
local plyspawnProtectionLength  = CreateConVar( "supercop_nextbot_spawnprot_ply",       5, bit.bor( FCVAR_ARCHIVE ), "Don't shoot players until they've been alive for this long.", 0, 60 )

ENT.SupercopEquipRevolverDist = 150
ENT.DuelEnemyDist = ENT.SupercopEquipRevolverDist
ENT.EquipDistRampup = 15
ENT.SupercopMaxUnequipRevolverDist = 1200
ENT.SupercopBeatingStickDist = 100
ENT.SupercopBlockOlReliable = 0
ENT.SupercopBlockShooting = 0
ENT.NextPickupTheCanLine = 0

ENT.DefaultAimSpeed = 80
ENT.MeleeAimSpeedMul = 6

ENT.ShouldJog = false

local CurTime = CurTime

local ignorePlayers = GetConVar( "ai_ignoreplayers" )
local cheats = GetConVar( "sv_cheats" )
local aiDisabled = GetConVar( "ai_disabled" )
local developer = GetConVar( "developer" )
local supercopIgnorePlayers = CreateConVar( "supercop_nextbot_ignoreplayers", 0, bit.bor( FCVAR_NONE ), "Ignore players?" )

function ENT:IgnoringPlayers()
    if supercopIgnorePlayers:GetBool() then return true end
    if cheats:GetBool() and developer:GetBool() and ignorePlayers:GetBool() then return true end

end
function ENT:DisabledThinking()
    if cheats:GetBool() and developer:GetBool() and aiDisabled:GetBool() then return true end

end

hook.Add( "PlayerSpawn", "supercop_plyspawnprotection", function( spawned )
    spawned.Supercop_SpawnProtection = CurTime() + plyspawnProtectionLength:GetInt()

end )

local supercopJog = CreateConVar( "supercop_nextbot_jog", 0, bit.bor( FCVAR_ARCHIVE ), "Should supercop jog?.", 0, 1 )

function ENT:AdditionalInitialize()
    self:SetModel( supercopModel() )

    self:SetCollisionGroup( COLLISION_GROUP_PLAYER )
    self:SetSolidMask( MASK_PLAYERSOLID )

    self:SetBloodColor( DONT_BLEED )

    local spawnProt = spawnProtectionLength:GetInt()
    self.SupercopJustspawnedBlockShooting = CurTime() + spawnProt
    self.SupercopJustspawnedBlockBeatstick = CurTime() + ( spawnProt * 0.25 )

    self.Term_FOV = 180
    self.AutoUpdateFOV = nil

    self.AimSpeed = self.DefaultAimSpeed
    self.NextForcedEnemy = CurTime()
    self.LastEnemySpotTime = CurTime()
    self.isTerminatorHunterChummy = "supercop"

    if engine.ActiveGamemode() == "terrortown" then
        if supercopJog:GetBool() then return end
        timer.Simple( 0, function()
            if not IsValid( self ) then return end
            local button = ents.Create( "ttt_traitor_button" )
            if not IsValid( button ) then return end
            button:SetPos( self:WorldSpaceCenter() )
            button.RawDescription = "Make supercop jog ( Costs 2 Credits )"
            button.RawDelay = -1
            button:SetUsableRange( 512 )
            button:SetParent( self )
            button:Spawn()

            button.IsSupercopJogButton = true
            button.my_supercop = self

        end )
    end
end

if engine.ActiveGamemode() == "terrortown" then
    hook.Add( "TTTCanUseTraitorButton", "supercop_jogbutton_canpress", function( button, presser )
        if not button.IsSupercopJogButton then return end

        if presser:GetCredits() >= 2 then return true end

        return false, "You don't have enough credits to activate this."

    end )
    hook.Add( "TTTTraitorButtonActivated", "supercop_jogbutton_functionality", function( button, presser )
        if not button.IsSupercopJogButton then return end

        presser:SetCredits( presser:GetCredits() - 2 )
        button.my_supercop.ShouldJog = true

    end )
end

local function aliveEnem( me )
    local enem = me:GetEnemy()
    if not IsValid( enem ) then return end
    if enem:IsPlayer() then
        return enem:Alive()

    else
        if enem:GetMaxHealth() > 0 then
            return enem:Health() > 0

        end
    end
    return true

end

local function stunstickCondition( me )
    if me:GetActiveWeapon():GetClass() ~= me.TERM_FISTS then return end
    if not aliveEnem( me ) then return end
    return true

end

local function revolverCondition( me )
    if me:GetActiveWeapon():GetClass() == me.TERM_FISTS then return end
    if not aliveEnem( me ) then return end
    return true

end

function ENT:DoCustomTasks( defaultTasks )
    self.TaskList = {
        ["awareness_handler"] = defaultTasks["awareness_handler"],
        ["reallystuck_handler"] = defaultTasks["reallystuck_handler"],
        ["movement_wait"] = defaultTasks["movement_wait"],
        ["enemy_handler"] = defaultTasks["enemy_handler"],
        ["supercop_handler"] = {
            StartsOnInitialize = true,
            EnemyFound = function( self, data )
                self:Term_SpeakSentence( spottedEnemy, aliveEnem )

            end,
        },
        ["shooting_handler"] = {
            StartsOnInitialize = true,
            StopsWhenPlayerControlled = true,
            OnStart = function( self, data )
            end,
            BehaveUpdatePriority = function(self,data,interval)
                local enemy = self:GetEnemy()
                local wep = self:GetActiveLuaWeapon() or self:GetActiveWeapon()
                -- edge case
                if not IsValid( wep ) then
                    self:shootAt( self.LastEnemyShootPos, true )
                    return

                end

                local moving = self:primaryPathIsValid()
                local doingBeatinStick = wep:GetClass() == beatinStickClass
                local equipRevolverDist = self.SupercopEquipRevolverDist
                if self:IsReallyAngry() then
                    equipRevolverDist = equipRevolverDist * 2.5

                elseif self:IsAngry() then
                    equipRevolverDist = equipRevolverDist * 1.5

                end
                local closeOrNotMoving = self.DistToEnemy < equipRevolverDist or not moving
                local blockShootingTimeGood = self.SupercopBlockShooting < CurTime()
                -- give fists logic time to work, see isfists in terminator weapons override file
                local nextWeaponPickup = self.terminator_NextWeaponPickup or 0

                if self.DistToEnemy < self.SupercopBeatingStickDist and self.IsSeeEnemy and self.NothingOrBreakableBetweenEnemy then
                    -- bring out stunstick
                    if not doingBeatinStick and blockShootingTimeGood and nextWeaponPickup < CurTime() then
                        self.PreventShooting = nil
                        self.IsHolstered = nil
                        self:Give( beatinStickClass )
                        self.AimSpeed = self.DefaultAimSpeed * self.MeleeAimSpeedMul
                        self.SupercopBlockShooting = CurTime() + 0.2
                        self:Term_SpeakSentence( stunstickEquip, stunstickCondition )
                        self.SupercopBlockOlReliable = CurTime() + math.Rand( 2, 3 )

                    end
                elseif doingBeatinStick then
                    -- put away stunstick
                    if blockShootingTimeGood and nextWeaponPickup < CurTime() and self.SupercopBlockOlReliable < CurTime() then
                        self:Give( olReliableClass )
                        -- fix aimspeed
                        self.AimSpeed = self.DefaultAimSpeed
                        self.SupercopBlockShooting = CurTime() + 0.4

                    end
                -- bring out gun
                elseif self.IsHolstered and closeOrNotMoving and self.IsSeeEnemy and self.NothingOrBreakableBetweenEnemy then
                    self.IsHolstered = nil
                    self:Term_SpeakSentence( weaponWarn, revolverCondition )

                    self.SupercopBlockShooting = math.max( self.SupercopBlockShooting, CurTime() + 0.75 )
                    self.PreventShooting = nil

                    -- make sure supercop's aimspeed is fixed!
                    self.AimSpeed = self.DefaultAimSpeed

                    -- as ply tests bot, increase the dist that we pull out the gun at.
                    local increased = self.SupercopEquipRevolverDist + self.EquipDistRampup
                    increased = math.Clamp( increased, 0, self.SupercopMaxUnequipRevolverDist + -250 )
                    self.SupercopEquipRevolverDist = increased

                -- put away gun
                elseif self.DistToEnemy > ( self.SupercopEquipRevolverDist + 250 ) and moving and blockShootingTimeGood and not self:IsReallyAngry() then
                    self.IsHolstered = true
                    self.PreventShooting = true

                end

                local lostEnemyForASec = ( self.LastEnemySpotTime + 1 ) < CurTime()
                local needToReload = ( wep:Clip1() < wep:GetMaxClip1() / 2 ) or ( wep:Clip1() < wep:GetMaxClip1() and self.IsHolstered )

                if self.IsHolstered ~= self.OldIsHolstered then
                    -- gun was reloaded and i dont need to shoot right now
                    if self.IsHolstered and wep:Clip1() == wep:GetMaxClip1() then
                        wep:SetWeaponHoldType( "passive" )

                    -- i need to shoot!
                    elseif self.IsHolstered ~= true then
                        wep:SetWeaponHoldType( "revolver" )

                    end
                    self.OldIsHolstered = self.IsHolstered

                end
                local readyToShoot = self.SupercopBlockShooting < CurTime()
                local tooLongSinceSeen = math.abs( self.LastEnemySpotTime - CurTime() ) > 4
                local canSeeThem = self.IsSeeEnemy
                local blockShooting = not blockShootingTimeGood or self.IsHolstered or self.PreventShooting or not readyToShoot or tooLongSinceSeen
                -- by default, aim at the last spot we saw enemy
                local toAimAt = self.LastEnemyShootPos
                -- otherwise, if we see enemy, aim right at them
                -- basically don't always aim at entshootpos  
                if canSeeThem then
                    toAimAt = self:EntShootPos( enemy )

                end

                if IsValid( enemy ) and not blockShooting and canSeeThem then
                    local enemySpawnProtEnds = enemy.Supercop_SpawnProtection or 0
                    local enemyIsSpawnProtected = enemySpawnProtEnds > CurTime()

                    if doingBeatinStick then
                        self:shootAt( toAimAt, true )
                        -- beating stick gets a shorter cooldown after bot spawned, and ignores per-player spawnprotection
                        if ( self.DistToEnemy < wep.Range * 1.25 ) and self.SupercopJustspawnedBlockBeatstick < CurTime() and readyToShoot then
                            self:WeaponPrimaryAttack()

                        end
                    else
                        -- dont shoot if bot just spawned, or enemy just spawned
                        local protected = ( self.SupercopJustspawnedBlockShooting > CurTime() ) or enemyIsSpawnProtected or not self.IsSeeEnemy
                        local shootableVolatile = self:getShootableVolatile( enemy )

                        -- attack barrel next to ply!
                        if IsValid( shootableVolatile ) and not protected then
                            self:shootAt( self:getBestPos( shootableVolatile ), false, 4 )

                        -- attack ply!
                        else
                            self:shootAt( toAimAt, protected, 4 )

                        end
                    end
                elseif wep:Clip1() <= 0 and wep:GetMaxClip1() > 0 and lostEnemyForASec then
                    self:WeaponReload()
                    self.OldIsHolstered = nil

                elseif wep:GetMaxClip1() > 0 and self.IsSeeEnemy and self.NothingOrBreakableBetweenEnemy and needToReload then
                    self:WeaponReload()
                    self.OldIsHolstered = nil

                elseif not IsValid( enemy ) then
                    local forcedToLook = self:Term_LookAround( data.myTbl )
                    if forcedToLook then return end

                else
                    -- look at enemy, block shooting
                    self:shootAt( toAimAt, true )

                end
            end,
            StartControlByPlayer = function( self, data, ply )
                self:TaskFail( "shooting_handler" )

            end,
        },
        ["movement_handler"] = {
            StartsOnInitialize = true,
            StopsWhenPlayerControlled = true,
            OnStart = function( self, data )
                data.wait = CurTime() + 0.5

            end,
            BehaveUpdateMotion = function( self, data )
                if data.wait > CurTime() then return end
                self:TaskComplete( "movement_handler" )
                self:StartTask2( "movement_followenemy", nil, "getem!" )

            end,
        },
        -- follow enemy
        -- if not enemy, bail to maintainlos
        -- if failed path to enemy, bail too
        ["movement_followenemy"] = {
            OnStart = function( self, data )
                data.nextTauntLine = CurTime() + 8

                self:InvalidatePath( "started followenemy" )

            end,
            BehaveUpdateMotion = function( self, data )
                local enemy = self:GetEnemy()
                local validEnemy = IsValid( enemy ) and enemy:Health() > 0
                local enemyPos = self:GetLastEnemyPosition( enemy ) or self.EnemyLastPos or nil

                local noPath = enemyPos and not self:primaryPathIsValid()
                local currentPathIsStale = enemyPos and self:primaryPathIsValid() and self:CanDoNewPath( enemyPos ) and not self.terminator_HandlingLadder

                local newPath = noPath or currentPathIsStale
                newPath = self:nextNewPathIsGood() and not data.Unreachable and newPath

                if newPath then
                    local result = terminator_Extras.getNearestPosOnNav( enemyPos )

                    local reachable = self:areaIsReachable( result.area )
                    if not reachable then data.Unreachable = true return end

                    local aboveUsJustShoot = ( math.abs( result.pos.z - enemyPos.z ) / 2 ) > self:GetPos():Distance( result.pos ) -- flying enemy
                    if aboveUsJustShoot then data.Unreachable = true return end

                    local posOnNav = result.pos
                    self:SetupPathShell( posOnNav )

                    if not self:primaryPathIsValid() then data.Unreachable = true return end

                end

                self:ControlPath2( not self.IsSeeEnemy )

                local pathLeng = 0
                local pathIsCurrent
                if self:primaryPathIsValid() then
                    pathLeng = self:GetPath():GetLength()
                    if enemyPos then
                        pathIsCurrent = self:GetPath():GetEnd():DistToSqr( enemyPos ) < 200^2

                    end
                end

                local circuitiousPath = self.IsSeeEnemy and self.NothingOrBreakableBetweenEnemy and ( pathLeng > ( self.DistToEnemy * 8 ) ) and ( pathLeng > 3000 ) and pathIsCurrent

                -- not worth pathing to new enemy
                if validEnemy then
                    if data.Unreachable or circuitiousPath or ( enemy.InVehicle and enemy:InVehicle() ) then
                        --print( data.Unreachable, failedPath, circuitiousPath, pathLeng, ( enemy.InVehicle and enemy:InVehicle() ) )
                        self:TaskComplete( "movement_followenemy" )
                        self:StartTask2( "movement_maintainlos", { Unreachable = true }, "they're unreachable!" )
                        if validEnemy then
                            self:Term_SpeakSentence( playerUnreachBegin, aliveEnem )

                        end
                    end
                    if data.nextTauntLine < CurTime() then
                        if self.IsSeeEnemy then
                            self:Term_SpeakSentence( approachingEnemyVisible, aliveEnem )
                            data.nextTauntLine = CurTime() + math.Rand( 7, 13 )

                        else
                            self:Term_SpeakSentence( approachingEnemyObscured, aliveEnem )
                            data.nextTauntLine = CurTime() + math.Rand( 13, 20 )

                        end
                    end
                -- reached end of path
                elseif not self:primaryPathIsValid() then
                    self:TaskComplete( "movement_followenemy" )
                    self:StartTask2( "movement_maintainlos", nil, "no enemy!" )
                end
            end,
            StartControlByPlayer = function()
            end,
            ShouldRun = function( self, data )
                return self.ShouldJog or supercopJog:GetBool()
            end,
            ShouldWalk = function( self, data )
                return not ( self.ShouldJog or supercopJog:GetBool() )
            end,
        },
        ["movement_maintainlos"] = {
            OnStart = function( self, data )
                local enemy = self:GetEnemy()
                data.nextPath = 0
                data.tryAndApproach = {}
                if data.Unreachable and IsValid( enemy ) then
                    data.tryAndApproach[enemy:GetCreationID()] = CurTime() + 5

                end
                data.nextTauntLine = CurTime() + 8
                local distToShootpos = self:GetPos():Distance( self:GetShootPos() )
                data.offsetToShootPos = Vector( 0, 0, distToShootpos )

                data.endToEnemyBlockedCount = 0

                self:GetPath():Invalidate()

            end,
            BehaveUpdateMotion = function( self, data )
                local enemy = self:GetEnemy()
                local goodEnemy = IsValid( enemy ) and enemy:Health() >= 0
                local seeAndCanShoot = self.IsSeeEnemy and self.NothingOrBreakableBetweenEnemy
                local canTryToApproach = false

                if not data.wander and not goodEnemy then
                    data.wander = true

                elseif data.wander and goodEnemy then
                    data.wander = nil

                end

                if goodEnemy then
                    local time = data.tryAndApproach[enemy:GetCreationID()]
                    canTryToApproach = ( not time or time < CurTime() ) or data.wander

                end

                local endCanSeeEnemy

                if self:primaryPathIsValid() and IsValid( enemy ) then
                    endCanSeeEnemy = self:ClearOrBreakable( self:GetPath():GetEnd() + data.offsetToShootPos, self:EntShootPos( enemy ) )
                    data.endToEnemyBlockedCount = data.endToEnemyBlockedCount + 1

                end
                if not endCanSeeEnemy then
                    data.endToEnemyBlockedCount = 0

                end

                local standingStillAndCantSee = not self:primaryPathIsValid() and not seeAndCanShoot
                local walkingOverAndEndCantSee = not data.wander and self:primaryPathIsValid() and data.endToEnemyBlockedCount > 15 and not self.terminator_HandlingLadder

                local newPath = standingStillAndCantSee or walkingOverAndEndCantSee
                if newPath and data.nextPath < CurTime() then
                    local enemysShootPos = nil
                    local enemsCrouchShootPos = nil
                    if not data.wander then
                        enemysShootPos = self:EntShootPos( enemy )
                        enemsCrouchShootPos = enemysShootPos + ( -data.offsetToShootPos / 2 )

                    end

                    local scoreData = {}
                    scoreData.blockRadiusEnd = not data.wander

                    scoreData.self = self
                    scoreData.myShootPos = self:GetShootPos()
                    scoreData.enemysShootPos = enemysShootPos
                    scoreData.enemysCrouchShootPos = enemsCrouchShootPos
                    scoreData.areaCenterOffset = data.offsetToShootPos
                    scoreData.wander = data.wander
                    scoreData.startingShootPosZ = scoreData.myShootPos.z
                    scoreData.goingFurtherAwayCutoff = self.DistToEnemy^2

                    local maxDist = 2000

                    if IsValid( enemy ) then
                        maxDist = self.DistToEnemy + 2000
                        maxDist = math.Clamp( maxDist, 2000, 8000 )

                    end

                    -- find areas that have a line of sight to my enemy
                    local scoreFunction = function( scoreData, area1, area2 )
                        if not scoreData.self:areaIsReachable( area2 ) then return 0 end

                        local area2Center = area2:GetCenter()

                        local enemsShoot = scoreData.enemysShootPos
                        local score = 1
                        if enemsShoot then
                            score = math.Round( ( maxDist - area2Center:Distance( enemsShoot ) ) / maxDist, 3 )

                        end

                        local heightChange = area1:ComputeGroundHeightChange( area2 )
                        local wander = scoreData.wander

                        if heightChange > scoreData.self.JumpHeight then
                            score = score * 0.5
                            --debugoverlay.Cross( area2Center, 10, 10, color_white, true )

                        elseif wander and ( heightChange < -( scoreData.self.JumpHeight / 2 ) ) then
                            score = score * 0.5

                        end

                        if area2:IsUnderwater() then
                            if wander then
                                score = score * 0.05

                            else
                                score = score * 0.6

                            end
                        end

                        local firstWasGood

                        if score >= 0.8 and not wander then
                            local firstClearOrBreakable, _, firstJustClear = self:ClearOrBreakable( area2Center + scoreData.areaCenterOffset, enemsShoot )

                            if firstJustClear then
                                firstWasGood = true
                                score = 1000

                            elseif firstClearOrBreakable then
                                score = maxDist - area2Center:Distance( enemsShoot ) / 100

                            end
                        end

                        if firstWasGood then
                            local potentialSnipingSpot = area2Center + scoreData.areaCenterOffset
                            local secondClearOrBreakable, _, secondJustClear = self:ClearOrBreakable( potentialSnipingSpot, scoreData.enemysCrouchShootPos )
                            if secondJustClear and terminator_Extras.PosCanSeeComplex( potentialSnipingSpot, scoreData.enemysCrouchShootPos ) then
                                score = math.huge -- perfect spot to shoot from

                            elseif secondClearOrBreakable then
                                score = 2000
                                --debugoverlay.Text( area2Center, tostring( score ), 5, false )
                            end
                        end

                        if not wander then
                            -- prefer high ground
                            if area2Center.z > scoreData.startingShootPosZ then
                                score = score * 1.5

                            -- don't go down!
                            elseif area2Center.z < ( scoreData.startingShootPosZ + -300 ) then
                                score = math.Clamp( score * 0.5, 0, 10000 )

                            end
                            if area2Center:DistToSqr( enemsShoot ) > scoreData.goingFurtherAwayCutoff then
                                score = score * 0.8

                            end
                        else
                            -- dont go to spots we've already been
                            if scoreData.self.walkedAreas[ area2:GetID() ] then
                                score = score * 0.05

                            -- prefer higher spots when wandering 
                            elseif area2Center.z > ( scoreData.startingShootPosZ + 150 ) then
                                score = score * 4

                            elseif area2Center.z < ( scoreData.startingShootPosZ + -300 ) then
                                score = score * 0.05

                            end
                        end

                        --debugoverlay.Text( area2Center, tostring( score ), 5, false )

                        return score

                    end
                    local posWithSightline = self:findValidNavResult( scoreData, self:GetPos(), maxDist, scoreFunction, 8 )

                    local result = terminator_Extras.getNearestPosOnNav( posWithSightline )
                    local posOnNav = result.pos

                    if posOnNav then
                        self:InvalidatePath( "new path time, los" )
                        self:SetupPathShell( posOnNav )

                        data.nextPath = CurTime() + math.Rand( 0.25, 0.5 )
                        --debugoverlay.Cross( posOnNav, 100, 1, color_white, true )

                        if not self:primaryPathIsValid() then return end
                        data.endToEnemyBlockedCount = 0
                        data.nextPath = CurTime() + math.Rand( 0.5, 1 )

                    end
                elseif data.endToEnemyBlockedCount > 4 and seeAndCanShoot then
                    -- walked into los, but path end will take us out of los
                    self:InvalidatePath( "break path, i can see em!" )

                end

                if not newPath and goodEnemy then
                    data.nextPath = math.max( CurTime() + 1, data.nextPath )

                end

                local farFromPathEnd = self:GetPath():GetEnd():DistToSqr( self:GetPos() ) > 200^2
                -- if bot is handling path then override shooting handler
                local isTraversingPath = self:primaryPathIsValid() and farFromPathEnd and self.DistToEnemy > self.SupercopMaxUnequipRevolverDist
                local pathResult = self:ControlPath2( isTraversingPath or data.wander )

                if pathResult == true and not data.endedPath then
                    if self.DistToEnemy > self.SupercopMaxUnequipRevolverDist then
                        data.nextPath = CurTime() + math.Rand( 2, 4 )

                    else
                        data.nextPath = CurTime() + math.Rand( 0.5, 1 )

                    end
                    data.endedPath = nil

                end
                data.endedPath = data.endedPath or pathResult == true

                local shouldTryToFollow = seeAndCanShoot and canTryToApproach

                -- this is the BAIL routine
                if goodEnemy and ( shouldTryToFollow or self.OverwatchReportedEnemy ) then
                    self.OverwatchReportedEnemy = nil
                    local navResult = terminator_Extras.getNearestPosOnNav( enemy:GetPos() )
                    local reachable = self:areaIsReachable( navResult.area )
                     -- allow an escape here on wander because wander can't loop easily.
                    if reachable and not ( enemy.InVehicle and enemy:InVehicle() ) then
                        self:TaskComplete( "movement_maintainlos" )
                        self:StartTask2( "movement_followenemy", nil, "enemy seems to be reachable, gonna try pathing to them." )
                        return

                    else
                        self.NextForcedEnemy = 0

                    end
                -- we can see enemy and our path is valid, nuke our path and just open fire
                elseif goodEnemy and seeAndCanShoot and self:primaryPathIsValid() and ( ( math.random( 1, 100 ) < 10 ) or walkingOverAndEndCantSee ) then
                    self:GetPath():Invalidate()
                    data.nextPath = CurTime() + 1

                else
                    if data.nextTauntLine < CurTime() then
                        if seeAndCanShoot then
                            self:Term_SpeakSentence( approachingEnemyVisible, aliveEnem )
                            data.nextTauntLine = CurTime() + math.Rand( 7, 13 )

                        else
                            self:Term_SpeakSentence( approachingEnemyObscured, aliveEnem )
                            data.nextTauntLine = CurTime() + math.Rand( 13, 20 )

                        end
                    end
                end
            end,
            StartControlByPlayer = function()
            end,
            ShouldRun = function( self, data )
                return self.ShouldJog or supercopJog:GetBool()
            end,
            ShouldWalk = function( self, data )
                return not ( self.ShouldJog or supercopJog:GetBool() )
            end,
        },
    }
end
