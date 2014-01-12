---------------------------------------------------
--  _ _ _           _             _     _ _      --
-- (_) | |         (_)           | |   (_) |     --
--  _| | |_   _ ___ _  ___  _ __ | |    _| |__   --
-- | | | | | | / __| |/ _ \| '_ \| |   | | '_ \  --
-- | | | | |_| \__ \ | (_) | | | | |___| | |_) | --
-- |_|_|_|\__,_|___/_|\___/|_| |_\_____/_|_.__/  --
--                     - By: DarkFire -          --
---------------------------------------------------
--
-- Selects a behavior for the illusions to use based on what the bot's current behavior is
-- If there is no corresponding behavior for the illusions they will use "NoBehavior"
--
-- For example, if the bot is running the "HarassHero" behavior the illusions will attempt
-- to run "HarassHero" from tIllusionsBehaviors
--

--------------------------------------
--          Initialization          --
--------------------------------------

local _G = getfenv(0)
local object = _G.object

object.illusionLib = object.illusionLib or {}
local illusionLib, core, behaviorLib = object.illusionLib, object.core, object.behaviorLib

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub        = _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog

----------------------------------------------------
--          Global Constants & Variables          --
----------------------------------------------------

-- Table containing all illusions owned by the bot
illusionLib.tIllusions = {}

-- Table containing all behaviors used by illusions
illusionLib.tIllusionBehaviors = {}
illusionLib.nNextBehaviorTime = HoN.GetGameTime()
illusionLib.nBehaviorAssessInterval = 100

-- Set to false to disable the behaviors system
illusionLib.bRunBehaviors = true

-- Illusions will only attempt to move if they are farther than this away from the targeted position
illusionLib.nDistanceSqTolerance = 100 * 100

-- Force the illusion to use the idle behavior
-- This value will reset to false on every frame that the illusions are called
-- Set the value to true whenever the bot is stealthed to avoid the illusions giving away it's position
illusionLib.bForceIllusionsToIdle = false

---------------------------------
--          Functions          --
---------------------------------

-- Populates tIllusions with all illusions owned by the bot
function illusionLib.updateIllusions(botBrain)
        illusionLib.tIllusions = {}
        local tPossibleIllusions = core.tControllableUnits["InventoryUnits"]
        if tPossibleIllusions ~= nil then
                for nUID, unit in pairs(tPossibleIllusions) do
                        if unit:IsHero() then
                                tinsert(illusionLib.tIllusions, unit)
                        end
                end
        end
end

---------------------------------
--          Behaviors          --
---------------------------------
--
-- Add/Overwrite Behaviors like this:
--     illusionLib.tIllusionBehaviors["sBehaviorName"] = funcBehavior
--
-- Remove default Behaviors like this:
--     illusionLib.tIllusionBehaviors["sBehaviorName"] = nil
--
-- Default Behaviors:
--     Idle
--     NoBehavior
--     HarassHero
--     RetreatFromThreat
--     HitBuilding
--     AttackCreeps
--     AttackEnemyMinions
--     Push
--

----------------------------
--          Idle          --
----------------------------

-- Illusions will stay in position and attack anything around them
function illusionLib.Idle(botBrain)
        illusionLib.bForceIllusionsToIdle = false

        return illusionLib.OrderIllusionsStop(botBrain, false)
end

illusionLib.tIllusionBehaviors["Idle"] = illusionLib.Idle

----------------------------------
--          NoBehavior          --
----------------------------------

-- Illusions will follow the bot
function illusionLib.NoBehavior(botBrain)
        return illusionLib.OrderIllusionsMoveToPos(botBrain, core.unitSelf:GetPosition())
end

illusionLib.tIllusionBehaviors["NoBehavior"] = illusionLib.NoBehavior

----------------------------------
--          HarassHero          --
----------------------------------

-- Illusions will attack the hero that the bot is targeting
function illusionLib.HarassHero(botBrain)
        local bActionTaken = false
        local unitTarget = behaviorLib.heroTarget

        if unitTarget ~= nil and core.CanSeeUnit(botBrain, unitTarget) then
                bActionTaken = illusionLib.OrderIllusionsAttack(botBrain, unitTarget)
        end

        return bActionTaken
end

illusionLib.tIllusionBehaviors["HarassHero"] = illusionLib.HarassHero

-----------------------------------
--          HitBuilding          --
-----------------------------------

-- Illusions will attack the building that the bot is targeting
function illusionLib.HitBuilding(botBrain)
        local bActionTaken = false
        local unitTarget = behaviorLib.hitBuildingTarget

        if unitTarget ~= nil and core.CanSeeUnit(botBrain, unitTarget) then
                bActionTaken = illusionLib.OrderIllusionsAttack(botBrain, unitTarget)
        end

        return bActionTaken
end

illusionLib.tIllusionBehaviors["HitBuilding"] = illusionLib.HitBuilding

------------------------------------
--          AttackCreeps          --
------------------------------------

-- Illusions will attack the creep that the bot is targeting
-- Will only attack if the creep has less than 10% health
function illusionLib.AttackCreeps(botBrain)
        local bActionTaken = false
        local unitTarget = core.unitCreepTarget

        if unitTarget ~= nil and core.CanSeeUnit(botBrain, unitTarget) and unitTarget:GetHealthPercent() < .1 then
                bActionTaken = illusionLib.OrderIllusionsAttack(botBrain, unitTarget)
        else
                bActionTaken = illusionLib.OrderIllusionsMoveToPosAndHold(botBrain, core.unitSelf:GetPosition())
        end

        return bActionTaken
