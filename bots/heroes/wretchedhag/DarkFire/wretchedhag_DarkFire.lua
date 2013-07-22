-----------------------------------------
--  _   _            ______       _    --
-- | | | |           | ___ \     | |   --
-- | |_| | __ _  __ _| |_/ / ___ | |_  --
-- |  _  |/ _` |/ _` | ___ \/ _ \| __| --
-- | | | | (_| | (_| | |_/ / (_) | |_  --
-- \_| |_/\__,_|\__, \____/ \___/ \__| --
--               __/ |                 --
--              |___/  -By: DarkFire   --
-----------------------------------------
 
------------------------------------------
--          Bot Initialization          --
------------------------------------------
 
local _G = getfenv(0)
local object = _G.object
 
object.myName = object:GetName()
 
object.bRunLogic = true
object.bRunBehaviors = true
object.bUpdates = true
object.bUseShop = true
 
object.bRunCommands = true
object.bMoveCommands = true
object.bAttackCommands = true
object.bAbilityCommands = true
object.bOtherCommands = true
 
object.bReportBehavior = false
object.bDebugUtility = false
 
object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false
 
object.core = {}
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
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, asin, max, random
        = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.asin, _G.math.max, _G.math.random
 
local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp
 
BotEcho('loading wretchedhag_DarkFire...')
 
---------------------------------
--          Constants          --
---------------------------------
 
-- Wretched Hag
object.heroName = 'Hero_BabaYaga'
 
-- Item buy order. internal names  
behaviorLib.StartingItems  = {"Item_PretendersCrown", "Item_MarkOfTheNovice", "Item_RunesOfTheBlight", "Item_HealthPotion"}
behaviorLib.LaneItems  = {"Item_Marchers", "Item_GraveLocket", "Item_Steamboots", "2 Item_Scarab", "Item_Silence"}
behaviorLib.MidItems  = {"Item_Protect", "Item_GrimoireOfPower"}
behaviorLib.LateItems  = {"Item_Intelligence7", "Item_Morph"}
 
-- Skillbuild table, 0=q, 1=w, 2=e, 3=r, 4=attri
object.tSkills = {
        1, 2, 2, 0, 2,
        3, 2, 0, 0, 0,
        3, 1, 1, 1, 4,
        3, 4, 4, 4, 4,
        4, 4, 4, 4, 4
}
 
-- Bonus agression points if a skill/item is available for use
 
object.nHauntUp = 8
object.nScreamUp = 12
object.nBlastUp = 26
object.nHellflowerUp = 12
object.nSheepstickUp = 15
 
-- Bonus agression points that are applied to the bot upon successfully using a skill/item
 
object.nHauntUse = 10
object.nBlinkUse = 8
object.nScreamUse = 16
object.nBlastUse = 24
object.nHellflowerUse = 15
object.nSheepstickUse = 18
 
-- Thresholds of aggression the bot must reach to use these abilities
 
object.nHauntThreshold = 23
object.nBlinkThreshold = 31
object.nScreamThreshold = 26
object.nBlastThreshold = 36
object.nHellflowerThreshold = 23
object.nSheepstickThreshold = 29
 
-- Other variables
 
behaviorLib.nCreepPushbackMul = 0.55
behaviorLib.nPositionHeroInfluenceMul = 3.75
 
------------------------------
--          Skills          --
------------------------------
 
function object:SkillBuild()
        local unitSelf = self.core.unitSelf
        if  skills.abilHaunt == nil then
                skills.abilHaunt = unitSelf:GetAbility(0)
                skills.abilBlink = unitSelf:GetAbility(1)
                skills.abilScream = unitSelf:GetAbility(2)
                skills.abilBlast = unitSelf:GetAbility(3)
                skills.abilAttributeBoost = unitSelf:GetAbility(4)
        end
 
        local nPoints = unitSelf:GetAbilityPointsAvailable()
        if nPoints <= 0 then
                return
        end
 
        local nLevel = unitSelf:GetLevel()
        for i = nLevel, (nLevel + nPoints) do
                unitSelf:GetAbility( self.tSkills[i] ):LevelUp()
        end
end
 
------------------------------------------
--          FindItems Override          --
------------------------------------------
 
local function funcFindItemsOverride(botBrain)
        local bUpdated = object.FindItemsOld(botBrain)
 
        if core.itemSteamboots ~= nil and not core.itemSteamboots:IsValid() then
                core.itemSteamboots = nil
        end
 
        if core.itemHellflower ~= nil and not core.itemHellflower:IsValid() then
                core.itemHellflower = nil
        end
 
        if core.itemSheepstick ~= nil and not core.itemSheepstick:IsValid() then
                core.itemSheepstick = nil
        end
         
        if core.itemSotM ~= nil and not core.itemSotM:IsValid() then
                core.itemSotM = nil
        end
       
        if bUpdated then
                --only update if we need to
                if core.itemSteamboots and core.itemHellflower and core.itemSheepstick and core.itemSotM then
                        return
                end
         
                local inventory = core.unitSelf:GetInventory(true)
                for slot = 1, 12, 1 do
                        local curItem = inventory[slot]
                        if curItem then
                                if core.itemSteamboots == nil and curItem:GetName() == "Item_Steamboots" then
                                        core.itemSteamboots = core.WrapInTable(curItem)
                                elseif core.itemHellflower == nil and curItem:GetName() == "Item_Silence" then
                                        core.itemHellflower = core.WrapInTable(curItem)
                                elseif core.itemSheepstick == nil and curItem:GetName() == "Item_Morph" then
                                        core.itemSheepstick = core.WrapInTable(curItem)
                                elseif core.itemSotM == nil and curItem:GetName() == "Item_Intelligence7" then
                                        core.itemSotM = core.WrapInTable(curItem)
                                end
                        end
                end
        end
end
 
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride
 
----------------------------------------
--          OnThink Override          --
----------------------------------------
 
function object:onthinkOverride(tGameVariables)
        self:onthinkOld(tGameVariables)
 
        -- Toggle Steamboots for more Health/Mana
        local itemSteamboots = core.itemSteamboots
        if itemSteamboots and itemSteamboots:CanActivate() then
                local unitSelf = core.unitSelf
                local sKey = itemSteamboots:GetActiveModifierKey()
                if sKey == "str" then
                        -- Toggle away from STR if health is high enough
                        if unitSelf:GetHealthPercent() > .65 then
                                self:OrderItem(itemSteamboots.object, false)
                        end
                elseif sKey == "agi" then
                        -- Always toggle past AGI
                        self:OrderItem(itemSteamboots.object, false)
                elseif sKey == "int" then
                        -- Toggle away from INT if health gets too low
                        if unitSelf:GetHealthPercent() < .45 then
                                self:OrderItem(itemSteamboots.object, false)
                        end
                end
        end
end
 
object.onthinkOld = object.onthink
object.onthink = object.onthinkOverride
 
----------------------------------------------
--          OnCombatEvent Override          --
----------------------------------------------
 
function object:oncombateventOverride(EventData)
        self:oncombateventOld(EventData)
 
        local nAddBonus = 0
 
        if EventData.Type == "Ability" then
                if EventData.InflictorName == "Ability_BabaYaga1" then
                        nAddBonus = nAddBonus + self.nHauntUse
                elseif EventData.InflictorName == "Ability_BabaYaga2" then
                        local sCurrentBehavior = core.GetCurrentBehaviorName(self)
                        if sCurrentBehavior ~= "RetreatFromThreat" and sCurrentBehavior ~= "HealAtWell" then
                                nAddBonus = nAddBonus + self.nBlinkUse
                        end
                elseif EventData.InflictorName == "Ability_BabaYaga3" then
                        nAddBonus = nAddBonus + self.nScreamUse
                elseif EventData.InflictorName == "Ability_BabaYaga4" then
                        nAddBonus = nAddBonus + self.nBlastUse
                end
        elseif EventData.Type == "Item" then
                if core.itemHellflower ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemHellflower:GetName() then
                        nAddBonus = nAddBonus + self.nHellflowerUse
                elseif core.itemSheepstick ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemSheepstick:GetName() then
                        nAddBonus = nAddBonus + self.nSheepstickUse
                end
        end
 
        if nAddBonus > 0 then
                core.DecayBonus(self)
                core.nHarassBonus = core.nHarassBonus + nAddBonus
        end
end
 
object.oncombateventOld = object.oncombatevent
object.oncombatevent = object.oncombateventOverride
 
----------------------------------------------------
--          CustomHarassUtility Override          --
----------------------------------------------------
 
local function CustomHarassUtilityFnOverride(hero)
        local nUtility = 0
 
        if skills.abilHaunt:CanActivate() then
                nUtility = nUtility + object.nHauntUp
        end
 
        if skills.abilScream:CanActivate() then
                nUtility = nUtility + object.nScreamUp
        end
 
        if skills.abilBlast:CanActivate() then
                nUtility = nUtility + object.nBlastUp
        end
 
        if object.itemHellflower and object.itemHellflower:CanActivate() then
                nUtility = nUtility + object.nHellflowerUp
        end
 
        if object.itemSheepstick and object.itemSheepstick:CanActivate() then
                nUtility = nUtility + object.nSheepstickUp
        end
 
        return nUtility
end
 
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride  
 
-----------------------------------
--          Haunt Logic          --
-----------------------------------
 
-- Returns the magic damage Haunt will do
local function hauntDamage()
        local nHauntLevel = skills.abilHaunt:GetLevel()
       
        if nHauntLevel == 1 then
                return 100
        elseif nHauntLevel == 2 then
                return 170
        elseif nHauntLevel == 3 then
                return 270
        elseif nHauntLevel == 4 then
                return 350
        end
 
        return nil
end
 
------------------------------------
--          Scream Logic          --
------------------------------------
 
-- Returns the radius of Scream
local function screamRadius()
        local nSkillLevel = skills.abilScream:GetLevel()
       
        if nSkillLevel == 1 then
                return 425
        elseif nSkillLevel == 2 then
                return 450
        elseif nSkillLevel == 3 then
                return 475
        elseif nSkillLevel == 4 then
                return 500
        end
 
        return nil
end
 
-----------------------------------
--          Blast Logic          --
-----------------------------------
 
-- Filters a group to be within a given range. Modified from St0l3n_ID's Chronos bot
local function filterGroupRange(tGroup, vecCenter, nRange)
        if tGroup and vecCenter and nRange then
                local tResult = {}
                for _, unitTarget in pairs(tGroup) do
                        if Vector3.Distance2DSq(unitTarget:GetPosition(), vecCenter) <= (nRange * nRange) then
                                tinsert(tResult, unitTarget)
                        end
                end    
       
                if #tResult > 0 then
                        return tResult
                end
        end
       
        return nil
end
 
-- Find the angle in degrees between two targets. Modified from St0l3n_ID's AngToTarget code
local function getAngToTarget(vecSelf, vecTarget)
        local nDeltaY = vecTarget.y - vecSelf.y
        local nDeltaX = vecTarget.x - vecSelf.x
 
        local nAng = floor(atan2(nDeltaY, nDeltaX) * 57.2957795131) -- That number is 180 / pi
 
        -- Force the output to be from 0 to 360
        if nAng < 0 then
                nAng = nAng + 360
        end
 
        return nAng
end
 
-- Returns the best direction to use a cone based spell
local function getConeTarget(tLocalTargets, nRange, nDegrees, nMinCount)
        if nMinCount == nil then
                nMinCount = 1
        end
 
        if tLocalTargets and core.NumberElements(tLocalTargets) >= nMinCount then
                local unitSelf = core.unitSelf
                local vecMyPosition = unitSelf:GetPosition()
                local tHeroesInRange = filterGroupRange(tLocalTargets, vecMyPosition, nRange)
                if tHeroesInRange and #tHeroesInRange >= nMinCount then
                        -- Create a list of the directions to each hero in range
                        local tAngleOfHeroesInRange = {}
                        for _, unitEnemyHero in pairs(tHeroesInRange) do
                                local vecEnemyPosition = unitEnemyHero:GetPosition()
                                local vecDirection = Vector3.Normalize(vecEnemyPosition - vecMyPosition)
                                vecDirection = core.RotateVec2DRad(vecDirection, pi / 2)
                       
                                local nHighAngle = getAngToTarget(vecMyPosition, vecEnemyPosition + vecDirection * 100)
                                local nMidAngle = getAngToTarget(vecMyPosition, vecEnemyPosition)
                                local nLowAngle = getAngToTarget(vecMyPosition, vecEnemyPosition - vecDirection * 100)
                               
                                tinsert(tAngleOfHeroesInRange, {nHighAngle, nMidAngle, nLowAngle})
                        end
 
                        local tBestGroup = {}
                        local tCurrentGroup = {}
                        for _, tStartAngles in pairs(tAngleOfHeroesInRange) do
                                local nStartAngle = tStartAngles[1]
                                if nStartAngle >= 270 then
                                        -- Avoid doing calculations near the break in numbers
                                        nStartAngle = nStartAngle - 360
                                end
                               
                                local nEndAngle = nStartAngle + nDegrees
                                for _, tAngles in pairs(tAngleOfHeroesInRange) do
                                        local nHighAngle = tAngles[1]
                                        local nMidAngle = tAngles[2]
                                        local nLowAngle = tAngles[3]
                                        if nStartAngle < 90 or nStartAngle >= 270 then
                                                -- Avoid doing calculations near the break in numbers
                                                if nHighAngle > 180 then
                                                        nHighAngle = nHighAngle - 360
                                                end
                                               
                                                if nMidAngle > 180 then
                                                        nMidAngle = nMidAngle - 360
                                                end
                                               
                                                if nLowAngle > 180 then
                                                        nLowAngle = nLowAngle - 360
                                                end
                                        end
                               
                                        if (nStartAngle <= nMidAngle and nMidAngle <= nEndAngle) or (nHighAngle >= nStartAngle and nLowAngle <= nStartAngle) or (nHighAngle >= nEndAngle and nLowAngle <= nEndAngle) then
                                                tinsert(tCurrentGroup, nMidAngle)
                                        end
                                end
 
                                if #tCurrentGroup > #tBestGroup then
                                        tBestGroup = tCurrentGroup
                                end
 
                                tCurrentGroup = {}
                        end
 
                        local nBestGroupSize = #tBestGroup
                       
                        if nBestGroupSize >= nMinCount then
                                tsort(tBestGroup)
                       
                                local nAvgAngle = (tBestGroup[1] + tBestGroup[nBestGroupSize]) / 2 * 0.01745329251 -- That number is pi / 180
 
                                return Vector3.Create(cos(nAvgAngle), sin(nAvgAngle)) * 500
                        end
                end
        end
 
        return nil
end
 
-- Returns the magic damage that Hag Ult will do
local function blastDamage()
        local itemSotM = core.itemSotM
        local nBlastLevel = skills.abilBlast:GetLevel()
        if itemSotM then
                if nBlastLevel == 1 then
                        return 340
                elseif nBlastLevel == 2 then
                        return 530
                elseif nBlastLevel == 3 then
                        return 725
                end    
        else
                if nBlastLevel == 1 then
                        return 290
                elseif nBlastLevel == 2 then
                        return 430
                elseif nBlastLevel == 3 then
                        return 600
                end    
        end
 
        return nil
end
 
---------------------------------------
--          Harass Behavior          --
---------------------------------------
 
local function HarassHeroExecuteOverride(botBrain)
 
        local unitTarget = behaviorLib.heroTarget
        if unitTarget == nil then
                return object.harassExecuteOld(botBrain)
        end
 
        local nLastHarassUtility = behaviorLib.lastHarassUtil
        local bActionTaken = false
       
        local unitSelf = core.unitSelf
        local vecMyPosition = unitSelf:GetPosition()
        local nMyMana = unitSelf:GetMana()
        local vecTargetPosition = unitTarget:GetPosition()
        local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
        local bTargetDisabled = unitTarget:IsStunned() or unitTarget:IsSilenced()
        local bCanSeeTarget = core.CanSeeUnit(botBrain, unitTarget)
        local nTargetMagicEHP = nil
       
        if bCanSeeTarget then
                nTargetMagicEHP = unitTarget:GetHealth() / (1 - unitTarget:GetMagicResistance())
        end
 
        -- Stop the bot from trying to harass heroes while dead
        if not bActionTaken and not unitSelf:IsAlive() then
                bActionTaken = true
        end
       
        -- Hellflower
        if not bActionTaken then
                local itemHellflower = core.itemHellflower
                if itemHellflower and itemHellflower:CanActivate() and (nMyMana - itemHellflower:GetManaCost()) >= 60 and not bTargetDisabled and bCanSeeTarget and nLastHarassUtility > object.nHellflowerThreshold then
                        local nRange = itemHellflower:GetRange()
                        if nTargetDistanceSq < (nRange * nRange) then
                                bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemHellflower, unitTarget)
                        end
                end
        end
 
        -- Blast
        if not bActionTaken then
                local abilBlast = skills.abilBlast
                if abilBlast:CanActivate() and (nMyMana - abilBlast:GetManaCost()) >= 60 and nLastHarassUtility > object.nBlastThreshold then
                        -- Hag Ult hits 700 Range at 33 degrees
                        local nRange = abilBlast:GetRange()
                        local vecDirection = getConeTarget(core.localUnits["EnemyHeroes"], nRange + 200, 20, 2)
                        if vecDirection then
                                -- Cast towards group center (only if there are 2 or more heroes)
                                bActionTaken = core.OrderAbilityPosition(botBrain, abilBlast, vecMyPosition + vecDirection)
                        elseif nTargetMagicEHP and (nTargetMagicEHP * .85) > blastDamage() then
                                -- Otherwise cast on target
                                nRange = nRange - 75
                                if nTargetDistanceSq < (nRange * nRange) and nTargetDistanceSq > (200 * 200) then
                                        bActionTaken = core.OrderAbilityEntity(botBrain, abilBlast, unitTarget)
                                end
                        end
                end    
        end
       
        -- Haunt
        if not bActionTaken then
                local abilHaunt = skills.abilHaunt
                if abilHaunt:CanActivate() and (nMyMana - abilHaunt:GetManaCost()) >= 60  and bCanSeeTarget and nTargetMagicEHP and (nTargetMagicEHP * .65) > hauntDamage() and nLastHarassUtility > object.nHauntThreshold then
                        local nRange = abilHaunt:GetRange()
                        if nTargetDistanceSq < (nRange * nRange) then
                                bActionTaken = core.OrderAbilityEntity(botBrain, abilHaunt, unitTarget)
                        end
                end
        end
       
        -- Sheepstick
        if not bActionTaken then
                local itemSheepstick = core.itemSheepstick
                if itemSheepstick and itemSheepstick:CanActivate() and (nMyMana - itemSheepstick:GetManaCost()) >= 60  and not bTargetDisabled and bCanSeeTarget and nLastHarassUtility > object.nSheepstickThreshold then
                        local nRange = itemSheepstick:GetRange()
                        if nTargetDistanceSq < (nRange * nRange) then
                                bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemSheepstick, unitTarget)
                        end
                end
        end
         
        -- Blink
        if not bActionTaken then
                local abilBlink = skills.abilBlink
                if abilBlink:CanActivate() and unitSelf:GetLevel() > 1 and (nMyMana - abilBlink:GetManaCost()) >= 60 and nLastHarassUtility > object.nBlinkThreshold and (nMyMana > 200 or unitTarget:GetHealthPercent() < .15) then
                        local nRange = abilBlink:GetRange() + 50
                        if nTargetDistanceSq < (nRange * nRange) and nTargetDistanceSq > (415 * 415) then
                                local unitEnemyWell = core.enemyWell
                                if unitEnemyWell then
                                        -- If possible blink behind the enemy (where behind is defined as the direction from the target to the enemy well)
                                        local vecTargetPointToWell = Vector3.Normalize(unitEnemyWell:GetPosition() - vecTargetPosition)
                                        if vecTargetPointToWell then
                                                bActionTaken = core.OrderAbilityPosition(botBrain, abilBlink, vecTargetPosition + (vecTargetPointToWell * 150))
                                        end
                                end
                        end
                end
        end
       
        -- Scream
        if not bActionTaken then
                local abilScream = skills.abilScream
                if abilScream:CanActivate() and (nMyMana - abilScream:GetManaCost()) >= 60  and nLastHarassUtility > object.nScreamThreshold then
                        local nRadius = screamRadius() - 10
                        if nTargetDistanceSq < (nRadius * nRadius) then
                                bActionTaken = core.OrderAbility(botBrain, abilScream)
                        end
                end
        end
 
        if not bActionTaken then
                return object.harassExecuteOld(botBrain)
        end
       
        return bActionTaken
