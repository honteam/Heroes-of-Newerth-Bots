----------------------------------------------------------------------------------
--                                                            ___               -- 
--                                                      .-.  (   )              --
--    .-..     .---.   ___ .-.      .---.      .--.    ( __)  | |_       .--.   --
--   /    \   / .-, \ (   )   \    / .-, \   /  _  \   (''") (   __)    /    \  --
--  ' .-,  ; (__) ; |  | ' .-. ;  (__) ; |  . .' `. ;   | |   | |      |  .-. ; --
--  | |  . |   .'`  |  |  / (___)   .'`  |  | '   | |   | |   | | ___  |  | | | --
--  | |  | |  / .'| |  | |         / .'| |  _\_`.(___)  | |   | |(   ) |  |/  | --
--  | |  | | | /  | |  | |        | /  | | (   ). '.    | |   | | | |  |  ' _.' --
--  | |  ' | ; |  ; |  | |        ; |  ; |  | |  `\ |   | |   | ' | |  |  .'.-. --
--  | `-'  ' ' `-'  |  | |        ' `-'  |  ; '._,' '   | |   ' `-' ;  '  `-' / --
--  | \__.'  `.__.'_. (___)       `.__.'_.   '.___.'   (___)   `.__.    `.__.'  --
--  | |                                                                         --
--  (___)    																    --
----------------------------------------------------------------------------------
--		 Parasite Bot Version 0.1		--
------------------------------------------
--			  Created by:				--
--		 Mellow_Ink    Kairus101		--
------------------------------------------


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

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

local sqrtTwo = math.sqrt(2)

BotEcho('loading parasite_main...')

--------------------------------
-- 			  Lanes			  --
--------------------------------
core.tLanePreferences = {Jungle = 5, Mid = 1, ShortSolo = 1, LongSolo = 1, ShortSupport = 1, LongSupport = 1, ShortCarry = 3, LongCarry = 2, hero=core.unitSelf}

---------------------------------
--          Constants          --
---------------------------------

-- Hero Name
object.heroName = 'Hero_Parasite'

-- Item buy order. internal names
behaviorLib.StartingItems =
	{"5 Item_ManaPotion", "Item_Scarab"}
behaviorLib.LaneItems =
	{"Item_Marchers", "Item_EnhancedMarchers", "Item_Nuke 5", "Item_SpellShards 3"}
behaviorLib.MidItems =
	{"Item_GrimoireOfPower", "Item_Evasion"} 
behaviorLib.LateItems =
	{"Item_Weapon3", "Item_BehemothsHeart", "Item_LifeSteal4"}

-- Skill build. 0 is Leech, 1 is Infest, 2 is Draining Venom, 3 is Facehug, 4 is Attributes
object.tSkills = {
	1, 0, 1, 0, 0,
	3, 0, 2, 2, 2,
	3, 1, 1, 4, 4,
	3, 4, 4, 4, 4,
	4, 4, 4, 4, 4
}

-- Bonus aggression points if a skill/item is available for use
object.nLeechUp = 10
object.nInfestUp = 0
object.nFacehugUp = 15
object.nNukeUp = 12
object.nSymbolOfRageUp = 4

-- Bonus aggression points that are applied to the bot upon successfully using a skill/item
object.nLeechUse = 20
object.nInfestUse = 0
object.nFacehugUse = 25
object.nNukeUse = 20
object.nSymbolOfRageUse = 8

-- Thresholds of aggression the bot must reach to use these abilities
object.nLeechThreshold = 30
object.nInfestThreshold = 0
object.nFacehugThreshold = 25
object.nNukeThreshold = 40
object.nSymbolOfRageThreshold = 25

-- Other variables
behaviorLib.nCreepPushbackMul = 0.1
behaviorLib.nTargetPositioningMul = 0.8
behaviorLib.safeTreeAngle = 360

------------------------------
--          Skills          --
------------------------------

function object:SkillBuild()
	core.VerboseLog("SkillBuild()")

	local unitSelf = self.core.unitSelf
	if  skills.abilLeech == nil then
		skills.abilLeech = unitSelf:GetAbility(0)
		skills.abilInfest = unitSelf:GetAbility(1)
		skills.abilDrainingVenom = unitSelf:GetAbility(2)
		skills.abilFacehug = unitSelf:GetAbility(3)
		skills.abilAttributeBoost = unitSelf:GetAbility(4)
	end

	local nPoints = unitSelf:GetAbilityPointsAvailable()
	if nPoints <= 0 then
		return
	end

	local nLevel = unitSelf:GetLevel()
	for i = nLevel, (nLevel + nPoints) do
		unitSelf:GetAbility(self.tSkills[i]):LevelUp()
	end
end

------------------------------------------
--          FindItems Override          --
------------------------------------------

local function funcFindItemsOverride(botBrain)
	local bUpdated = object.FindItemsOld(botBrain)
	
	--removes item if sold
	core.ValidateItem(core.itemGhostMarchers)	
	core.ValidateItem(core.itemNuke)
	core.ValidateItem(core.itemSymbolOfRage)

	--bupdated seems to break this O.o
	if core.itemNuke and core.itemSymbolOfRage then
		return
	end

	local inventory = core.unitSelf:GetInventory(false)
	for slot = 1, 6, 1 do
		local curItem = inventory[slot]
		if curItem then
			if core.itemNuke == nil and curItem:GetName() == "Item_Nuke" then
				core.itemNuke = core.WrapInTable(curItem)
			elseif core.itemSymbolOfRage == nil and curItem:GetName() == "Item_LifeSteal4" then
				core.itemSymbolOfRage = core.WrapInTable(curItem)
			end
		end
	end
end

object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride

----------------------------------------
--         HealAtWell Override        --
----------------------------------------
--Return to well, based on more factors than just health.
function HealAtWellUtilityOverride(botBrain)
    return object.HealAtWellUtilityOld(botBrain)+(botBrain:GetGold()*8/2000)+ 8-(core.unitSelf:GetManaPercent()*8)
end
object.HealAtWellUtilityOld = behaviorLib.HealAtWellBehavior["Utility"]
behaviorLib.HealAtWellBehavior["Utility"] = HealAtWellUtilityOverride

----------------------------------------------
--          OnCombatEvent Override          --
----------------------------------------------

function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)

	local nAddBonus = 0

	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_Parasite1" then
			nAddBonus = nAddBonus + object.nLeechUse
		elseif EventData.InflictorName == "Ability_Parasite2" then
			nAddBonus = nAddBonus + object.nInfestUse
		elseif EventData.InflictorName == "Ability_Parasite4" then
			nAddBonus = nAddBonus + object.nFacehugUse
		end
	elseif EventData.Type == "Item" then
		if core.itemNuke ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemNuke:GetName() then
			nAddBonus = nAddBonus + object.nNukeUse
		elseif core.itemSymbolOfRage ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemSymbolOfRage:GetName() then
			nAddBonus = nAddBonus + object.nBSymbolOfRageUse
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
	
	if skills.abilLeech:CanActivate() then
		nUtility = nUtility + object.nLeechUp
	end
	
	if skills.abilInfest:CanActivate() then
		nUtility = nUtility + object.nInfestUp
	end

	if skills.abilFacehug:CanActivate() then
		nUtility = nUtility + object.nFacehugUp
	end
	
	if object.itemNuke and object.itemNuke:CanActivate() then
		nUtility = nUtility + object.nNukeUp
	end

	if object.itemSymbolOfRage and object.itemSymbolOfRage:CanActivate() then
		nUtility = nUtility + object.nSymbolOfRageUp
	end
	
	return nUtility
