-- DOES NOT SHOOT THRU FENCES!

AddCSLuaFile()

ENT.Base = "sb_advanced_nextbot_terminator_hunter"
DEFINE_BASECLASS( ENT.Base )
ENT.PrintName = "The Supercop"
ENT.Spawnable = false
list.Set( "NPC", "sb_advanced_nextbot_terminator_hunter_supercop", {
    Name = "The Supercop",
    Class = "sb_advanced_nextbot_terminator_hunter_supercop",
    Category = "SB Advanced Nextbots",
} )

if CLIENT then
    language.Add( "sb_advanced_nextbot_terminator_hunter_supercop", ENT.PrintName )
    return

end

ENT.JumpHeight = 80
ENT.MaxJumpToPosHeight = ENT.JumpHeight
ENT.DefaultStepHeight = 18
ENT.StandingStepHeight = ENT.DefaultStepHeight * 1 -- used in crouch toggle in motionoverrides
ENT.CrouchingStepHeight = ENT.DefaultStepHeight * 0.9
ENT.StepHeight = ENT.StandingStepHeight
ENT.PathGoalToleranceFinal = 35
ENT.SpawnHealth = 5000000
ENT.AimSpeed = 150
ENT.WalkSpeed = 50
ENT.RunSpeed = 100
ENT.AccelerationSpeed = 1000
ENT.DeathDropHeight = 1000
ENT.InformRadius = 0

ENT.DontDropPrimary = true
ENT.LookAheadOnlyWhenBlocked = true
ENT.isTerminatorHunterChummy = false
ENT.DoMetallicDamage = true
ENT.ReallyStrong = false -- no metallic jumping sounds
ENT.alwaysManiac = true -- fights other terminator based npcs, or other supercops
ENT.HasFists = true
ENT.IsTerminatorSupercop = true

ENT.NextSpokenLine = 0
ENT.StuffToSay = {}

local SUPERCOP_MODEL = "models/player/police.mdl"
ENT.ARNOLD_MODEL = SUPERCOP_MODEL

ENT.PhysgunDisabled = true

function ENT:CanProperty()
    return false

end

function ENT:CanTool()
    return false

end

if not SERVER then return end
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

local vecFiveDown = Vector( 0, 0, -5 )

-- copied the original function
function ENT:MakeFootstepSound( volume, surface )
    local foot = self.m_FootstepFoot
    self.m_FootstepFoot = not foot
    self.m_FootstepTime = CurTime()

    local tr

    if not surface then
        tr = util.TraceEntity( {
            start = self:GetPos(),
            endpos = self:GetPos() + vecFiveDown,
            filter = self,
            mask = self:GetSolidMask(),
            collisiongroup = self:GetCollisionGroup(),

        }, self )

        surface = tr.SurfaceProps
    end

    if surface or ( tr and tr.Hit ) then
        local copStep = foot and "NPC_MetroPolice.RunFootstepRight" or "NPC_MetroPolice.RunFootstepLeft"

        self:EmitSound( copStep )

    end

    if not surface then return end

    local surfaceDat = util.GetSurfaceData( surface )
    if not surfaceDat then return end

    local sound = foot and surfaceDat.stepRightSound or surfaceDat.stepLeftSound

    if sound then
        local pos = self:GetPos()

        local filter = RecipientFilter()
        filter:AddPAS( pos )

        if not self:OnFootstep( pos, foot, sound, volume, filter ) then
            self.stepSoundPatches = self.stepSoundPatches or {}

            local stepSound = self.stepSoundPatches[sound]
            if not stepSound then
                stepSound = CreateSound( self, sound, filter )
                self.stepSoundPatches[sound] = stepSound
            end
            stepSound:Stop()
            stepSound:Play()

        end
    end
end