end
 
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride
 
-------------------------------------------
--          Blink Retreat Logic          --
-------------------------------------------
 
-- Find the angle in radians between two targets. Modified from St0l3n_ID's AngToTarget code
local function getAngToPoint(vecOrigin, vecTarget)
        local nDeltaY = vecTarget.y - vecOrigin.y
        local nDeltaX = vecTarget.x - vecOrigin.x
       
        nAng = atan2(nDeltaY, nDeltaX)
       
        return nAng
end
 
-- Find the point D such that the lenght of CD is equal to nRange
--  A-----D---------B
--   \   /
--    \ /
--     C
-- Where A is the previous node, B is the current node, and C is the Bots position
local function bestPointOnPath(vecA, vecB, nRange, bIgnoreZAxis)
        local vecResult = nil
        local vecC = core.unitSelf:GetPosition()
 
        if bIgnoreZAxis then
                vecA.z = 0
                vecB.z = 0
                vecC.z = 0
        end
       
        local vecAC = vecC - vecA
        local nLengthAC = Vector3.Length(vecAC)
       
        if nLengthAC then
                local nAngleA = core.AngleBetween(vecB - vecA, vecAC)
                if nAngleA then
                        local vecACDirection = Vector3.Normalize(vecA - vecC) * nRange
                        if vecACDirection then
                                local nAngleD = asin((nLengthAC * sin(nAngleA)) / nRange) -- Law of Sines
                                local nAngleC = (pi - nAngleD - nAngleA)
                                local nAngleB = getAngToPoint(vecB, vecC) - getAngToPoint(vecB, vecA) -- This is the angle ABC in the drawing
                                if nAngleB > 0 then
                                        vecResult = vecC + core.RotateVec2DRad(vecACDirection, -nAngleC)
                                else
                                        vecResult = vecC + core.RotateVec2DRad(vecACDirection, nAngleC)
                                end
                                                               
                                if vecResult then
                                        return vecResult
                                end
                        end
                end
        end
       
        return vecResult
