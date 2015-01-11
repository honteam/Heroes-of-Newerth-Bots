--NOTE: Uncomment blocks at 66 and 148 when advanced shopping is approved.
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
--kairus101 - Jungling, TeamBot intergration--
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

--[[
runfile "bots/advancedShopping.lua"
local shopping = object.shoppingHandler
shopping.Setup({bReserveItems=true, bWaitForLaneDecision=true, tConsumableOptions=false, bCourierCare=false})
]]

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

BotEcho('loading legionnaire_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 5, Mid = 1, ShortSolo = 1, LongSolo = 1, ShortSupport = 1, LongSupport = 1, ShortCarry = 3, LongCarry = 2, hero=core.unitSelf}

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
	{"Item_Excruciator", "Item_SolsBulwark", "Item_DaemonicBreastplate", "Item_Intelligence7", "Item_HealthMana2", "Item_BehemothsHeart"} --Excruciator is Barbed Armor, Item_Intelligence7 is staff, Item_HealthMana2 is icon

-- Skillbuild. 0 is Taunt, 1 is Charge, 2 is Whirling Blade, 3 is Execution, 4 is Attributes
object.tSkills = {
	2, 1, 2, 0, 2,
	3, 2, 1, 1, 1,
	3, 0, 0, 0, 4,
	3, 4, 4, 4, 4,
	4, 4, 4, 4, 4
}

-- Bonus agression points if a skill/item is available for use

object.nTauntUp = 10
object.nChargeUp = 8
object.nDecapUp = 20
object.nPortalKeyUp = 10
object.nBarbedArmorUp = 10

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
--  Dynamic Item building   --
------------------------------
--[[
local function legoItemBuilder()
		local debugInfo = false
		if debugInfo then BotEcho("Checking Itembuilder of Lego") end
		local bNewItems = false
	   
		--get itembuild decision table
		local tItemDecisions = shopping.ItemDecisions
		if debugInfo then BotEcho("Found ItemDecisions"..type(tItemDecisions)) end
	   
		--Choose Lane Items
		if not tItemDecisions.Lane then		
	   
				if debugInfo then BotEcho("Choose Startitems") end
			   
				local tLane = core.tMyLane
				if tLane then
						if debugInfo then BotEcho("Found my Lane") end
						local startItems = nil
						if tLane.sLaneName == "jungle" then
								if debugInfo then BotEcho("I will take to the jungle.") end
								startItems = {"2 Item_IronBuckler", "Item_RunesOfTheBlight"}
						else
								if debugInfo then BotEcho("Argh, I am not mid *sob*") end
								startItems = {"Item_LoggersHatchet", "Item_IronBuckler", "Item_RunesOfTheBlight"}
						end
						core.InsertToTable(shopping.Itembuild, startItems)			 
						bNewItems = true
						tItemDecisions.Lane = true
				else
						--still no lane.... no starting items
						if debugInfo then BotEcho("No Lane set. Bot will skip start items now") end
				end
		--rest of itembuild
		elseif not tItemDecisions.Rest then
				if debugInfo then BotEcho("Insert Rest of Items") end
				core.InsertToTable(shopping.Itembuild, behaviorLib.LaneItems)
				core.InsertToTable(shopping.Itembuild, behaviorLib.MidItems)
				core.InsertToTable(shopping.Itembuild, behaviorLib.LateItems)
			   
				bNewItems = true
				tItemDecisions.Rest = true
		end
	   
		if debugInfo then BotEcho("Reached end of Itembuilder Function. Keep Shopping? "..tostring(bNewItems)) end
		return bNewItems
end
object.oldItembuilder = shopping.CheckItemBuild
shopping.CheckItemBuild = legoItemBuilder
]]

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
		object.currentMaxDifficulty = 90
	elseif nLevel == 5 then
		object.currentMaxDifficulty = 100
	elseif nLevel == 7 then
		object.currentMaxDifficulty = 130
	elseif nLevel == 10 then
		object.currentMaxDifficulty = 150
	elseif nLevel >= 12 then
		object.currentMaxDifficulty = 260
	end
	
	-- Wait until level 7 to start grouping/pushing/defending
	behaviorLib.nTeamGroupUtilityMul = 0.13 + nLevel * 0.01
	behaviorLib.pushingCap = 13 + nLevel
	behaviorLib.nTeamDefendUtilityVal = 13 + nLevel
end

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
	
	if core.itemPortalKey and core.itemPortalKey:CanActivate() then
		nUtility = nUtility + object.nPortalKeyUp
	end

	if core.itemBarbedArmor and core.itemBarbedArmor:CanActivate() then
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
	return 275 -- This is 300 minus 25 to ensure people are within range
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
		local nTauntRadius = getTauntRadius()
		local tCurrentGroup = {}
		local nCurrentGroupCount = 0
		local tBestGroup = {}
		local nBestGroupCount = 0
		local tauntRadiusSq = nTauntRadius * nTauntRadius
		for _, unitTarget in pairs(tEnemyHeroes) do
			local vecTargetPosition = unitTarget:GetPosition()
			for _, unitOtherTarget in pairs(tEnemyHeroes) do
				if Vector3.Distance2DSq(unitOtherTarget:GetPosition(), vecTargetPosition) <= tauntRadiusSq then
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
	
	-- Get items
	core.itemPortalKey = core.GetItem("Item_PortalKey")
	core.itemBarbedArmor = core.GetItem("Item_Excruciator")

	-- Portal Key
	local itemPortalKey = core.itemPortalKey
	if itemPortalKey and itemPortalKey:CanActivate() and behaviorLib.lastHarassUtil > object.nPortalKeyThreshold then
		local vecBestTauntPosition = getBestPortalKeyTauntPosition(botBrain, vecMyPosition, 2)
		if vecBestTauntPosition then
			-- Port into two or more enemies
			bActionTaken = core.OrderItemPosition(botBrain, unitSelf, itemPortalKey, vecBestTauntPosition)
		else
			-- Port to a single enemy
			local nTauntRadius = getTauntRadius()
			if nTargetDistanceSq > (nTauntRadius * nTauntRadius) then
				bActionTaken = core.OrderItemPosition(botBrain, unitSelf, itemPortalKey, vecTargetPosition)
			end
		end
	end

	-- Taunt
	if not bActionTaken then
		local abilTaunt = skills.abilTaunt
		if abilTaunt:CanActivate() and nLastHarassUtility > botBrain.nTauntThreshold then
			local nRadius = getTauntRadius()
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

core.AddJunglePreferences("Legionnaire", {
	Neutral_Catman_leader = 40,
	Neutral_Catman = 20,
	Neutral_VagabondLeader = 30,
	Neutral_Minotaur = 15,
	Neutral_Ebula = 3,
	Neutral_HunterWarrior = -5,
	Neutral_snotterlarge = -1,
	Neutral_snottling = -3,
	Neutral_SkeletonBoss = -5,
	Neutral_AntloreHealer = 5,
	Neutral_WolfCommander = 15,
	Neutral_Crazy_Alchemist = 5,
	Neutral_Wereboss = 5,
})

behaviorLib.nCreepAggroUtility = 0
behaviorLib.nRecentDamageMul = 0.20

object.nStacking = 0 -- 0 = not, 1 = waiting/attacking 2, = running away
object.nStackingCamp = 0

object.currentMaxDifficulty = 70
object.lastJungleExecute = 0

-------- Behavior Functions --------
function jungleUtility(botBrain)
	if (HoN.GetRemainingPreMatchTime() and HoN.GetRemainingPreMatchTime()>14000) or core.tMyLane.sLaneName~='jungle' then -- don't try if we have a lane!
		return 0
	end
	return 21
end

local bBeenToOutside = false --have we been to the outside of our next camp?
local bShouldStack = false
function jungleExecute(botBrain)
	local unitSelf = core.unitSelf
	local debugMode=false
	local jungleLib = core.teamBotBrain.jungleLib

	local vecMyPos = unitSelf:GetPosition()
	local vecTargetPos, nCamp = jungleLib.getNearestCampPos(vecMyPos, "Legionnaire", 0, object.currentMaxDifficulty)
	
	-- if we don't have a camp to go to, wait at the hard camp closest to well
	if nCamp==nil then-- we have no next position! Likely the beginning of the game, go to default camp and wait.
		object.nLastCamp = -1
		if core.myTeam == HoN.GetHellbourneTeam() then
			nCamp=8
		else
			nCamp=2
		end
		vecTargetPos = jungleLib.tJungleSpots[nCamp].vecOutsidePos
	end
	
	local nDistanceSq = Vector3.Distance2DSq(vecMyPos, vecTargetPos)
	if debugMode then core.DrawDebugArrow(vecMyPos, vecTargetPos, 'green') end
	
	-- reset bBeenToOutside if we are changing camps and haven't yet been to the outside
	if (nCamp ~= object.nLastCamp) then
		bBeenToOutside = false
	end
	object.nLastCamp=nCamp
	-- we are too far, reset the camp.
	if bBeenToOutside and nDistanceSq > 1000 * 1000 and not bShouldStack then
		bBeenToOutside = false
	end
	-- we are too far to still be stacking, reset it.
	if bShouldStack and nDistanceSq > 2000 * 2000 then
		bShouldStack = false
	end
	
	local nMins, nSecs = jungleLib.getTime()
	-- Get out of creeps and go to the outside of the camp if we haven't yet - this means we can get a good view of all the creeps in the camp to infest the best one.
	if not bBeenToOutside and not bShouldStack then
		-- if we are close to the outside of a camp, we can now go into the camp
		if Vector3.Distance2DSq(vecMyPos, jungleLib.tJungleSpots[nCamp].vecOutsidePos) < 100 * 100 then -- we can go into the camp now!
			bBeenToOutside = true
			bShouldStack = false
			if nSecs < 53 and (nSecs > 40 or nMins == 0) then --if we reach a camp, and we can/should stack it, then do so.
				bShouldStack = true
			end
		end
		return core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, jungleLib.tJungleSpots[nCamp].vecOutsidePos)
	-- Lets stack the camp first
	elseif (bShouldStack) then
		if (nSecs < 53 and (nSecs > 40 or nMins == 0)) then
			-- Wait outside the camp
			object.nStacking = 1
			object.nStackingCamp = nCamp
			return core.OrderMoveToPosAndHoldClamp(botBrain, core.unitSelf, jungleLib.tJungleSpots[nCamp].vecOutsidePos, false)
		elseif object.nStacking == 1 and unitSelf:IsAttackReady() then -- move in until we attack
			-- Attack the units in the camp
			if nSecs >= 57 then 
				-- Missed our chance to stack
				bShouldStack = false
				object.nStacking = 0 
			end
			return core.OrderAttackPosition(botBrain, unitSelf, vecTargetPos,false,false)
		elseif object.nStacking ~= 0 and nDistanceSq < (1500 * 1500) and nSecs > 50 then
			-- Move away from the units in the camp
			jungleLib.stacking = object.nStackingCamp
			object.nStacking = 2
			local vecAwayPos = jungleLib.tJungleSpots[object.nStackingCamp].pos + (jungleLib.tJungleSpots[object.nStackingCamp].vecOutsidePos - jungleLib.tJungleSpots[object.nStackingCamp].pos) * 4
			if debugMode then
				core.DrawXPosition(jungleLib.tJungleSpots[object.nStackingCamp].pos, 'red')
				core.DrawXPosition(jungleLib.tJungleSpots[object.nStackingCamp].vecOutsidePos, 'red')
				core.DrawDebugArrow(jungleLib.tJungleSpots[object.nStackingCamp].pos,vecAwayPos, 'green')
			end

			return core.OrderMoveToPosClamp(botBrain, core.unitSelf, vecAwayPos, false)
		else
			-- Finished stacking
			object.nStacking = 0
			jungleLib.stacking = 0
			bShouldStack = false
			return core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, vecTargetPos)
		end
	-- Lets kill the units in the camp
	else
		-- It is safe to assume we are in this section of code a lot, without much changing, therefore we can slow this down.
		if HoN:GetGameTime() < object.lastJungleExecute + 300 then --run 2.5 times a second.
			return true
		end
		object.lastJungleExecute = HoN:GetGameTime()
	-- Kill neutrals in the camp
		local tUnits = HoN.GetUnitsInRadius(vecMyPos, 800, core.UNIT_MASK_ALIVE + core.UNIT_MASK_UNIT)
		if tUnits then
			-- Find the strongest unit in the camp
			local nHighestHealth = 0
			local unitStrongest = nil
			for _, unitTarget in pairs(tUnits) do
				if unitTarget:GetHealth() > nHighestHealth and unitTarget:IsAlive() and unitTarget:GetTeam() ~= core.myTeam and unitTarget:GetTeam() ~= core.enemyTeam then
					unitStrongest = unitTarget
					nHighestHealth = unitTarget:GetHealth()
				end
			end
			
			-- Attack the strongest unit
			if unitStrongest and unitStrongest:GetPosition() then
				if debugMode then core.DrawDebugArrow(vecMyPos, unitStrongest:GetPosition(), 'silver') end
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

