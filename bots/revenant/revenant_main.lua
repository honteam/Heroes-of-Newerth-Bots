-------------------------------------------------------------
-----------                     REVENANT BOT                     -------------
----------- Made by NoseNuggets  Version 1.3  -------------
-------------------------------------------------------------
 
local _G = getfenv(0)
local object = _G.object
 
object.myName = object:GetName()
 
object.bRunLogic = true
object.bRunBehaviors = true
object.bUpdates = true
object.bUseShop = true
 
object.bRunCommands     = true
object.bMoveCommands = true
object.bAttackCommands = true
object.bAbilityCommands = true
object.bOtherCommands = true
 
object.bReportBehavior = false
object.bDebugUtility = false
object.bDebugExecute = false
 
object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false
 
object.core     = {}
object.eventsLib = {}
object.metadata = {}
object.behaviorLib = {}
object.skills = {}
 
runfile "bots/core.lua"
runfile "bots/botbraincore.lua"
runfile "bots/eventsLib.lua"
runfile "bots/metadata.lua"
runfile "bots/behaviorLib.lua"
 
local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills
 
local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
        = _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
        = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random
 
local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp
 
local sqrtTwo = math.sqrt(2)
 
BotEcho('loading revenant_main...')
 
--------------------------------
-----Constant Definitions-------
--------------------------------
 
object.heroName = 'Hero_Revenant'
 
behaviorLib.StartingItems =
        {"2 Item_MinorTotem", "Item_HealthPotion", "Item_RunesOfTheBlight", "Item_MarkOfTheNovice"}
behaviorLib.LaneItems =
        {"Item_Marchers", "Item_Steamboots","Item_MysticVestments", "Item_GraveLocket", "2 Item_Weapon1"}
behaviorLib.MidItems =
        {"Item_Silence", "Item_Intelligence7", "Item_HealthMana2"} --Silence is Hellflower --Intelligence7 is SoTM --HealthMana2 is Icon of the Goddess
behaviorLib.LateItems =
        {"Item_BehemothsHeart", 'Item_Damage9'} --Item_Damage9 is Doombringer
 
object.tSkills = {
        2, 0, 2, 0, 2,
        3, 2, 0, 0, 1,
        3, 1, 1, 1, 4,
        3, 4, 4, 4, 4,
        4, 4, 4, 4, 4
}
 
object.nDefileUp = 7
object.nMortificationUp = 5
object.nHellflowerUp = 13
 
object.nDefileUse = 13
object.nMortificationUse = 12
object.nHellflowerUse = 18
 
object.nDefileThreshold = 26
object.nMortificationThreshold = 36
object.nHellflowerThreshold = 38
 
----------------------------------
------Bot Function Overrides------
----------------------------------
 
function object:SkillBuild()
        core.VerboseLog("SkillBuild()")
 
        local unitSelf = self.core.unitSelf
        if  skills.abilDefile == nil then
                skills.abilDefile = unitSelf:GetAbility(0)
                skills.abilMortification = unitSelf:GetAbility(1)
                skills.abilShroud = unitSelf:GetAbility(2)
                skills.abilManifestation = unitSelf:GetAbility(3)
                skills.abilAttributeBoost = unitSelf:GetAbility(4)
        end
        if unitSelf:GetAbilityPointsAvailable() <= 0 then
                return
        end
 
 
        local nLev = unitSelf:GetLevel()
        local nLevPts = unitSelf:GetAbilityPointsAvailable()
        for i = nLev, nLev+nLevPts do
                unitSelf:GetAbility( object.tSkills[i] ):LevelUp()
        end
end
 
------------------------------------
------OncombatEvent Override--------
------------------------------------
 
function object:oncombateventOverride(EventData)
        self:oncombateventOld(EventData)
 
        local nAddBonus = 0
 
        if EventData.Type == "Ability" then
                if EventData.InflictorName == "Ability_Revenant2" then
                        nAddBonus = nAddBonus + object.nMortificationUse
                elseif EventData.InflictorName == "Ability_Revenant1" then
                        nAddBonus = nAddBonus + object.nDefileUse
                end
        elseif EventData.Type == "Item" then
                if core.itemHellflower ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemHellflower:GetName() then
                        nAddBonus = nAddBonus + self.nHellflowerUse
                end
        end
 
        if nAddBonus > 0 then
                core.DecayBonus(self)
                core.nHarassBonus = core.nHarassBonus + nAddBonus
        end
 
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent = object.oncombateventOverride
 