end
 
-- Returns the best location to blink when retreating
local function getBlinkRetreatLocation()
        local vecCurrentPosition = core.unitSelf:GetPosition()
        local vecEndPosition = core.allyWell:GetPosition()
        local vecBlinkPosition = nil
       
        -- Get a path from current position back to well
        local tPath = BotMetaData.FindPath(vecCurrentPosition, vecEndPosition)
        if tPath then
                local nIndex = 1
                local nBlinkRange = skills.abilBlink:GetRange()
                local vecPreviousNodePosition = vecCurrentPosition
                local vecNodePosition = nil
                local nDistanceSq = nil
                while nIndex < #tPath do
                        vecNodePosition = tPath[nIndex]:GetPosition()
                        nDistanceSq = Vector3.Distance2DSq(vecCurrentPosition, vecNodePosition)
                        -- Find the first node on the path that is outside of blink range
                        if nDistanceSq > (nBlinkRange * nBlinkRange) then
                                if nIndex == 1 then
                                        vecBlinkPosition = vecNodePosition
                                else
                                        vecBlinkPosition = bestPointOnPath(vecPreviousNodePosition, vecNodePosition, nBlinkRange, true)
                                end
 
                                break
                        end
                       
                        vecPreviousNodePosition = vecNodePosition
                        nIndex = nIndex + 1
                end
        end
 
        return vecBlinkPosition
