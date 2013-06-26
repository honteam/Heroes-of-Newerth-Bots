----------------------------------------------
--  _                     ______       _    --
-- | |                    | ___ \     | |   --
-- | |     ___  __ _  ___ | |_/ / ___ | |_  --
-- | |    / _ \/ _` |/ _ \| ___ \/ _ \| __| --
-- | |___|  __/ (_| | (_) | |_/ / (_) | |_  --
-- \_____/\___|\__, |\___/\____/ \___/ \__| --
--              __/ |                       --
--             |___/                        --
----------------------------------------------
--       A HoN Community Bot Project        --
----------------------------------------------
--                Created by:               --
----------------------------------------------
--           kairus101 - Jungling           --
--    DarkFire - Code Cleanup & Abilities   --
--    NoseNuggets - Bot Base Code & Ideas   --
----------------------------------------------
--            Special Thanks To:            --
----------------------------------------------
--       Schnarchnase - Shop & Courier      --
--           fane_maciuca - Ideas           --
----------------------------------------------

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
object.bDebugExecute = false

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

-- uncomment these when advanced shopping is implimented.
--runfile "bots/advancedShopping.lua"
--local shopping = object.shoppingHandler
----shopping.Setup(bReserveItems, bSkipLaneWaiting, bCourierCare, bBuyConsumables, tConsumableOptions)
--shopping.Setup({bReserveItems=true, bWaitForLaneDecision=false, tConsumableOptions=false, bCourierCare=false})

runfile "bots/jungleLib.lua"
local jungleLib = object.jungleLib

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

local sqrtTwo = math.sqrt(2)

BotEcho('loading legionnaire_main...')

---------------------------------
--          Constants          --
---------------------------------

-- Legionnaire
object.heroName = 'Hero_Legionnaire'

-- Item buy order. internal names
behaviorLib.StartingItems =
	{"2 Item_IronBuckler", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems =
	{"Item_Lifetube", "Item_Marchers", "Item_Shield2", "Item_MysticVestments"} -- Shield2 is HotBL
behaviorLib.MidItems =
	{"Item_EnhancedMarchers", "Item_PortalKey"} 
behaviorLib.LateItems =
	{"Item_Excruciator", "Item_SolsBulwark", "Item_DaemonicBreastplate", "Item_BehemothsHeart", "Item_Freeze"} --Excruciator is Barbed Armor, Freeze is Frostwolf's Skull.

-- Skillbuild. 0 is Taunt, 1 is Charge, 2 is Whirling Blade, 3 is Execution, 4 is Attributes
object.tSkills = {
	2, 1, 2, 0, 2,
	3, 2, 1, 1, 1,
	3, 0, 0, 0, 4,
	3, 4, 4, 4, 4,
	4, 4, 4, 4, 4
}

-- Bonus agression points if a skill/item is available for use

object.nTauntUp = 7
object.nChargeUp = 5
object.nDecapUp = 13
object.nPortalKeyUp = 7
object.nBarbedArmorUp = 7

-- Bonus agression points that are applied to the bot upon successfully using a skill/item

object.nTauntUse = 13
object.nChargeUse = 12
object.nDecapUse = 18
object.nPortalKeyUse = 20
object.nBarbedArmorUse = 18

-- Thresholds of aggression the bot must reach to use these abilities

object.nTauntThreshold = 26
object.nChargeThreshold = 36
object.nDecapThreshold = 38
object.nPortalKeyThreshold = 20

-- Other variables

behaviorLib.nCreepPushbackMul = 0.3
behaviorLib.nTargetPositioningMul = 0.8

behaviorLib.safeTreeAngle = 360

object.nLastTauntTime = 0

------------------------------
--          Skills          --
------------------------------

function object:SkillBuild()
	core.VerboseLog("SkillBuild()")

	local unitSelf = self.core.unitSelf
	if  skills.abilWhirlingBlade == nil then
		skills.abilTaunt = unitSelf:GetAbility(0)
		skills.abilCharge = unitSelf:GetAbility(1)
		skills.abilWhirlingBlade = unitSelf:GetAbility(2)
		skills.abilDecap = unitSelf:GetAbility(3)
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

	if nLevel == 3 then
		jungleLib.currentMaxDifficulty = 90
	elseif nLevel == 5 then
		jungleLib.currentMaxDifficulty = 100
	elseif nLevel == 7 then
		jungleLib.currentMaxDifficulty = 130
	elseif nLevel == 10 then
		jungleLib.currentMaxDifficulty = 150
	elseif nLevel >= 12 then
		jungleLib.currentMaxDifficulty = 260
	end
end

------------------------------------------
--          FindItems Override          --
------------------------------------------

local function funcFindItemsOverride(botBrain)
	local bUpdated = object.FindItemsOld(botBrain)

	if core.itemPortalKey ~= nil and not core.itemPortalKey:IsValid() then
		core.itemPortalKey = nil
	end

	if core.itemGhostMarchers ~= nil and not core.itemGhostMarchers:IsValid() then
		core.itemGhostMarchers = nil
	end

	if core.itemBarbedArmor ~= nil and not core.itemBarbedArmor:IsValid() then
		core.itemBarbedArmor = nil
	end

	if bUpdated then
		if core.itemPortalKey and core.itemGhostMarchers and core.itemBarbedArmor then
			return
		end

		local inventory = core.unitSelf:GetInventory(true)
		for slot = 1, 12, 1 do
			local curItem = inventory[slot]
			if curItem then
				if core.itemPortalKey == nil and curItem:GetName() == "Item_PortalKey" then
					core.itemPortalKey = core.WrapInTable(curItem)
				elseif core.itemGhostMarchers == nil and curItem:GetName() == "Item_EnhancedMarchers" then
					core.itemGhostMarchers = core.WrapInTable(curItem)
				elseif core.itemBarbedArmor == nil and curItem:GetName() == "Item_Excruciator" then
					core.itemBarbedArmor = core.WrapInTable(curItem)
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
	
	jungleLib.assess(self)
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
		if EventData.InflictorName == "Ability_Legionnaire1" then
			nAddBonus = nAddBonus + object.nTauntUse
		elseif EventData.InflictorName == "Ability_Legionnaire2" then
			nAddBonus = nAddBonus + object.nChargeUse
		elseif EventData.InflictorName == "Ability_Legionnaire4" then
			nAddBonus = nAddBonus + object.nDecapUse
		end
	elseif EventData.Type == "Item" then
		if core.itemPortalKey ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemPortalKey:GetName() then
			nAddBonus = nAddBonus + self.nPortalKeyUse
		elseif core.itemBarbedArmor ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemBarbedArmor:GetName() then
			nAddBonus = nAddBonus + self.nBarbedArmorUse
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
	
	if skills.abilTaunt:CanActivate() then
		nUtility = nUtility + object.nTauntUp
	end
	
	if skills.abilCharge:CanActivate() then
		nUtility = nUtility + object.nChargeUp
	end

	if skills.abilDecap:CanActivate() then
		nUtility = nUtility + object.nDecapUp
	end
	
	if object.itemPortalKey and object.itemPortalKey:CanActivate() then
		nUtility = nUtility + object.nPortalKeyUp
	end

	if object.itemBarbedArmor and object.itemBarbedArmor:CanActivate() then
		nUtility = nUtility + object.nBarbedArmorUp
	end
	
	return nUtility
end

behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride

-----------------------------------
--          Taunt Logic          --
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

local function getTauntRadius()
	return 300
end

-----------------------------------
--          Decap Logic          --
-----------------------------------

local function getDecapKillThreshold()
	local nSkillLevel = skills.abilDecap:GetLevel()

	if nSkillLevel == 1 then
		return 300
	elseif nSkillLevel == 2 then
		return 450
	elseif nSkillLevel == 3 then
		return 600
	else
		return nil
	end
end

----------------------------------------
--          Portal Key Logic          --
----------------------------------------

-- Returns the best position to Portal Key - Taunt combo
-- Returns nil if there are no enemies or there is no group with enough targets in it
local function getBestPortalKeyTauntPosition(botBrain, vecMyPosition, nMinimumTargets)
	if nMinimumTargets == nil then
		nMinimumTargets = 1
	end

	local tEnemyHeroes = core.localUnits["EnemyHeroes"]
	if tEnemyHeroes and core.NumberElements(tEnemyHeroes) >= nMinimumTargets then
		local nTauntRadius = getTauntRadius() - 25
		local tCurrentGroup = {}
		local nCurrentGroupCount = 0
		local tBestGroup = {}
		local nBestGroupCount = 0
		for _, unitTarget in pairs(tEnemyHeroes) do
			local vecTargetPosition = unitTarget:GetPosition()
			for _, unitOtherTarget in pairs(tEnemyHeroes) do
				if Vector3.Distance2DSq(unitOtherTarget:GetPosition(), vecTargetPosition) <= (nTauntRadius * nTauntRadius) then
					tinsert(tCurrentGroup, unitOtherTarget)
				end
			end

			nCurrentGroupCount = #tCurrentGroup
			if nCurrentGroupCount > nBestGroupCount then
				tBestGroup = tCurrentGroup
				nBestGroupCount = nCurrentGroupCount
			end

			tCurrentGroup = {}
		end

		if nBestGroupCount >= nMinimumTargets then
			return core.GetGroupCenter(tBestGroup)
		end
	end

	return nil
end

----------------------------------------
--          Harass Behaviour          --
----------------------------------------

local function HarassHeroExecuteOverride(botBrain)
	
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil then
		return object.harassExecuteOld(botBrain)
	end

	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local nLastHarassUtility = behaviorLib.lastHarassUtil

	local bActionTaken = false

	if unitSelf:HasState("State_Legionnaire_Ability2_Self") then
		-- We are currently charging the enemy
		return true
	end

	-- Portal Key
	if not bActionTaken then
		local itemPortalKey = core.itemPortalKey
		if itemPortalKey and itemPortalKey:CanActivate() and behaviorLib.lastHarassUtil > object.nPortalKeyThreshold then
			local vecBestTauntPosition = getBestPortalKeyTauntPosition(botBrain, vecMyPosition, 2)
			if vecBestTauntPosition then
				-- Port into two or more enemies
				bActionTaken = core.OrderItemPosition(botBrain, unitSelf, itemPortalKey, vecBestTauntPosition)
			else
				-- Port to a single enemy
				local nTauntRadius = getTauntRadius() - 25
				if nTargetDistanceSq > (nTauntRadius * nTauntRadius) then
					bActionTaken = core.OrderItemPosition(botBrain, unitSelf, itemPortalKey, vecTargetPosition)
				end
			end
		end
	end

	-- Taunt
	if not bActionTaken then
		local abilTaunt = skills.abilTaunt
		if abilTaunt:CanActivate() and nLastHarassUtility > botBrain.nTauntThreshold then
			local nRadius = getTauntRadius() - 25
			local tTauntRangeEnemies = filterGroupRange(core.localUnits["EnemyHeroes"], vecMyPosition, nRadius)
			if tTauntRangeEnemies and #tTauntRangeEnemies > 1 then
				-- If there are two or more enemy heroes in range then taunt
				bActionTaken = core.OrderAbility(botBrain, abilTaunt)
			elseif nTargetDistanceSq <= (nRadius * nRadius) then
				-- Otherwise Taunt the target only if they are in range and not disabled
				local bDisabled = unitTarget:IsImmobilized() or unitTarget:IsStunned()
				if not bDisabled then
					bActionTaken = core.OrderAbility(botBrain, abilTaunt)
				end
			end
		end

		if bActionTaken then
		-- Record our last taunt time 
			object.nLastTauntTime = HoN.GetMatchTime()
		end
	end

	-- Barbed Armor
	if not bActionTaken then
		local itemBarbedArmor = core.itemBarbedArmor
		if itemBarbedArmor and itemBarbedArmor:CanActivate() and object.nLastTauntTime + 500 > HoN.GetMatchTime() then
			-- Use Barbed within .5 seconds of taunt
			bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemBarbedArmor)
		end
	end

	-- Charge
	if not bActionTaken then
		local abilCharge = skills.abilCharge
		if abilCharge:CanActivate() and nLastHarassUtility > botBrain.nChargeThreshold then
			local nRange = abilCharge:GetRange()
			if nTargetDistanceSq <= (nRange * nRange) then
				bActionTaken = core.OrderAbilityEntity(botBrain, abilCharge, unitTarget)
			end
		end
	end

	-- Decap
	if not bActionTaken then
		local abilDecap = skills.abilDecap
		if abilDecap:CanActivate() and nLastHarassUtility > botBrain.nDecapThreshold then
			local nRange = abilDecap:GetRange()
			if nTargetDistanceSq <= (nRange * nRange) then
				local nInstantKillThreshold = getDecapKillThreshold()
				if unitTarget:GetHealth() <  nInstantKillThreshold then
					bActionTaken = core.OrderAbilityEntity(botBrain, abilDecap, unitTarget)
				end
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

---------------------------------------
--          Jungle Behavior          --
---------------------------------------
--
-- Utility: 21
-- This is effectively an "idle" behavior
--
-- Execute:
-- Move to unoccupied camps
-- Attack strongest Neutral until they are all dead
--

-------- Global Constants & Variables --------
behaviorLib.nCreepAggroUtility = 0
behaviorLib.nRecentDamageMul = 0.20

jungleLib.nStacking = 0 -- 0 = not, 1 = waiting/attacking 2, = running away
jungleLib.nStackingCamp = 0

jungleLib.currentMaxDifficulty = 70

-------- Behavior Functions --------
function jungleUtility(botBrain)
	if HoN.GetRemainingPreMatchTime() and HoN.GetRemainingPreMatchTime()>40000 then
		return 0
	end
	-- Wait until level 9 to start grouping/pushing/defending
	behaviorLib.nTeamGroupUtilityMul = 0.13 + core.unitSelf:GetLevel() * 0.01
	behaviorLib.pushingCap = 13 + core.unitSelf:GetLevel()
	behaviorLib.nTeamDefendUtilityVal = 13 + core.unitSelf:GetLevel()
	return 21
end

function jungleExecute(botBrain)
	local unitSelf = core.unitSelf
	local debugMode=false

	local vecMyPos = unitSelf:GetPosition()
	local vecTargetPos, nCamp = jungleLib.getNearestCampPos(vecMyPos, 0, jungleLib.currentMaxDifficulty)
	if not vecTargetPos then
		if core.myTeam == HoN.GetHellbourneTeam() then
			return core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, jungleLib.jungleSpots[8].outsidePos)
		else
			return core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, jungleLib.jungleSpots[2].outsidePos)
		end
	end

	if debugMode then core.DrawDebugArrow(vecMyPos, vecTargetPos, 'green') end

	BotEcho(jungleLib.stacking)
	
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPos, vecTargetPos)
	if nTargetDistanceSq > (600 * 600) or jungleLib.nStacking ~= 0 then
		-- Move to the next camp
		local nMins, nSecs = jungleLib.getTime()
		if jungleLib.nStacking ~= 0 or ((nSecs > 40 or nMins == 0) and nTargetDistanceSq < (800 * 800) and nTargetDistanceSq > (400 * 400)) then
			-- Stack the camp if possible
			if nSecs < 53 and (nSecs > 40 or nMins == 0) then
				-- Wait outside the camp
				jungleLib.nStacking = 1
				jungleLib.nStackingCamp = nCamp
				
				return core.OrderMoveToPosAndHoldClamp(botBrain, core.unitSelf, jungleLib.jungleSpots[nCamp].outsidePos, false)
			elseif jungleLib.nStacking == 1 and unitSelf:IsAttackReady() then
				-- Attack the units in the camp
				if nSecs >= 57 then 
					-- Missed our chance to stack
					jungleLib.nStacking = 0 
				end
				
				return core.OrderAttackPosition(botBrain, unitSelf, vecTargetPos,false,false)
			elseif jungleLib.nStacking ~= 0 and nTargetDistanceSq < (1500 * 1500) and nSecs > 50 then
				-- Move away from the units in the camp
				jungleLib.stacking = jungleLib.nStackingCamp
				jungleLib.nStacking = 2
				local vecAwayPos = jungleLib.jungleSpots[jungleLib.nStackingCamp].pos + (jungleLib.jungleSpots[jungleLib.nStackingCamp].outsidePos - jungleLib.jungleSpots[jungleLib.nStackingCamp].pos) * 5
				if debugMode then
					core.DrawXPosition(jungleLib.jungleSpots[jungleLib.nStackingCamp].pos, 'red')
					core.DrawXPosition(jungleLib.jungleSpots[jungleLib.nStackingCamp].outsidePos, 'red')
					core.DrawDebugArrow(jungleLib.jungleSpots[jungleLib.nStackingCamp].pos,vecAwayPos, 'green')
				end

				return core.OrderMoveToPosClamp(botBrain, core.unitSelf, vecAwayPos, false)
			else
				-- Finished stacking
				jungleLib.nStacking = 0
				jungleLib.stacking=0
				return core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, vecTargetPos)
			end
		else
			-- Otherwise just move to camp
			return core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, vecTargetPos)
		end
	else 
		-- Kill neutrals in the camp
		local tUnits = HoN.GetUnitsInRadius(vecMyPos, 800, core.UNIT_MASK_ALIVE + core.UNIT_MASK_UNIT)
		if tUnits then
			-- Find the strongest unit in the camp
			local nHighestHealth = 0
			local unitStrongest = nil
			for _, unitTarget in pairs(tUnits) do
				if unitTarget:GetHealth() > nHighestHealth and unitTarget:IsAlive() then
					unitStrongest = unitTarget
					nHighestHealth = unitTarget:GetHealth()
				end
			end
			
			-- Attack the strongest unit
			if unitStrongest and unitStrongest:GetPosition() then
				local nStrongestTargetDistanceSq = Vector3.Distance2DSq(vecMyPos, unitStrongest:GetPosition())
				return core.OrderAttackClamp(botBrain, unitSelf, unitStrongest, false)
			else
				return core.OrderAttackPosition(botBrain, unitSelf, vecTargetPos, false, false)
			end
		end
	end
	
	return false
end

behaviorLib.jungleBehavior = {}
behaviorLib.jungleBehavior["Utility"] = jungleUtility
behaviorLib.jungleBehavior["Execute"] = jungleExecute
behaviorLib.jungleBehavior["Name"] = "jungle"
tinsert(behaviorLib.tBehaviors, behaviorLib.jungleBehavior)

----------------------------------------
--          Behavior Changes          --
----------------------------------------
function zeroUtility(botBrain)
	return 0
end

behaviorLib.PositionSelfBehavior["Utility"] = zeroUtility
behaviorLib.PreGameBehavior["Utility"] = zeroUtility

-----------------------------------
--          Custom Chat          --
-----------------------------------

core.tKillChatKeys={
    "BUAHAHAHA!",
    "Off with their heads!",
    "I put the meaning into human blender.",
    "You spin me right round!",
    "Did I break your spirit?",
    "You spin my head right round, right round. When ya go down, when ya go down down."
}

core.tDeathChatKeys = {
    "Spinning out of control..",
    "I think I'm gonna throw up...",
    "Stop taunting me!",
    "Off with.....my head?"
}

BotEcho(object:GetName()..' finished loading legionnaire_main')