-----------------------------------------
------CustomHarassUtility Override-------
-----------------------------------------
 
 
local function CustomHarassUtilityFnOverride(hero)
        local nUtil = 0
 
        if skills.abilDefile:CanActivate() then
                nUtil = nUtil + object.nDefileUp
        end
 
        if skills.abilMortification:CanActivate() then
                nUtil = nUtil + object.nMortificationUp
        end
 
        if object.itemHellflower and object.itemHellflower:CanActivate() then
                nUtil = nUtil + object.nHellflowerUp
        end
 
        return nUtil
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride
 
-------------------------------
------FindItems Override-------
-------------------------------
 
local function funcFindItemsOverride(botBrain)
        local bUpdated = object.FindItemsOld(botBrain)
 
        if core.itemHellflower ~= nil and not core.itemHellflower:IsValid() then
                core.itemHellflower = nil
        end
 
        if bUpdated then
                if core.itemHellflower then
                        return
                end
 
                local inventory = core.unitSelf:GetInventory(true)
                for slot = 1, 12, 1 do
                        local curItem = inventory[slot]
                        if curItem then
                                if core.itemHellflower == nil and curItem:GetName() == "Item_Silence" then
                                        core.itemHellflower = core.WrapInTable(curItem)
                                end
                        end
                end
        end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride
 
-----------------------------
------Harass behaviour-------
-----------------------------
 
local function HarassHeroExecuteOverride(botBrain)
 
        local unitTarget = behaviorLib.heroTarget
        if unitTarget == nil then
                return object.harassExecuteOld(botBrain)  --Target is invalid, move on to the next behavior
        end
 
 
        local unitSelf = core.unitSelf
        local vecMyPosition = unitSelf:GetPosition()
 
        local vecTargetPosition = unitTarget:GetPosition()
        local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
 
 
        local nLastHarassUtility = behaviorLib.lastHarassUtil
        local bActionTaken = false
 
        if core.CanSeeUnit(botBrain, unitTarget) then
                local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:IsPerplexed()
                core.FindItems()
                local itemHellflower = core.itemHellflower
 
                -- Silence - on unit.
                if not bActionTaken and not bTargetVuln and itemHellflower and itemHellflower:CanActivate() and nLastHarassUtility > botBrain.nHellflowerThreshold then
                        local nRange = itemHellflower:GetRange()
                        if nTargetDistanceSq < (nRange*nRange) then
                                bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemHellflower, unitTarget)
                        end
                end
 
                -- Mortification
                local abilMortification = skills.abilMortification
                if abilMortification:CanActivate() and nLastHarassUtility > botBrain.nMortificationThreshold then
                        local nRange = abilMortification:GetRange()
                        if nTargetDistanceSq < (nRange * nRange) then
                                bActionTaken = core.OrderAbilityEntity(botBrain, abilMortification, unitTarget, nLastHarassUtility)
                        end
                end
        end
 
        -- Defile
        local abilDefile = skills.abilDefile
        if abilDefile:CanActivate() and nLastHarassUtility > botBrain.nDefileThreshold then
                local nRange = abilDefile:GetRange()
                if nTargetDistanceSq < (nRange * nRange) then
                        bActionTaken = core.OrderAbilityEntity(botBrain, abilDefile, unitSelf, nLastHarassUtility)
                end
        end
 
 
        if not bActionTaken then
                return object.harassExecuteOld(botBrain)
        end
 
        return bActionTaken
end
 
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride
 
---------------------------------------------
----     RetreatFromThreat Override       ----
---------------------------------------------
object.nRetreatStealthThreshold = 50
 
function funcRetreatFromThreatExecuteOverride(botBrain)
        local bDebugEchos = false
 
        local bActionTaken = false
 
        local unitSelf = core.unitSelf
 
        local abilShroud = skills.abilShroud
 
        if abilShroud and abilShroud:CanActivate() and behaviorLib.lastRetreatUtil >= object.nRetreatStealthThreshold then
                bActionTaken = core.OrderAbilityEntity(botBrain, abilShroud, unitSelf)
        end
 
        if not bActionTaken then
                return object.RetreatFromThreatExecuteOld(botBrain)
        end
 
        return bActionTaken
end
object.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatExecute
behaviorLib.RetreatFromThreatBehavior["Execute"] = funcRetreatFromThreatExecuteOverride
 
 
---------------------------------------------
----    DontBreakInvis Behavior           ----
---------------------------------------------
 