end

illusionLib.tIllusionBehaviors["AttackCreeps"] = illusionLib.AttackCreeps

------------------------------------------
--          AttackEnemyMinions          --
------------------------------------------

-- Illusions will attack the minion that the bot is targeting
function illusionLib.AttackEnemyMinions(botBrain)
        local bActionTaken = false
        local unitTarget = core.unitMinionTarget

        if unitTarget ~= nil and core.CanSeeUnit(botBrain, unitTarget) then
                bActionTaken = illusionLib.OrderIllusionsAttack(botBrain, unitTarget)
        end

        return bActionTaken
end

illusionLib.tIllusionBehaviors["AttackEnemyMinions"] = illusionLib.AttackEnemyMinions

----------------------------
--          Push          --
----------------------------

-- Illusions will attack everything near the bot
function illusionLib.Push(botBrain)
        return illusionLib.OrderIllusionsAttackPosition(botBrain, core.unitSelf:GetPosition())
end

illusionLib.tIllusionBehaviors["Push"] = illusionLib.Push

---------------------------------------
--          Action Wrappers          --
---------------------------------------
--
-- Wrappers return true if any of the illusions successfully completed an action
--

function illusionLib.OrderIllusionsAttack(botBrain, unitTarget, bQueueCommand)
        local bActionTaken = false

        for _, unitIllusion in pairs(illusionLib.tIllusions) do
                bActionTaken = core.OrderAttack(botBrain, unitIllusion, unitTarget, bQueueCommand) or bActionTaken
        end

        return bActionTaken
end

function illusionLib.OrderIllusionsMoveToUnit(botBrain, unitTarget, bInterruptAttacks, bQueueCommand)
        local bActionTaken = false

        for _, unitIllusion in pairs(illusionLib.tIllusions) do
                bActionTaken = core.OrderMoveToUnit(botBrain, unitIllusion, unitTarget, bInterruptAttacks, bQueueCommand) or bActionTaken
        end

        return bActionTaken
end

function illusionLib.OrderIllusionsFollow(botBrain, unitTarget, bInterruptAttacks, bQueueCommand)
        local bActionTaken = false

        for _, unitIllusion in pairs(illusionLib.tIllusions) do
                bActionTaken = core.OrderFollow(botBrain, unitIllusion, unitTarget, bInterruptAttacks, bQueueCommand) or bActionTaken
        end

        return bActionTaken
end

function illusionLib.OrderIllusionsTouch(botBrain, unitTarget, bInterruptAttacks, bQueueCommand)
        local bActionTaken = false

        for _, unitIllusion in pairs(illusionLib.tIllusions) do
                bActionTaken = core.OrderTouch(botBrain, unitIllusion, unitTarget, bInterruptAttacks, bQueueCommand) or bActionTaken
        end

        return
end

function illusionLib.OrderIllusionsStop(botBrain, bInterruptAttacks, bQueueCommand)
        local bActionTaken = false

        for _, unitIllusion in pairs(illusionLib.tIllusions) do
                bActionTaken = core.OrderStop(botBrain, unitIllusion, bInterruptAttacks, bQueueCommand) or bActionTaken
        end

        return bActionTaken
end

function illusionLib.OrderIllusionsHold(botBrain, bInterruptAttacks, bQueueCommand)
        local bActionTaken = false

        for _, unitIllusion in pairs(illusionLib.tIllusions) do
                bActionTaken = core.OrderHold(botBrain, unitIllusion, bInterruptAttacks, bQueueCommand) or bActionTaken
        end

        return bActionTaken
end

function illusionLib.OrderIllusionsMoveToPosAndHold(botBrain, vecPosition, bInterruptAttacks, bQueueCommand)
        local bActionTaken = false

        for _, unitIllusion in pairs(illusionLib.tIllusions) do
                if Vector3.Distance2DSq(vecPosition, unitIllusion:GetPosition()) >= illusionLib.nDistanceSqTolerance then
                        bActionTaken = core.OrderMoveToPosAndHold(botBrain, unitIllusion, vecPosition, bInterruptAttacks, bQueueCommand) or bActionTaken
                end
        end

        return bActionTaken
end

function illusionLib.OrderIllusionsMoveToPos(botBrain, vecPosition, bInterruptAttacks, bQueueCommand)
        local bActionTaken = false

        for _, unitIllusion in pairs(illusionLib.tIllusions) do
                if Vector3.Distance2DSq(vecPosition, unitIllusion:GetPosition()) >= illusionLib.nDistanceSqTolerance then
                        bActionTaken = core.OrderMoveToPos(botBrain, unitIllusion, vecPosition, bInterruptAttacks, bQueueCommand) or bActionTaken
                end
        end

        return bActionTaken
end

function illusionLib.OrderIllusionsAttackPosition(botBrain, vecPosition, bInterruptAttacks, bQueueCommand)
        local bActionTaken = false

        for _, unitIllusion in pairs(illusionLib.tIllusions) do
                if Vector3.Distance2DSq(vecPosition, unitIllusion:GetPosition()) >= illusionLib.nDistanceSqTolerance then
                        bActionTaken = core.OrderAttackPosition(botBrain, unitIllusion, vecPosition, bInterruptAttacks, bQueueCommand) or bActionTaken
                end
        end

        return bActionTaken
end
