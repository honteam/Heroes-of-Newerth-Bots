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
	{"Item_BloodChalice"}
behaviorLib.LaneItems =
	{"Item_Marchers", "Item_EnhancedMarchers", "Item_Nuke 5", "Item_SpellShards 3"}
behaviorLib.MidItems =
	{"Item_GrimoireOfPower", "Item_Immunity"} -- Item_Immunity is shrunken head
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
object.nFacehugUp = 15
object.nNukeUp = 12
object.nSymbolOfRageUp = 4

-- Bonus aggression points that are applied to the bot upon successfully using a skill/item
object.nLeechUse = 20
object.nFacehugUse = 25
object.nNukeUse = 20
object.nSymbolOfRageUse = 8

-- Thresholds of aggression the bot must reach to use these abilities
object.nLeechThreshold = 30
object.nFacehugThreshold = 25
object.nNukeThreshold = 40

-- Other variables
behaviorLib.nCreepPushbackMul = 0.1
behaviorLib.nTargetPositioningMul = 0.8
behaviorLib.safeTreeAngle = 360
object.nTimeLastFacehugged = 0
local bBeenToOutside=false
object.unitInfestedUnit = nil
object.unitInfestingUnit = nil --currently infesting this unit
object.nLastCamp=-1
local nSpamChaliceTill = 0

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
	end

	local nPoints = unitSelf:GetAbilityPointsAvailable()
	if nPoints <= 0 then
		return
	end

	local nLevel = unitSelf:GetLevel()
	for i = nLevel, (nLevel + nPoints) do
		unitSelf:GetAbility(self.tSkills[i]):LevelUp()
	end
	
	-- Wait until level 7 to start grouping/pushing/defending
	behaviorLib.nTeamGroupUtilityMul = 0.13 + core.unitSelf:GetLevel() * 0.01
	behaviorLib.pushingCap = 13 + core.unitSelf:GetLevel()
	behaviorLib.nTeamDefendUtilityVal = 13 + core.unitSelf:GetLevel()
end

----------------------------------------
--         HealAtWell Override        --
----------------------------------------
--Return to well, based on more factors than just health.
function HealAtWellUtilityOverride(botBrain)
    return object.HealAtWellUtilityOld(botBrain)+(botBrain:GetGold()*8/2000)
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
		elseif EventData.InflictorName == "Ability_Parasite4" then
			nAddBonus = nAddBonus + object.nFacehugUse
		end
	elseif EventData.Type == "Item" then
		if core.itemNuke ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemNuke:GetName() then
			nAddBonus = nAddBonus + object.nNukeUse
		elseif core.itemSymbolOfRage ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemSymbolOfRage:GetName() then
			nAddBonus = nAddBonus + object.nSymbolOfRageUse
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
local function HarassHeroExecuteOverride(botBrain)
	
	local unitTarget = behaviorLib.heroTarget
	--Target is invalid, move on to the next behaviour
	if unitTarget == nil then
		return false
	end

	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bActionTaken = false
	local nTime = HoN:GetGameTime()
	--don't codex if it hasn't been 0.25 seconds since facehug - because damage won't have been applied yet.
	if (nTime < object.nTimeLastFacehugged + 250) then
		return true
	end
	
	-- Find items
	core.itemNuke = core.GetItem("Item_Nuke")
	core.itemSymbolOfRage = core.GetItem("Item_LifeSteal4")
	
	-- Facehug
	local abilFacehug = skills.abilFacehug
	if abilFacehug:CanActivate() and nLastHarassUtility > botBrain.nFacehugThreshold then
		bActionTaken = core.OrderAbilityEntity(botBrain, abilFacehug, unitTarget, false)
		if bActionTaken then
			object.nTimeLastFacehugged = nTime
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
			--only codex if it will kill with that and an auto attack
			(unitTarget:GetHealth() < (300+itemNuke:GetLevel()*100)*(1-unitTarget:GetMagicResistance()) + unitSelf:GetFinalAttackDamageMin()) then
				if nTargetDistanceSq <= (nNukeRange * nNukeRange) then
					bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemNuke, unitTarget)
					core.OrderAttackClamp(botBrain, unitSelf, unitTarget, false)
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
	Neutral_Catman_leader = -10,
	Neutral_Catman = 20,
	Neutral_VagabondLeader = -10,
	Neutral_Minotaur = -5,
	Neutral_Ebula = 15,
	Neutral_HunterWarrior = -5,
	Neutral_snotterlarge = 5,
	Neutral_snottling = 5,
	Neutral_SkeletonBoss = -5,
	Neutral_AntloreHealer = 5,
	Neutral_WolfCommander = 5,
	Neutral_Crazy_Alchemist = -10,
	Neutral_Wereboss = -15,
})