function behaviorLib.DontBreakInvisUtility(botBrain)
 
        local unitSelf = core.unitSelf
 
        nUtility = 0
 
        if unitSelf:HasState("State_Revenant_Ability3") and unitSelf:GetHealthPercent() < 0.25 and core.NumberElements(core.localUnits["EnemyHeroes"]) then
                nUtility = 45
        end
 
        return nUtility
end
behaviorLib.DontBreakInvisBehavior = {}
behaviorLib.DontBreakInvisBehavior["Utility"] = behaviorLib.DontBreakInvisUtility
behaviorLib.DontBreakInvisBehavior["Execute"] = behaviorLib.HealAtWellExecute
behaviorLib.DontBreakInvisBehavior["Name"] = "DontBreakInvis"
tinsert(behaviorLib.tBehaviors, behaviorLib.DontBreakInvisBehavior)
 
 
---------------------------------------------
----      Revenant's Help Behaviour       ----
----    Util:                                                   ----
----    Execute: Use Shroud                       ----
---------------------------------------------
 
behaviorLib.nShroudUtilityMul = 0.8
behaviorLib.nShroudHelpHealthUtilityMul = 1.0
behaviorLib.nShroudTimeToLiveUtilityMul = 0.5
 
 
function behaviorLib.ShroudHelpHealthUtilityFn(unitHero)
        local nUtility = 0
 
        local nYIntercept = 100
        local nXIntercept = 100
        local nOrder = 2
 
        nUtility = core.ExpDecay(unitHero:GetHealthPercent() * 100, nYIntercept, nXIntercept, nOrder)
 
        return nUtility
end
 
function behaviorLib.TimeToLiveUtilityFn(unitHero)
        local nUtility = 0
        local nTimeToLive = 9999
 
        if unitHero.bIsMemoryUnit then
                local nHealthVelocity = unitHero:GetHealthVelocity()
                local nHealth = unitHero:GetHealth()
                if nHealthVelocity < 0 then
                        nTimeToLive = nHealth / (-1 * nHealthVelocity)
 
                        local nYIntercept = 100
                        local nXIntercept = 20
                        local nOrder = 2
                        nUtility = core.ExpDecay(nTimeToLive, nYIntercept, nXIntercept, nOrder)
                end
        end
 
        nUtility = Clamp(nUtility, 0, 100)
 
        return nUtility, nTimeToLive
end
 
behaviorLib.nShroudCostBonus = 10
behaviorLib.nShroudCostBonusCooldownThresholdMul = 4.0
function behaviorLib.AbilityCostBonusFn(unitSelf, ability)
        local bDebugEchos = false
 
        local nCost = ability:GetManaCost()
        local nCooldownMS = ability:GetCooldownTime()
        local nRegen = unitSelf:GetManaRegen()
 
        local nTimeToRegenMS = nCost / nRegen * 1000
 
        if nTimeToRegenMS < nCooldownMS * behaviorLib.nShroudCostBonusCooldownThresholdMul then
                return behaviorLib.nShroudCostBonus
        end
 
        return 0
end
 
behaviorLib.nShroudTimeToLive = nil
behaviorLib.nShroudTimeToLiveThreshold = 4
function behaviorLib.ShroudHelpUtility(botBrain)
        local bDebugEchos = false
 
        local nUtility = 0
 
        local abilShroud = skills.abilShroud
        local unitSelf = core.unitSelf
 
        behaviorLib.unitShroudTarget = nil
 
        local nHighestUtility = 0
        local unitTarget = nil
        local nTargetTimeToLive = nil
        if abilShroud:CanActivate() then
                local tTargets = core.CopyTable(core.localUnits["AllyHeroes"])
                tTargets[unitSelf:GetUniqueID()] = unitSelf
                for key, hero in pairs(tTargets) do
                        if hero:GetUniqueID() ~= unitSelf:GetUniqueID() or core.GetCurrentBehaviorName(botBrain) ~= "HealAtWell" then
                                local nCurrentUtility = 0
 
                                local nShroudUtility = behaviorLib.ShroudHelpHealthUtilityFn(hero) * behaviorLib.nShroudHelpHealthUtilityMul
                                local nTimeToLiveUtility = nil
                                local nCurrentTimeToLive = nil
                                nTimeToLiveUtility, nCurrentTimeToLive = behaviorLib.TimeToLiveUtilityFn(hero)
                                nTimeToLiveUtility = nTimeToLiveUtility * behaviorLib.nShroudTimeToLiveUtilityMul
                                nCurrentUtility = nShroudUtility + nTimeToLiveUtility
 
                                if nCurrentUtility > nHighestUtility then
                                        nHighestUtility = nCurrentUtility
                                        nTargetTimeToLive = nCurrentTimeToLive
                                        unitTarget = hero
                                end
                        end
                end
 
                if unitTarget and abilShroud:CanActivate() and nTargetTimeToLive <= behaviorLib.nShroudTimeToLiveThreshold then
                        local nCostBonus = behaviorLib.AbilityCostBonusFn(core.unitSelf, abilShroud)
 
                        nUtility = nHighestUtility + nCostBonus
                end
 
                if nUtility ~= 0 then
                        behaviorLib.unitShroudTarget = unitTarget
                        behaviorLib.nShroudTimeToLive = nTargetTimeToLive
                end
        end
 
        nUtility = nUtility * behaviorLib.nShroudUtilityMul
 
        return nUtility