function ENT:ClearOrBreakable( start, endpos )
    local tr = util.TraceLine( {
        start = start,
        endpos = endpos,
        mask = MASK_SHOT,
        filter = self,
    } )

    local hitNothingOrHitBreakable = true
    local hitNothing = true
    if tr.Hit then
        hitNothing = nil
        hitNothingOrHitBreakable = nil

    end
    if IsValid( tr.Entity ) then
        local enemy = self:GetEnemy()
        local isVehicle = tr.Entity:IsVehicle() and tr.Entity:GetDriver() and tr.Entity:GetDriver() == enemy
        if enemy == tr.Entity or isVehicle then
            hitNothingOrHitBreakable = true
            hitNothing = true

        elseif self:memorizedAsBreakable( tr.Entity ) then
            hitNothingOrHitBreakable = true

        end
    end

    return hitNothingOrHitBreakable, tr, hitNothing

end

function ENT:DoHardcodedRelations()
    self:SetClassRelationship( "player", D_HT,1 )
    self:SetClassRelationship( "npc_lambdaplayer", D_HT,1 )
    self:SetClassRelationship( "sb_advanced_nextbot_terminator_hunter", D_HT, 1 )
    self:SetClassRelationship( "sb_advanced_nextbot_terminator_hunter_slower", D_HT, 1 )
    self:SetClassRelationship( "sb_advanced_nextbot_soldier_follower", D_HT )
    self:SetClassRelationship( "sb_advanced_nextbot_soldier_friendly", D_HT )
    self:SetClassRelationship( "sb_advanced_nextbot_soldier_hostile", D_HT )

end

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
    local attacker = damageInfo:GetAttacker()
    if IsValid( attacker ) and attacker ~= damaged and attacker:GetClass() == damaged:GetClass() then
        damageInfo:ScaleDamage( 2 )

    else
        damageInfo:ScaleDamage( 0 )

    end

    damaged:MakeFeud( attacker )

    if not damageInfo:IsBulletDamage() then return end
    doRicsEnt( damaged )
    hitEffect( damageInfo:GetDamagePosition(), 0.25 )

end

hook.Add( "ScaleNPCDamage", "supercop_nextbot_blockdamage", blockDamage )

function ENT:OnTakeDamage( damageInfo )
    local attacker = damageInfo:GetAttacker()
    if IsValid( attacker ) and attacker ~= self and attacker:GetClass() == self:GetClass() then
        damageInfo:ScaleDamage( 2 )

    else
        damageInfo:ScaleDamage( 0 )

    end

    self:MakeFeud( attacker )

    if not damageInfo:IsBulletDamage() then return end
    doRicsEnt( self )
    hitEffect( damageInfo:GetDamagePosition(), 0.25 )

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

}

local playerUnreachBegin = {
    "METROPOLICE_HIT_BY_PHYSOBJECT2",
    "METROPOLICE_ARREST_IN_POS1",

}

local stunstuckEquip = {
    "METROPOLICE_ACTIVATE_BATON0",
    "METROPOLICE_ACTIVATE_BATON1",
    "METROPOLICE_ACTIVATE_BATON2",

}

function ENT:GetDesiredEnemyRelationship( ent )
    local disp = D_HT
    local theirdisp = D_HT
    local priority = 1000

    if ent:GetClass() == self:GetClass() then
        disp = D_LI
        theirdisp = D_LI

    end

    if ent:IsPlayer() then
        priority = 1
    elseif ent:IsNPC() or ent:IsNextBot() then
        local memories = {}
        if self.awarenessMemory then
            memories = self.awarenessMemory
        end
        local key = self:getAwarenessKey( ent )
        local memory = memories[key]
        if memory == MEMORY_WEAPONIZEDNPC then
            priority = priority + -300
        else
            --print("boringent" )
            priority = priority + -100
        end
    end

    return disp,priority,theirdisp
end

local beatinStickClass = "weapon_sb_supercopstunstick"
local olReliableClass = "weapon_sb_supercoprevolver"

ENT.TERM_FISTS = beatinStickClass

function ENT:PlaySentence( sentenceIn )
    if #self.StuffToSay >= 4 then return end -- don't add infinite stuff to say.
    if #self.StuffToSay >= 1 and math.random( 0, 100 ) >= 50 then return end
    table.insert( self.StuffToSay, sentenceIn )

end

ENT.SupercopOnComms = nil
ENT.SupercopOldOnComms = nil