end

behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride


----------------------------------------
--          Harass Behaviour          --
----------------------------------------
object.timeLastFacehugged = 0
local function HarassHeroExecuteOverride(botBrain)
	
	local unitTarget = behaviorLib.heroTarget
	--Target is invalid, move on to the next behaviour
	if unitTarget == nil then
		return object.harassExecuteOld(botBrain)
	end

	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bActionTaken = false

	--don't codex if it hasn't been 0.5 seconds since facehug - because damage won't have been applied yet.
	if (HoN:GetGameTime() < object.timeLastFacehugged + 250) then
		return true
	end
	
	-- Facehug
	if not bActionTaken then
		local abilFacehug = skills.abilFacehug
		if abilFacehug:CanActivate() and nLastHarassUtility > botBrain.nFacehugThreshold then
			bActionTaken = core.OrderAbilityEntity(botBrain, abilFacehug, unitTarget, false)
			if bActionTaken then
				object.timeLastFacehugged = HoN:GetGameTime()
			end
		end
	end
	
	-- Leech
	if not bActionTaken then
		local abilLeech = skills.abilLeech
		if abilLeech:CanActivate() and nLastHarassUtility > botBrain.nLeechThreshold then
				bActionTaken = core.OrderAbilityEntity(botBrain, abilLeech, unitTarget, false)
		end
	end

	-- Codex
	if not bActionTaken then
		local itemNuke = core.itemNuke
		if itemNuke then
			local nNukeRange = itemNuke:GetRange()
			if itemNuke:CanActivate() and nLastHarassUtility > botBrain.nNukeThreshold and
			--only codex if it will kill or if they have DrainingVenom on them
			(unitTarget:GetHealth() < (300+itemNuke:GetLevel()*100)*(1-unitTarget:GetMagicResistance()) or unitTarget:HasState("State_Parasite_Ability3") or skills.abilDrainingVenom:GetLevel() == 0) then
				if nTargetDistanceSq <= (nNukeRange * nNukeRange) then
					bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemNuke, unitTarget)
					bActionTaken = core.OrderAttackClamp(botBrain, unitSelf, unitTarget, false, true)
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
--          Jungle Behaviour          --
---------------------------------------
--
-- Utility: 21
-- This is effectively an "idle" behaviour
--
-- Execute:
-- Move to unoccupied camps
-- Attack weakest Neutral until they are all dead
--