end
 
function behaviorLib.ShroudHelpExecute(botBrain)
 
        local unitShroudTarget = behaviorLib.unitShroudTarget
        local nShroudTimeToLive = behaviorLib.nShroudTimeToLive
        local bActionTaken = false
        local abilShroud = skills.abilShroud
 
        if unitShroudTarget and abilShroud:CanActivate() and nShroudTimeToLive <= behaviorLib.nShroudTimeToLiveThreshold then
                bActionTaken = core.OrderAbilityEntity(botBrain, abilShroud, unitShroudTarget)
        end
 
        return bActionTaken
end
behaviorLib.ShroudHelpBehavior = {}
behaviorLib.ShroudHelpBehavior["Utility"] = behaviorLib.ShroudHelpUtility
behaviorLib.ShroudHelpBehavior["Execute"] = behaviorLib.ShroudHelpExecute
behaviorLib.ShroudHelpBehavior["Name"] = "ShroudHelp"
tinsert(behaviorLib.tBehaviors, behaviorLib.ShroudHelpBehavior)
 
 
--------------------------------------------------
--      SoulReapers's Predictive Last Hitting Helper
--
--      Assumes that you have vision on the creep
--      passed in to the function
--
--      Developed by paradox870
--------------------------------------------------
local function GetAttackDamageOnCreep(botBrain, unitCreepTarget)
 
                if not unitCreepTarget or not core.CanSeeUnit(botBrain, unitCreepTarget) then
                        return nil
                end
 
                local unitSelf = core.unitSelf
 
                --Get positioning information
                local vecSelfPos = unitSelf:GetPosition()
                local vecTargetPos = unitCreepTarget:GetPosition()
 
                --Get projectile info
                local nProjectileSpeed = unitSelf:GetAttackProjectileSpeed()
                local nProjectileTravelTime = Vector3.Distance2D(vecSelfPos, vecTargetPos) / nProjectileSpeed
                if bDebugEchos then BotEcho ("Projectile travel time: " .. nProjectileTravelTime ) end
 
                local nExpectedCreepDamage = 0
                local nExpectedTowerDamage = 0
                local tNearbyAttackingCreeps = nil
                local tNearbyAttackingTowers = nil
 
                --Get the creeps and towers on the opposite team
                -- of our target
                if unitCreepTarget:GetTeam() == unitSelf:GetTeam() then
                        tNearbyAttackingCreeps = core.localUnits['EnemyCreeps']
                        tNearbyAttackingTowers = core.localUnits['EnemyTowers']
                else
                        tNearbyAttackingCreeps = core.localUnits['AllyCreeps']
                        tNearbyAttackingTowers = core.localUnits['AllyTowers']
                end
 
                --Determine the damage expected on the creep by other creeps
                for i, unitCreep in pairs(tNearbyAttackingCreeps) do
                        if unitCreep:GetAttackTarget() == unitCreepTarget then
                                local nCreepAttacks = 1 + math.floor(unitCreep:GetAttackSpeed() * nProjectileTravelTime)
                                nExpectedCreepDamage = nExpectedCreepDamage + unitCreep:GetFinalAttackDamageMin() * nCreepAttacks
                        end
                end
 
                --Determine the damage expected on the creep by other towers
                for i, unitTower in pairs(tNearbyAttackingTowers) do
                        if unitTower:GetAttackTarget() == unitCreepTarget then
                                local nTowerAttacks = 1 + math.floor(unitTower:GetAttackSpeed() * nProjectileTravelTime)
                                nExpectedTowerDamage = nExpectedTowerDamage + unitTower:GetFinalAttackDamageMin() * nTowerAttacks
                        end
                end
 
                return nExpectedCreepDamage + nExpectedTowerDamage