function ENT:AdditionalThink()
    if self.NextSpokenLine > CurTime() then return end
    if #self.StuffToSay <= 0 then return end

    local sentenceIn = table.remove( self.StuffToSay, 1 )

    local sentence

    if istable( sentenceIn ) then
        sentence = sentenceIn[ math.random( 1, #sentenceIn ) ]

    elseif isstring( sentenceIn ) then
        sentence = sentenceIn

    end

    if not sentence then return end
    if isstring( self.lastSpokenSentence ) and ( sentence == self.lastSpokenSentence ) then return end

    self.lastSpokenSentence = sentence

    EmitSentence( sentence, self:GetShootPos(), self:EntIndex(), CHAN_AUTO, 1, 80, 0, 100 )

    local additional = math.random( 10, 15 ) / 10

    local duration = SentenceDuration( sentence ) or 1
    self.NextSpokenLine = CurTime() + ( duration + additional )

end

function ENT:SpeakLine( line )
    self:EmitSound( line, 85, 100, 1, CHAN_AUTO )

end


hook.Add( "terminator_engagedenemywasbad", "supercop_killedenemy", function( self, enemyLost )
    if not self.IsTerminatorSupercop then return end
    if not IsValid( enemyLost ) then return end
    if enemyLost:Health() <= 0 then
        -- secret, funny pick up that can line
        if math.random( 0, 100 ) <= 5 and math.random( 0, 100 ) <= 15 and self.NextPickupTheCanLine < CurTime() then
            self.NextPickupTheCanLine = CurTime() + 55
            self.NextSpokenLine = CurTime() + 4
            timer.Simple( 1.5, function()
                if not IsValid( self ) then return end
                self:SpeakLine( "npc/metropolice/vo/pickupthecan3.wav" )

            end )

            timer.Simple( 2.75, function()
                if not IsValid( self ) then return end
                self:SpeakLine( "npc/metropolice/vo/chuckle.wav" )

            end )
        else
            self:PlaySentence( playerDead )

        end
        -- killed other supercop, i am the the superior cop
        if IsValid( enemyLost ) and enemyLost:GetClass() == self:GetClass() then
            self:SetHealth( self:Health(), self:GetMaxHealth() / 2, self:GetMaxHealth() )

        end
    end
end )

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

local spawnProtectionLength     = CreateConVar( "supercop_nextbot_spawnprot_copspawn",  10, bit.bor( FCVAR_ARCHIVE ), "Bot won't shoot until it's been alive for this long", 0, 60 )
local plyspawnProtectionLength  = CreateConVar( "supercop_nextbot_spawnprot_ply",       5, bit.bor( FCVAR_ARCHIVE ), "Don't shoot players until they've been alive for this long.", 0, 60 )

ENT.SupercopEquipRevolverDist = 350
ENT.EquipDistRampup = 15
ENT.SupercopMaxUnequipRevolverDist = 1200
ENT.SupercopBeatingStickDist = 125
ENT.SupercopBlockOlReliable = 0
ENT.SupercopBlockShooting = 0
ENT.NextPickupTheCanLine = 0

local _CurTime = CurTime
local ignorePlayers = GetConVar( "ai_ignoreplayers" )

hook.Add( "PlayerSpawn", "supercop_plyspawnprotection", function( spawned )
    spawned.Supercop_SpawnProtection = _CurTime() + plyspawnProtectionLength:GetInt()

end )

function ENT:AdditionalInitialize()
    self:SetModel( supercopModel() )

    self:Give( "weapon_sb_supercoprevolver" )

    self:SetBloodColor( DONT_BLEED )

    local spawnProt = spawnProtectionLength:GetInt()
    self.SupercopJustspawnedBlockShooting = _CurTime() + spawnProt
    self.SupercopJustspawnedBlockBeatstick = _CurTime() + ( spawnProt * 0.25 )

    self.LastEnemySpotTime = _CurTime()

end

local supercopJog = CreateConVar( "supercop_nextbot_jog", 0, bit.bor( FCVAR_ARCHIVE ), "Should supercop jog?.", 0, 1 )

function ENT:GetFootstepSoundTime()
    local vel2d = self.loco:GetVelocity():Length2D()
    return 1000 + -vel2d * 6.5

end

function ENT:DoTasks()
    self.TaskList = {
        ["shooting_handler"] = {
            OnStart = function( self, data )
            end,
            BehaveUpdate = function(self,data,interval)
                local enemy = self:GetEnemy()
                local wep = self:GetActiveLuaWeapon() or self:GetActiveWeapon()
                -- edge case
                if not IsValid( wep ) then
                    self:shootAt( self.LastEnemyShootPos )
                    return

                end

                local moving = self:primaryPathIsValid()
                local doingBeatinStick = wep:GetClass() == beatinStickClass
                local closeOrNotMoving = self.DistToEnemy < self.SupercopEquipRevolverDist or not moving or self:IsReallyAngry()
                local blockShootingTimeGood = self.SupercopBlockShooting < _CurTime()
                -- give fists logic time to work, see isfists in terminator weapons override file
                local nextWeaponPickup = self.terminator_NextWeaponPickup or 0

                if self.DistToEnemy < self.SupercopBeatingStickDist and self.NothingOrBreakableBetweenEnemy then
                    -- bring out stunstuck
                    if not doingBeatinStick and blockShootingTimeGood and nextWeaponPickup < _CurTime() then
                        self.PreventShooting = nil
                        self.DoHolster = nil
                        self:Give( beatinStickClass )
                        self.SupercopBlockShooting = _CurTime() + 0.2
                        self:PlaySentence( stunstuckEquip )
                        self.SupercopBlockOlReliable = _CurTime() + math.Rand( 2, 3 )

                    end

                elseif doingBeatinStick then
                    -- put away stunstick
                    if blockShootingTimeGood and nextWeaponPickup < CurTime() and self.SupercopBlockOlReliable < CurTime() then
                        self:Give( olReliableClass )
                        self.SupercopBlockShooting = _CurTime() + 0.4

                    end
                -- bring out gun
                elseif self.DoHolster and closeOrNotMoving then
                    self.DoHolster = nil
                    self:PlaySentence( weaponWarn )

                    -- as ply tests bot, increase the dist that we pull out the gun at.
                    self.SupercopBlockShooting = math.max( self.SupercopBlockShooting, _CurTime() + 0.75 )
                    self.PreventShooting = nil

                    local increased = self.SupercopEquipRevolverDist + self.EquipDistRampup
                    increased = math.Clamp( increased, 0, self.SupercopMaxUnequipRevolverDist + -250 )
                    self.SupercopEquipRevolverDist = increased

                -- put away gun
                elseif self.DistToEnemy > ( self.SupercopEquipRevolverDist + 250 ) and moving and blockShootingTimeGood and not self:IsReallyAngry() then
                    self.DoHolster = true
                    self.PreventShooting = true

                end

                local lostEnemyForASec = ( self.LastEnemySpotTime + 1 ) < CurTime()
                local needToReload = ( wep:Clip1() < wep:GetMaxClip1() / 2 ) or ( wep:Clip1() < wep:GetMaxClip1() and self.DoHolster )

                if self.DoHolster ~= self.OldDoHolster then
                    if self.DoHolster and wep:Clip1() == wep:GetMaxClip1() then
                        wep:SetWeaponHoldType( "passive" )

                    elseif self.DoHolster ~= true then
                        wep:SetWeaponHoldType( "revolver" )

                    end
                    self.OldDoHolster = self.DoHolster

                end
                local tooLongSinceSeen = math.abs( self.LastEnemySpotTime - _CurTime() ) > 4
                local blockShooting = not blockShootingTimeGood or self.DoHolster or self.PreventShooting or not self.NothingOrBreakableBetweenEnemy or self.SupercopBlockShooting > _CurTime() or tooLongSinceSeen
                -- by default, aim at the last spot we saw enemy
                local toAimAt = self.LastEnemyShootPos
                -- otherwise, if we see enemy, aim right at them
                -- basically don't always aim at entshootpos  
                if self.IsSeeEnemy then
                    toAimAt = self:EntShootPos( enemy )

                end

                if IsValid( enemy ) and not blockShooting then
                    local enemySpawnProtEnds = enemy.Supercop_SpawnProtection or 0
                    local enemyIsSpawnProtected = enemySpawnProtEnds > _CurTime()

                    if doingBeatinStick then
                        self:shootAt( toAimAt, true )
                        -- beating stick gets a shorter cooldown after bot spawned, and ignores per-player spawnprotection
                        if ( self.DistToEnemy < wep.Range * 1.25 ) and self.SupercopJustspawnedBlockBeatstick < _CurTime() then
                            self:WeaponPrimaryAttack()

                        end
                    else
                        -- dont shoot if bot just spawned, or enemy just spawned
                        local protected = ( self.SupercopJustspawnedBlockShooting > _CurTime() ) or enemyIsSpawnProtected
                        self:shootAt( toAimAt, protected )

                    end
                elseif wep:Clip1() <= 0 and wep:GetMaxClip1() > 0 and lostEnemyForASec then
                    self:WeaponReload()
                    self.OldDoHolster = nil

                elseif wep:GetMaxClip1() > 0 and self.NothingOrBreakableBetweenEnemy and needToReload then
                    self:WeaponReload()
                    self.OldDoHolster = nil

                else
                    self:shootAt( toAimAt, true )

                end
            end,
            StartControlByPlayer = function( self, data, ply )
                self:TaskFail( "shooting_handler" )
            end,
        },
        -- manages whether or not stuff is breakable.
        ["awareness_handler"] = {
            BehaveUpdate = function( self, data, interval )
                local nextAware = data.nextAwareness or 0
                if nextAware < _CurTime() then
                    data.nextAwareness = _CurTime() + 1.5
                    self:understandSurroundings()
                end
            end,
        },
        ["enemy_handler"] = {
            OnStart = function( self, data )
                data.UpdateEnemies = _CurTime()
                data.HasEnemy = false
                data.playerCheckIndex = 0
                data.blockSwitchingEnemies = 0
                self.IsSeeEnemy = false
                self.DistToEnemy = 0
                self:SetEnemy( NULL )

                self.UpdateEnemyHandler = function( forceupdateenemies )
                    local prevenemy = self:GetEnemy()
                    local newenemy = prevenemy

                    if forceupdateenemies or not data.UpdateEnemies or _CurTime() > data.UpdateEnemies or data.HasEnemy and not IsValid( prevenemy ) then
                        data.UpdateEnemies = _CurTime() + 0.5

                        self:FindEnemies()

                        -- rotate through all players one by one
                        -- we check looong distance here so it's staggered.
                        if not ignorePlayers:GetBool() then
                            local allPlayers = player.GetAll()
                            local pickedPlayer = allPlayers[data.playerCheckIndex]

                            local didForceEnemy
                            local tooLongSinceLastEnemy = ( self.LastEnemySpotTime + 20 ) < _CurTime()

                            -- check if alive etc
                            -- MESSY but it's better than it going off to the right
                            if
                                IsValid( pickedPlayer ) and
                                pickedPlayer:Health() > 0 and
                                (
                                    ( self:ShouldBeEnemy( pickedPlayer ) and terminator_Extras.PosCanSee( self:GetShootPos(), self:EntShootPos( pickedPlayer ) ) ) or
                                    tooLongSinceLastEnemy
                                )
                            then
                                didForceEnemy = true
                                self:UpdateEnemyMemory( pickedPlayer, pickedPlayer:GetPos() )

                            end

                            if didForceEnemy and tooLongSinceLastEnemy then
                                self.OverwatchReportedEnemy = true
                                self:PlaySentence( "METROPOLICE_FLANK6" )

                            end

                            local new = data.playerCheckIndex + 1
                            if new > #allPlayers then
                                data.playerCheckIndex = 1
                            else
                                data.playerCheckIndex = new
                            end
                        end

                        local enemy = self:FindPriorityEnemy()

                        -- conditional friction for switching enemies.
                        -- fixes bot jumping between two enemies that get obscured as it paths, and doing a little dance
                        if
                            IsValid( enemy ) and
                            IsValid( prevenemy ) and
                            prevenemy:Health() > 0 and -- old enemy needs to be alive...
                            prevenemy ~= enemy and
                            data.blockSwitchingEnemies > 0 and
                            self:GetPos():Distance( enemy:GetPos() ) > self.SupercopEquipRevolverDist -- enemy needs to be far away, otherwise just switch now

                        then
                            data.blockSwitchingEnemies = data.blockSwitchingEnemies + -1
                            enemy = prevenemy


                        elseif IsValid( enemy ) then
                            newenemy = enemy
                            local enemyPos = enemy:GetPos()
                            if not self.EnemyLastPos then self.EnemyLastPos = enemyPos end

                            self.LastEnemySpotTime = _CurTime()
                            self.DistToEnemy = self:GetPos():Distance( enemyPos )
                            self.IsSeeEnemy = self:CanSeePosition( enemy )
                            self.NothingOrBreakableBetweenEnemy = self:ClearOrBreakable( self:GetShootPos(), self:EntShootPos( enemy ) )

                            if self.IsSeeEnemy and not self.WasSeeEnemy then
                                hook.Run( "terminator_spotenemy", self, enemy )

                            elseif not self.IsSeeEnemy and self.WasSeeEnemy then
                                hook.Run( "terminator_loseenemy", self, enemy )

                            end

                            hook.Run( "terminator_enemythink", self, enemy )

                            self.WasSeeEnemy = self.IsSeeEnemy

                            -- override enemy's relations to me
                            self:MakeFeud( enemy )
                            -- we cheatily store the enemy's stuff for a second to make bot feel smarter
                            -- people can intuit where someone ran off to after 1 second, so bot can too
                            local posCheatsLeft = self.EnemyPosCheatsLeft or 0
                            if self.IsSeeEnemy then
                                posCheatsLeft = 5000 -- default 5, changing it to 5000 is a certified HACK
                            -- doesn't time out if we are too close to them
                            elseif self.DistToEnemy < 500 and posCheatsLeft >= 1 then
                                --debugoverlay.Line( enemyPos, self:GetPos(), 0.3, Color( 255,255,255 ), true )
                                posCheatsLeft = math.max( 1, posCheatsLeft )

                            end

                            local isPly = enemy:IsPlayer()

                            if isPly and ignorePlayers:GetBool() then
                                self.EnemyPosCheatsLeft = nil

                            elseif enemy and enemy.Alive and enemy:Alive() then
                                self.EnemyPosCheatsLeft = posCheatsLeft + -1
                                self:UpdateEnemyMemory( enemy, enemy:GetPos() )

                            else
                                self.EnemyPosCheatsLeft = nil

                            end

                        else
                            self.DistToEnemy = math.huge
                        end
                    end

                    if IsValid( newenemy ) then
                        if not data.HasEnemy then
                            self:PlaySentence( spottedEnemy )
                            self:RunTask( "EnemyFound", newenemy )

                        elseif prevenemy ~= newenemy then
                            data.blockSwitchingEnemies = math.random( 3, 5 )
                            self:RunTask( "EnemyChanged", newenemy, prevenemy )

                        end
                        data.HasEnemy = true

                        if self:CanSeePosition( newenemy ) then
                            self.LastEnemyShootPos = self:EntShootPos( newenemy )
                            self:UpdateEnemyMemory( newenemy, newenemy:GetPos() )

                        end
                    else
                        if data.HasEnemy then
                            self:RunTask( "EnemyLost", prevenemy )

                        end
                        data.HasEnemy = false
                        self.IsSeeEnemy = false

                    end

                    self:SetEnemy( newenemy )
                end
            end,
            BehaveUpdate = function(self,data,interval)
                self.UpdateEnemyHandler()
            end,
            StartControlByPlayer = function( self, data, ply )
                self:TaskFail( "enemy_handler" )
            end,
        },
        ["movement_handler"] = {
            OnStart = function( self, data )
                self:TaskComplete( "movement_handler" )
                self:StartTask2( "movement_followenemy", nil, "getem!" )

            end,
        },
        -- follow enemy
        -- if not enemy, bail to maintainlos
        -- if failed path to enemy, bail too
        ["movement_followenemy"] = {
            OnStart = function( self, data )
                data.nextTauntLine = _CurTime() + 8

                self:GetPath():Invalidate()

            end,
            BehaveUpdate = function( self, data )
                local enemy = self:GetEnemy()
                local validEnemy = IsValid( enemy ) and enemy:Health() > 0
                local enemyPos = self:GetLastEnemyPosition( enemy ) or self.EnemyLastPos or nil
                data.wasEnemy = validEnemy or data.wasEnemy

                local noPath = enemyPos and not self:primaryPathIsValid()
                local currentPathIsStale = enemyPos and self:primaryPathIsValid() and self:CanDoNewPath( enemyPos )

                local newPath = noPath or currentPathIsStale
                newPath = self:nextNewPathIsGood() and not data.Unreachable and newPath

                if newPath then
                    local result = terminator_Extras.getNearestPosOnNav( enemyPos )

                    local reachable = self:areaIsReachable( result.area )
                    if not reachable then data.Unreachable = true return end

                    local posOnNav = result.pos
                    self:SetupPath2( posOnNav )

                    if not self:primaryPathIsValid() then data.Unreachable = true return end

                end

                local controlResult = self:ControlPath2( not self.IsSeeEnemy )

                local pathLeng = 0
                local pathIsCurrent
                if self:primaryPathIsValid() then
                    pathLeng = self:GetPath():GetLength()
                    if enemyPos then
                        pathIsCurrent = self:GetPath():GetEnd():DistToSqr( enemyPos ) < 200^2

                    end
                end

                local circuitiousPath = self.NothingOrBreakableBetweenEnemy and ( pathLeng > ( self.DistToEnemy * 6 ) ) and ( pathLeng > 2000 ) and pathIsCurrent
                local failedPath = controlResult == false and validEnemy

                if validEnemy and ( data.Unreachable or failedPath or circuitiousPath or ( enemy.InVehicle and enemy:InVehicle() ) ) then
                    --print( data.Unreachable, failedPath, circuitiousPath, pathLeng, ( enemy.InVehicle and enemy:InVehicle() ) )
                    self:TaskComplete( "movement_followenemy" )
                    self:StartTask2( "movement_maintainlos", { Unreachable = true }, "they're unreachable!" )
                    if validEnemy then
                        self:PlaySentence( playerUnreachBegin )

                    end
                elseif controlResult == true then
                    if validEnemy then
                        self:GetPath():Invalidate()

                    elseif not validEnemy then
                        self:TaskComplete( "movement_followenemy" )
                        self:StartTask2( "movement_maintainlos", nil, "no enemy and i checked where they were!" )
                        if data.wasEnemy then
                            data.wasEnemy = nil
                            self:PlaySentence( "METROPOLICE_LOST_LONG" .. math.random( 0, 5 ) )

                        end
                    end
                elseif not self:primaryPathIsValid() and not newPath then
                    self:TaskComplete( "movement_followenemy" )
                    self:StartTask2( "movement_maintainlos", nil, "no enemy to follow!" )

                else
                    if data.nextTauntLine < _CurTime() then
                        if self.IsSeeEnemy then
                            self:PlaySentence( approachingEnemyVisible )
                            data.nextTauntLine = _CurTime() + math.Rand( 7, 13 )

                        else
                            self:PlaySentence( approachingEnemyObscured )
                            data.nextTauntLine = _CurTime() + math.Rand( 13, 20 )

                        end
                    end
                end
            end,
            StartControlByPlayer = function()
            end,
            ShouldRun = function( self, data )
                return supercopJog:GetBool()
            end,
            ShouldWalk = function( self, data )
                return not supercopJog:GetBool()
            end,
        },
        ["movement_maintainlos"] = {
            OnStart = function( self, data )
                local enemy = self:GetEnemy()
                data.nextPath = 0
                data.tryAndApproach = {}
                if data.Unreachable and IsValid( enemy ) then
                    data.tryAndApproach[enemy:GetCreationID()] = CurTime() + 11

                end
                data.nextTauntLine = _CurTime() + 8
                local distToShootpos = self:GetPos():Distance( self:GetShootPos() )
                data.offsetToShootPos = Vector( 0, 0, distToShootpos )

                data.endToEnemyBlockedCount = 0

                self:GetPath():Invalidate()

            end,
            BehaveUpdate = function( self, data )
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
                    canTryToApproach = not time or time < _CurTime()

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
                local walkingOverAndEndCantSee = not data.wander and self:primaryPathIsValid() and data.endToEnemyBlockedCount > 15

                local newPath = standingStillAndCantSee or walkingOverAndEndCantSee
                if newPath and data.nextPath < _CurTime() then
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
                        local area2Center = area2:GetCenter()

                        local score = math.Round( math.Rand( 0.90, 1.10 ), 3 )

                        if not scoreData.self:areaIsReachable( area2 ) then score = 0.1 end

                        local heightChange = area1:ComputeAdjacentConnectionHeightChange( area2 )
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
                            local firstClearOrBreakable, _, firstJustClear = self:ClearOrBreakable( area2Center + scoreData.areaCenterOffset, scoreData.enemysShootPos )

                            if firstJustClear then
                                firstWasGood = true
                                score = 1000

                            elseif firstClearOrBreakable then
                                score = 100

                            end
                        end

                        if firstWasGood then
                            local secondClearOrBreakable, _, secondJustClear = self:ClearOrBreakable( area2Center + scoreData.areaCenterOffset, scoreData.enemysCrouchShootPos )
                            if secondJustClear then
                                score = math.huge -- perfect spot to shoot from

                            elseif secondClearOrBreakable then
                                score = 2000

                            end
                        end

                        if not wander then
                            -- prefer high ground
                            if area2Center.z > scoreData.startingShootPosZ then
                                score = score * 4

                            -- don't go down!
                            elseif area2Center.z < ( scoreData.startingShootPosZ + -300 ) then
                                score = math.Clamp( score * 0.5, 0, 1000 )

                            end
                            if area2Center:DistToSqr( scoreData.enemysShootPos ) > scoreData.goingFurtherAwayCutoff then
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

                    self:GetPath():Invalidate()

                    local result = terminator_Extras.getNearestPosOnNav( posWithSightline )
                    local posOnNav = result.pos
                    self:SetupPath2( posOnNav )

                    data.nextPath = _CurTime() + math.Rand( 0.25, 0.5 )
                    --debugoverlay.Cross( posOnNav, 100, 1, color_white, true )

                    if not self:primaryPathIsValid() then return end
                    data.nextPath = _CurTime() + math.Rand( 0.5, 1 )

                end

                if not newPath and goodEnemy then
                    data.nextPath = math.max( _CurTime() + 1, data.nextPath )

                end

                local farFromPathEnd = self:GetPath():GetEnd():DistToSqr( self:GetPos() ) > 200^2
                -- if bot is handling path then override shooting handler
                local isTraversingPath = self:primaryPathIsValid() and farFromPathEnd and self.DistToEnemy > self.SupercopMaxUnequipRevolverDist
                local pathResult = self:ControlPath2( isTraversingPath or data.wander )

                if pathResult == true and not data.endedPath then
                    if self.DistToEnemy > self.SupercopMaxUnequipRevolverDist then
                        data.nextPath = _CurTime() + math.Rand( 2, 4 )

                    else
                        data.nextPath = _CurTime() + math.Rand( 0.5, 1 )

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
                    if reachable or data.wander then
                        self:TaskComplete( "movement_maintainlos" )
                        self:StartTask2( "movement_followenemy", nil, "see enemy, gonna try pathing to them." )
                        return

                    end
                -- we can see enemy and our path is valid, nuke our path and just open fire
                elseif goodEnemy and seeAndCanShoot and self:primaryPathIsValid() and ( ( math.random( 1, 100 ) < 10 ) or walkingOverAndEndCantSee ) then
                    self:GetPath():Invalidate()
                    data.nextPath = _CurTime() + 1

                else
                    if data.nextTauntLine < _CurTime() then
                        if self.IsSeeEnemy then
                            self:PlaySentence( approachingEnemyVisible )
                            data.nextTauntLine = _CurTime() + math.Rand( 7, 13 )

                        else
                            self:PlaySentence( approachingEnemyObscured )
                            data.nextTauntLine = _CurTime() + math.Rand( 13, 20 )

                        end
                    end
                end
            end,
            StartControlByPlayer = function()
            end,
            ShouldRun = function( self, data )
                return supercopJog:GetBool()
            end,
            ShouldWalk = function( self, data )
                return not supercopJog:GetBool()
            end,
        },
    }
end