-------- Global Constants & Variables --------
behaviorLib.nCreepAggroUtility = 0
--behaviorLib.nRecentDamageMul = 0.20
core.AddJunglePreferences("Parasite", {
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
})

-------- Behaviour Functions --------
local bBeenToOutside=false
function jungleUtility(botBrain)

	--remove infested unit if it is gone
	if (object.unitInfestedUnit and not object.unitInfestedUnit:IsAlive()) then
		object.unitInfestedUnit = nil
	end
	-- If we start on another behavior, but we are inside a unit, leave the unit. This is in utility as it is run constantly.
	if object.unitInfestedUnit and core.GetLastBehaviorName(botBrain) ~= "jungle" and core.GetLastBehaviorName(botBrain) ~= "RetreatFromThreat" and core.GetLastBehaviorName(botBrain) ~= "PositionSelf" then
		--BotEcho("Exited due to another behavior taking over! ".. core.GetLastBehaviorName(botBrain))
		core.OrderAbility(botBrain, object.unitInfestedUnit:GetAbility(3))
		return 0
	end
	
	-- Wait until level 9 to start grouping/pushing/defending
	behaviorLib.nTeamGroupUtilityMul = 0.13 + core.unitSelf:GetLevel() * 0.01
	behaviorLib.pushingCap = 13 + core.unitSelf:GetLevel()
	behaviorLib.nTeamDefendUtilityVal = 13 + core.unitSelf:GetLevel()
	
	-- don't reference core.tMyLane until it actually has a value
	if (HoN.GetRemainingPreMatchTime() and HoN.GetRemainingPreMatchTime()>14000) or core.tMyLane.sLaneName~='jungle' then -- don't try if we have a lane!
		return 0
	end
	
	-- don't jungle when we have a codex! >:D
	if object.itemNuke and object.itemNuke:CanActivate() and not object.unitInfestedUnit and not bBeenToOutside then
		return 0
	end
	
	return 25
end