end
 
function GetCreepAttackTargetOverride(botBrain, unitEnemyCreep, unitAllyCreep) --called pretty much constantly
                local bDebugEchos = false
 
                --Get info about self
                local unitSelf = core.unitSelf
                local nDamageMin = unitSelf:GetFinalAttackDamageMin()
 
                if unitEnemyCreep and core.CanSeeUnit(botBrain, unitEnemyCreep) then
                        local nTargetHealth = unitEnemyCreep:GetHealth()
                        --Only attack if, by the time our attack reaches the target
                        -- the damage done by other sources brings the target's health
                        -- below our minimum damage
                        if nDamageMin >= (nTargetHealth - GetAttackDamageOnCreep(botBrain, unitEnemyCreep)) then
                                if bDebugEchos then BotEcho("Returning an enemy") end
                                return unitEnemyCreep
                        end
                end
 
                if unitAllyCreep then
                        local nTargetHealth = unitAllyCreep:GetHealth()
 
                        --Only attack if, by the time our attack reaches the target
                        -- the damage done by other sources brings the target's health
                        -- below our minimum damage
                        if nDamageMin >= (nTargetHealth - GetAttackDamageOnCreep(botBrain, unitAllyCreep)) then
                                local bActuallyDeny = true
 
                                --[Difficulty: Easy] Don't deny
                                if core.nDifficulty == core.nEASY_DIFFICULTY then
                                        bActuallyDeny = false
                                end
 
                                -- [Tutorial] Hellbourne *will* deny creeps after shit gets real
                                if core.bIsTutorial and core.bTutorialBehaviorReset == true and core.myTeam == HoN.GetHellbourneTeam() then
                                        bActuallyDeny = true
                                end
 
                                if bActuallyDeny then
                                        if bDebugEchos then BotEcho("Returning an ally") end
                                        return unitAllyCreep
                                end
                        end
                end
 
                return nil
end
-- overload the behaviour stock function with custom
object.getCreepAttackTargetOld = behaviorLib.GetCreepAttackTarget
behaviorLib.GetCreepAttackTarget = GetCreepAttackTargetOverride
 
function AttackCreepsExecuteOverride(botBrain)
                local unitSelf = core.unitSelf
                local unitCreepTarget = core.unitCreepTarget
 
                if unitSelf:HasState("State_Revenant_Ability3") then
                        return false
                end
 
                if unitCreepTarget and core.CanSeeUnit(botBrain, unitCreepTarget) then
                        --Get info about the target we are about to attack
                        local vecSelfPos = unitSelf:GetPosition()
                        local vecTargetPos = unitCreepTarget:GetPosition()
                        local nDistSq = Vector3.Distance2DSq(vecSelfPos, vecTargetPos)
                        local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, currentTarget, true)
 
                        --Only attack if, by the time our attack reaches the target
                        -- the damage done by other sources brings the target's health
                        -- below our minimum damage, and we are in range and can attack right now
                        if nDistSq < nAttackRangeSq and unitSelf:IsAttackReady() then
                                core.OrderAttackClamp(botBrain, unitSelf, unitCreepTarget)
 
                        --Otherwise get within 70% of attack range if not already
                        -- This will decrease travel time for the projectile
                        elseif (nDistSq > nAttackRangeSq * 0.5) then
                                local vecDesiredPos = core.AdjustMovementForTowerLogic(vecTargetPos)
                                core.OrderMoveToPosClamp(botBrain, unitSelf, vecDesiredPos, false)
 
                        --If within a good range, just hold tight
                        else
                                core.OrderHoldClamp(botBrain, unitSelf, false)
                        end
                else
                        return false
                end
end
object.AttackCreepsExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.AttackCreepsBehavior["Execute"] = AttackCreepsExecuteOverride
 
---------------------------------------
---              Personality                     ---
---------------------------------------
 
core.tKillChatKeys = {
        "BOO!",
        "Scream more for me!",
        "You can't kill what is already dead!",
        "Death consumes you!",
        "Defiled!",
        "May the Afterlife consume you."
}
 
core.tDeathChatKeys = {
        "I thought I was dead already...",
        "I haven't reached my scare quota yet..",
        "I'll be back! Don't you worry...",
        "Back to the grave...",
        "I dissipate....",
        "Cast to the winds...."
}
 
BotEcho(object:GetName()..' finished loading revenant_main')