-------- Behaviour Functions --------
local function jungleUtility(botBrain)

	--remove infested unit if it is gone
	if (object.unitInfestedUnit and not object.unitInfestedUnit:IsAlive()) then
		object.unitInfestedUnit = nil
	end
	
	local nRemainingTime = HoN.GetRemainingPreMatchTime()
	-- don't reference core.tMyLane until it actually has a value
	if (nRemainingTime and nRemainingTime>14000) or core.tMyLane.sLaneName~='jungle' then -- don't try if we have a lane!
		return 0
	end
	
	-- don't jungle when we have a codex! >:D
	if object.itemNuke and object.itemNuke:CanActivate() and not object.unitInfestedUnit and not bBeenToOutside then
		return 0
	end
	
	return 25
end

local function jungleExecute(botBrain)
	--show lines etc
	local debugMode = false
	local jungleLib = core.teamBotBrain.jungleLib
	local unitSelf = core.unitSelf -- Set to parasite for the camp searching stuff
	
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
	local vecMyPos = unitSelf:GetPosition()
	local vecTargetPos, nCamp = jungleLib.getNearestCampPos(vecMyPos, "Parasite", 85, 200, unitSelf:GetTeam())
	
	--If hard camps spawn while we are doing another camp, stay at our camp, no need to stop prematurely.
	if nCamp and object.nLastCamp and object.nLastCamp ~= -1 and bBeenToOutside and nCamp ~= object.nLastCamp and jungleLib.tJungleSpots[object.nLastCamp].nStacks > 0 then 
		nCamp = object.nLastCamp
		vecTargetPos = jungleLib.tJungleSpots[object.nLastCamp].pos
	end
	
	-- we have no camp to go to... Lets try to find one if we can do them
	if nCamp==nil then 
		local nLevel = unitSelf:GetLevel()
		if nLevel >= 4 then --no more hard camps on our side of the river.. lets try medium camps if we can do them?
			vecTargetPos, nCamp = jungleLib.getNearestCampPos(vecMyPos, "Parasite", 40, 200, unitSelf:GetTeam())
		end
		if nCamp==nil and nLevel >= 16 then --what.. Still no free camps, take out ancients if we can?
			vecTargetPos, nCamp = jungleLib.getNearestCampPos(vecMyPos, "Parasite", 40, 300, unitSelf:GetTeam())
		end
	end
	
	-- now set control to either parasite or the creep he is currently possessing
	unitSelf = (object.unitInfestedUnit ~= nil and object.unitInfestedUnit) or unitSelf
	
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
			local abilEscape = object.unitInfestedUnit:GetAbility(3)
			if (abilEscape == nil) then
				BotEcho("Error, no ability to get out of unit! WHAT!?")
			end
			-- kill the infected creep
			return core.OrderAbility(botBrain, abilEscape)
		end
		return core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, jungleLib.tJungleSpots[nCamp].vecOutsidePos)
	-- Lets kill the units in the camp
	else 
		-- Kill neutrals in the camp
		local tUnits = core.localUnits["Neutrals"]
		if tUnits then
			if (skills.abilInfest:CanActivate()) then
				-- Find the strongest unit in the camp
				local nHighestHealth = unitSelf:GetHealth()/5
				local unitStrongest = nil
				for _, unitTarget in pairs(tUnits) do
					local targetHealth = unitTarget:GetHealth()
					if targetHealth > nHighestHealth and unitTarget:IsAlive() then
						unitStrongest = unitTarget
						nHighestHealth = targetHealth
					end
					if (unitTarget:GetTypeName() == "Neutral_Crazy_Alchemist" and targetHealth > 500) then
						unitStrongest = unitTarget
						nHighestHealth = targetHealth
						break
					end
				end
				-- Infest the strongest unit
				if unitStrongest then
					bActionTaken = core.OrderAbilityEntity(botBrain, skills.abilInfest, unitStrongest, false)
					-- use chalice if we just jumped into a good creep!
					local itemChalice = core.GetItem("Item_BloodChalice")
					if (itemChalice and itemChalice:CanActivate()) then
						nSpamChaliceTill = HoN:GetGameTime() + 250
					end
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
			
			local abilFirstAbilitiy = object.unitInfestedUnit and object.unitInfestedUnit:GetAbility(0)
			local sTypeName = object.unitInfestedUnit and object.unitInfestedUnit:GetTypeName()
			if object.unitInfestedUnit and nDistanceSq < 200*200 and (sTypeName == "Neutral_Catman_leader" or sTypeName == "Neutral_Minotaur") and abilFirstAbilitiy and abilFirstAbilitiy:CanActivate() then
				--BotEcho("Using ability!")
				core.OrderAbility(botBrain, abilFirstAbilitiy)
			elseif (skills.abilInfest:GetActualRemainingCooldownTime()<8 or nDistanceSq < (500 * 500) or object.unitInfestedUnit ~= nil) then
				local nLowestHealth = 999999
				local unitWeakest = nil
				--BotEcho("Gonna search for a target "..core.NumberElements(tUnits))
				
				for _, unitTarget in pairs(tUnits) do
					if unitTarget:GetHealth() < nLowestHealth and unitTarget:IsAlive() then
						--BotEcho("Searching for weakest")
						unitWeakest = unitTarget
						nLowestHealth = unitTarget:GetHealth()
					end
				end
				if (unitWeakest) then
					--Units with abilities requiring targets go here. Alchemist should use this on the strongest, but I don't want to gate for that. This should be fine.
					if object.unitInfestedUnit and (sTypeName == "Neutral_VagabondLeader" or sTypeName == "Neutral_Crazy_Alchemist") and abilFirstAbilitiy and abilFirstAbilitiy:CanActivate() then
						core.OrderAbilityEntity(botBrain, abilFirstAbilitiy, unitWeakest, false)
					end
					--BotEcho("Attacking weakest")
					return core.OrderAttackClamp(botBrain, unitSelf, unitWeakest, false)
				else
					return core.OrderAttackPosition(botBrain, unitSelf, vecTargetPos)
				end
			else
				return core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, jungleLib.tJungleSpots[nCamp].vecOutsidePos)
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
--  	OnThink Override	  --
----------------------------------------
function object:onthinkOverride(tGameVariables) --This is run, even while dead. Every frame.
	self:onthinkOld(tGameVariables)--don't distrupt old think, run it.
	local unitSelf = core.unitSelf
	
	-- If we start on another behavior, but we are inside a unit, leave the unit. This is in utility as it is run constantly.
	if object.unitInfestedUnit and core.GetCurrentBehaviorName(self) ~= "jungle" and core.GetCurrentBehaviorName(self) ~= "RetreatFromThreat" and core.GetCurrentBehaviorName(self) ~= "PositionSelf" then
		--BotEcho("Exited due to another behavior taking over! ".. core.GetCurrentBehaviorName(self))
		core.OrderAbility(self, object.unitInfestedUnit:GetAbility(3))
	end
	
	local itemChalice = core.GetItem("Item_BloodChalice")
	if (HoN:GetGameTime() < nSpamChaliceTill) then
		if (itemChalice and itemChalice:CanActivate()) then
			if (not skills.abilInfest:CanActivate()) then
				self:OrderItem((itemChalice ~= nil and itemChalice.object) or itemChalice)
			end
		else
			nSpamChaliceTill = 0
		end
	end
	
end
object.onthinkOld = object.onthink
object.onthink  = object.onthinkOverride

----------------------------------------
--          Behaviour Changes         --
----------------------------------------
tinsert(behaviorLib.tDontUseDefaultItemBehavior, "Item_ManaPotion") -- we will manage mana pots ourselves.

local function PreGameUtilityOverride(botBrain)
	local nTime = HoN:GetMatchTime()
	if nTime <= 20000 then
		if (nTime >= 19800) then
			behaviorLib.canAccessShopLast = false
		end
		return 98
	end
	return 0
end

local function PreGameExecuteOverride(botBrain)
	core.OrderHoldClamp(botBrain, core.unitSelf)
end
behaviorLib.PreGameBehavior["Utility"] = PreGameUtilityOverride
behaviorLib.PreGameBehavior["Execute"] = PreGameExecuteOverride

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