--Position self, but only if not in jungle.
local function PositionSelfUtilityOverride(botBrain)
	if (core.tMyLane and core.tMyLane.sLaneName~='jungle') then
		return object.oldPositionSelfUtility(botBrain)
	end
	return 0
end
object.oldPositionSelfUtility = behaviorLib.PositionSelfBehavior["Utility"]
behaviorLib.PositionSelfBehavior["Utility"] = PositionSelfUtilityOverride

--Pre-game, but, we don't head to lanes, we head to jungle.
local function PreGameUtilityOverride(botBrain)
	if (not (core.tMyLane and core.tMyLane.sLaneName=='jungle')) then
		return object.oldPreGameUtility(botBrain)
	end
	return 0
end
object.oldPreGameUtility = behaviorLib.PreGameBehavior["Utility"]
behaviorLib.PreGameBehavior["Utility"] = PreGameUtilityOverride

--Return to well, based on more factors than just health.
function HealAtWellUtilityOverride(botBrain)
    return object.HealAtWellUtilityOld(botBrain)+(botBrain:GetGold()*8/2000)
end
object.HealAtWellUtilityOld = behaviorLib.HealAtWellBehavior["Utility"]
behaviorLib.HealAtWellBehavior["Utility"] = HealAtWellUtilityOverride

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