object.unitInfestedUnit = nil
object.unitInfestingUnit = nil --currently infesting this unit
object.nLastCamp=-1
function jungleExecute(botBrain)
	--show lines etc
	local debugMode = false
	local jungleLib = core.teamBotBrain.jungleLib
	
	--get infested unit if there is one
	if (object.unitInfestingUnit and object.unitInfestingUnit:IsValid() and object.unitInfestingUnit:HasState("State_Parasite_Ability2_Target")) then
		object.unitInfestedUnit = object.unitInfestingUnit
		object.unitInfestingUnit = nil
	end

	--remove infested unit if it is gone
	if (object.unitInfestedUnit and not object.unitInfestedUnit:IsAlive()) then
		object.unitInfestedUnit = nil
	end
	
	-- get information about the nearest jungle spot
	local vecMyPos = core.unitSelf:GetPosition()
	local vecTargetPos, nCamp = jungleLib.getNearestCampPos(vecMyPos, "Parasite", 85, 200, core.unitSelf:GetTeam())
	
	--If hard camps spawn while we are doing another camp, stay at our camp, no need to stop prematurely.
	if nCamp and object.nLastCamp and object.nLastCamp ~= -1 and bBeenToOutside and nCamp ~= object.nLastCamp and jungleLib.tJungleSpots[object.nLastCamp].nStacks > 0 then 
		nCamp = object.nLastCamp
		vecTargetPos = jungleLib.tJungleSpots[object.nLastCamp].pos
	end
	
	-- we have no camp to go to... Lets try to find one if we can do them
	if nCamp==nil then 
		local nLevel = core.unitSelf:GetLevel()
		if nLevel >= 4 then --no more hard camps on our side of the river.. lets try medium camps if we can do them?
			vecTargetPos, nCamp = jungleLib.getNearestCampPos(vecMyPos, "Parasite", 40, 200, core.unitSelf:GetTeam())
		end
		if nCamp==nil and nLevel >= 16 then --what.. Still no free camps, take out ancients if we can?
			vecTargetPos, nCamp = jungleLib.getNearestCampPos(vecMyPos, "Parasite", 40, 300, core.unitSelf:GetTeam())
		end
	end
	
	-- set control to either parasite or the creep he is currently possessing
	local unitSelf = (object.unitInfestedUnit ~= nil and object.unitInfestedUnit) or core.unitSelf	
	
	-- reset bBeenToOutside if we are changing camps and haven't yet been to the outside
	if (nCamp ~= object.nLastCamp) then
		--BotEcho("New camp!")
		bBeenToOutside = false
	end
	object.nLastCamp=nCamp
	
	-- if we don't have a camp to go to, wait at the hard camp closest to well
	if nCamp==nil then-- we have no next position! Likely the beginning of the game, go to default camp and wait.
		object.nLastCamp = -1
		if core.myTeam == HoN.GetHellbourneTeam() then
			nCamp=7
		else
			nCamp=1
		end
		vecTargetPos = jungleLib.tJungleSpots[nCamp].vecOutsidePos
	end 
	if debugMode then core.DrawDebugArrow(vecMyPos, vecTargetPos, 'green') end
	
	local nDistanceSq = Vector3.Distance2DSq(vecMyPos, vecTargetPos)
	
	-- Get out of creeps and go to the outside of the camp if we haven't yet - this means we can get a good view of all the creeps in the camp to infest the best one.
	if not bBeenToOutside then
	
		-- if we are close to the outside of a camp, we can now go into the camp
		if Vector3.Distance2DSq(vecMyPos, jungleLib.tJungleSpots[nCamp].vecOutsidePos) < 100 * 100 then -- we can go into the camp now!
			bBeenToOutside = true
			--BotEcho("Been to outside!")
		end
		
		-- kill currently infested unit
		if (object.unitInfestedUnit and object.unitInfestedUnit:GetHealthPercent() < 0.5) then --comment the second part to make parasite not keep units when migrating
			-- uncomment this to see unit information when breaking out of it
			--BotEcho("getting rid of old unit " .. object.unitInfestedUnit:GetTypeName())
			--[[if (object.unitInfestedUnit) then
				for n = 0, 8 do
					if object.unitInfestedUnit:GetAbility(n) ~= nil then BotEcho("Ability "..n..": "..object.unitInfestedUnit:GetAbility(n):GetTypeName()) end
				end
			end]]
			
			if (object.unitInfestedUnit:GetAbility(3) == nil) then
				BotEcho("Error, no ability to get out of unit! WHAT!?")
			end
			-- kill the infected creep
			return core.OrderAbility(botBrain, object.unitInfestedUnit:GetAbility(3))
		end
		return core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, jungleLib.tJungleSpots[nCamp].vecOutsidePos)
	-- Lets kill the units in the camp
	else 
		-- Kill neutrals in the camp
		local tUnits = HoN.GetUnitsInRadius(vecMyPos, 900, core.UNIT_MASK_ALIVE + core.UNIT_MASK_UNIT)
		if tUnits then
			if (skills.abilInfest:CanActivate()) then
				-- Find the strongest unit in the camp
				local nHighestHealth = unitSelf:GetHealth()/5
				local unitStrongest = nil
				for _, unitTarget in pairs(tUnits) do
					if unitTarget:GetHealth() > nHighestHealth and unitTarget:IsAlive() and unitTarget:GetTeam() ~= core.myTeam and unitTarget:GetTeam() ~= core.enemyTeam then
						unitStrongest = unitTarget
						nHighestHealth = unitTarget:GetHealth()
					end
				end
				-- Infest the strongest unit
				if unitStrongest then					
					-- TODO This will be simplified by core.GetItem
					-- use a mana pot if we are about to jump into a good creep!
					local tInventory = unitSelf:GetInventory()
					local tManaPots = core.InventoryContains(tInventory, "Item_ManaPotion")
					if (not core.IsTableEmpty(tManaPots) and nHighestHealth >= 950 and unitSelf:GetManaPercent()<1 and not unitSelf:HasState("State_ManaPotion")) then
						botBrain:OrderItemEntity((tManaPots[1] ~= nil and tManaPots[1].object) or tManaPots[1], (unitSelf ~= nil and unitSelf.object) or unitSelf, false)
					end
					bActionTaken = core.OrderAbilityEntity(botBrain, skills.abilInfest, unitStrongest, false)
					if bActionTaken then
						object.unitInfestingUnit = unitStrongest
						return
					end
				else
					if (core.GetAttackSequenceProgress(unitSelf)=="idle") then
						--perhaps we are stuck? This sometimes happens upon leaving retreating and trying to leave base again. We shall check for it here.
						if Vector3.Distance2DSq(vecMyPos, jungleLib.tJungleSpots[nCamp].vecOutsidePos) > 1000 * 1000 then -- we are too far, reset it.
							bBeenToOutside = false
							--BotEcho("reset because far away! ".. math.sqrt(Vector3.Distance2DSq(vecMyPos, jungleLib.tJungleSpots[nCamp].vecOutsidePos)))
						end
						return core.OrderAttackPosition(botBrain, unitSelf, vecTargetPos)
					end
				end
			end
			
			if object.unitInfestedUnit and nDistanceSq < 200*200 and (object.unitInfestedUnit:GetTypeName() == "Neutral_Catman_leader" or object.unitInfestedUnit:GetTypeName() == "Neutral_Minotaur") and object.unitInfestedUnit:GetAbility(0) and object.unitInfestedUnit:GetAbility(0):CanActivate() then
				--BotEcho("Using ability!")
				core.OrderAbility(botBrain, object.unitInfestedUnit:GetAbility(0))
			else
				if (skills.abilInfest:GetActualRemainingCooldownTime()<8 or nDistanceSq < (500 * 500) or object.unitInfestedUnit ~= nil) then
					local nLowestHealth = 999999
					local unitWeakest = nil
					--BotEcho("Gonna search for a target "..core.NumberElements(tUnits))
					
					for _, unitTarget in pairs(tUnits) do
						if unitTarget:GetHealth() < nLowestHealth and unitTarget:IsAlive() and unitTarget:GetTeam() ~= core.myTeam and unitTarget:GetTeam() ~= core.enemyTeam then
							--BotEcho("Searching for weakest")
							unitWeakest = unitTarget
							nLowestHealth = unitTarget:GetHealth()
						end
					end
					if (unitWeakest) then
						--vagabond leader, he has to go here because he needs a target.
						if object.unitInfestedUnit and object.unitInfestedUnit:GetTypeName() == "Neutral_VagabondLeader" and object.unitInfestedUnit:GetAbility(0) and object.unitInfestedUnit:GetAbility(0):CanActivate() then
							core.OrderAbilityEntity(botBrain, object.unitInfestedUnit:GetAbility(0), unitWeakest, false)
						end
						--BotEcho("Attacking weakest")
						return core.OrderAttackClamp(botBrain, unitSelf, unitWeakest, false)
					else
						return core.OrderAttackPosition(botBrain, unitSelf, vecTargetPos)
					end
				else
					return core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, jungleLib.tJungleSpots[nCamp].vecOutsidePos)
				end
			end
		else
			return core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, jungleLib.tJungleSpots[nCamp].vecOutsidePos)
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
--          Behaviour Changes         --
----------------------------------------
tinsert(behaviorLib.tDontUseDefaultItemBehavior, "Item_ManaPotion") -- we will manage mana pots ourselves.

-----------------------------------
--          Custom Chat          --
-----------------------------------

core.tKillChatKeys = {
    "Don't throw up!",
    "You look a little sick.",
    "Why is your face so pale?",
    "The SITE up here is to DIE for!",
    "Nothing is immune to me!"
}

core.tDeathChatKeys = {
    "All I wanted was a hug!",
    "I think I'm gonna throw up...",
    "I feel sick..",
    "Let me back in!!!",
	"You cant get rid of me forever"
}

BotEcho(object:GetName()..' finished loading parasite_main')