end
 
--------------------------------------------------
--          RetreatFromThreat Override          --
--------------------------------------------------
 
local function funcRetreatFromThreatExecuteOverride(botBrain)
        local bActionTaken = false
       
        -- Use blink to retreat if possible
        if not bActionTaken then
                local abilBlink = skills.abilBlink
                if abilBlink:CanActivate() and core.unitSelf:GetHealthPercent() < .425 then
                        local vecRetreatPosition = getBlinkRetreatLocation()
                        if vecRetreatPosition then
                                bActionTaken = core.OrderAbilityPosition(botBrain, abilBlink, vecRetreatPosition)
                        else
                                bActionTaken = core.OrderAbilityPosition(botBrain, abilBlink, core.allyWell:GetPosition())
                        end
                end
        end
       
        if not bActionTaken then
                return object.RetreatFromThreatExecuteOld(botBrain)
        end
end
 
object.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatExecute
behaviorLib.RetreatFromThreatBehavior["Execute"] = funcRetreatFromThreatExecuteOverride
 
-------------------------------------------------
--          HealAtWellExecute Overide          --
-------------------------------------------------
 
local function HealAtWellOveride(botBrain)
        local bSuccess = false
        local abilBlink = skills.abilBlink
       
        -- Use blink on way to well
        if abilBlink:CanActivate() then
                local nRange = abilBlink:GetRange()
                local vecAllyWell = core.allyWell:GetPosition()
                local nDistToWellSq = Vector3.Distance2DSq(core.unitSelf:GetPosition(), vecAllyWell)
                if nDistToWellSq > (nRange * nRange) then
                        local vecRetreatPosition = getBlinkRetreatLocation()
                        if vecRetreatPosition then
                                bSuccess = core.OrderAbilityPosition(botBrain, abilBlink, vecRetreatPosition)
                        else
                                bSuccess = core.OrderAbilityPosition(botBrain, abilBlink, vecAllyWell)
                        end
                end
        end
       
        if not bSuccess then
                return object.HealAtWellBehaviorOld(botBrain)
        end
end
 
object.HealAtWellBehaviorOld = behaviorLib.HealAtWellBehavior["Execute"]
behaviorLib.HealAtWellBehavior["Execute"] = HealAtWellOveride
 
-------------------------------------------
--          PushExecute Overide          --
-------------------------------------------
 
-- These are modified from fane_maciuca's Rhapsody Bot
local function AbilityPush(botBrain)
        local bSuccess = false
        local abilScream = skills.abilScream
        local unitSelf = core.unitSelf
        local nMinimumCreeps = 3
       
        -- Stop the bot from trying to farm creeps if the creeps approach the spot where the bot died
        if not unitSelf:IsAlive() then
                return bSuccess
        end
       
        --Don't use Scream if it would put mana too low
        if abilScream:CanActivate() and unitSelf:GetManaPercent() > .32 then
                local tLocalEnemyCreeps = core.localUnits["EnemyCreeps"]
                if core.NumberElements(tLocalEnemyCreeps) > nMinimumCreeps then
                        local vecCenter = core.GetGroupCenter(tLocalEnemyCreeps)
                        if vecCenter then
                                local vecCenterDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecCenter)
                                if vecCenterDistanceSq then
                                        if vecCenterDistanceSq < (90 * 90) then
                                                bSuccess = core.OrderAbility(botBrain, abilScream)
                                        else
                                                bSuccess = core.OrderMoveToPos(botBrain, unitSelf, vecCenter)
                                        end
                                end
                        end
                end
        end
       
        return bSuccess
end
 
local function PushExecuteOverride(botBrain)
        if not AbilityPush(botBrain) then
                return object.PushExecuteOld(botBrain)
        end
end
 
object.PushExecuteOld = behaviorLib.PushBehavior["Execute"]
behaviorLib.PushBehavior["Execute"] = PushExecuteOverride
 
local function TeamGroupBehaviorOverride(botBrain)
        if not AbilityPush(botBrain) then
                return object.TeamGroupBehaviorOld(botBrain)
        end
end
 
object.TeamGroupBehaviorOld = behaviorLib.TeamGroupBehavior["Execute"]
behaviorLib.TeamGroupBehavior["Execute"] = TeamGroupBehaviorOverride
 
BotEcho('finished loading wretchedhag_DarkFire')
