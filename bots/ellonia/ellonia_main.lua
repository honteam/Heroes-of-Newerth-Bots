--------------------------------------------------------------
-- ###  				 #####  							--
--  #   ####  ######	#     # #    # ###### ###### #    # --
--  #  #	# # 		#     # #    # #	  # 	 ##   # --
--  #  #	  ##### 	#     # #    # #####  #####  # #  # --
--  #  #	  # 		#   # # #    # #	  # 	 #  # # --
--  #  #	# # 		#    #  #    # #	  # 	 #   ## --
-- ###  ####  ######	 #### #  ####  ###### ###### #    # --
--------------------------------------------------------------
--  		Ellonia Bot Version 0.1		--
------------------------------------------
--	Created by: Mellow_Ink	--
------------------------------

------------------------------------------
--  		Bot Initialization  		--
------------------------------------------  					   

local _G 					= getfenv(0)
local object 				= _G.object

object.myName 				= object:GetName()
object.bRunLogic			= true
object.bRunBehaviors		= true
object.bUpdates 			= true
object.bUseShop 		 	= true

object.bRunCommands 	 	= true 
object.bMoveCommands		= true
object.bAttackCommands  	= true
object.bAbilityCommands 	= true
object.bOtherCommands    	= true

object.bReportBehavior  	= false
object.bDebugUtility	 	= false

object.logger = {}
object.logger.bWriteLog  	= false
object.logger.bVerboseLog	= false

object.core 				= {}
object.eventsLib		 	= {}
object.metadata 			= {}
object.behaviorLib     		= {}
object.skills   	  		= {}

runfile "bots/core.lua"
runfile "bots/botBraincore.lua"
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

BotEcho(object:GetName()..' loading ellonia_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 2, ShortSolo = 1, LongSolo = 1, ShortSupport = 5, LongSupport = 4, ShortCarry = 2, LongCarry = 1}

---------------------------------
--  		Constants   	   --
---------------------------------

-- hero_ < hero >  to reference the internal hon name of a hero, Hero_Yogi == wildsoul
object.heroName = 'Hero_Ellonia'


-- item buy order. internal names  
behaviorLib.StartingItems  = {"Item_RunesOfTheBlight", "Item_MarkOfTheNovice", "Item_PretendersCrown", "Item_ManaPotion", "2 Item_MinorTotem"}
behaviorLib.LaneItems  = {"Item_Marchers", "Item_PowerSupply", "Item_Intelligence5", "Item_Replenish", "Item_MajorTotem"}
behaviorLib.MidItems  = {"Item_Steamboots", "Item_Weapon1", "Item_NomesWisdom", "Item_Manatube"}
behaviorLib.LateItems  = {"Item_Morph", "Item_HarkonsBlade", "Item_FrostfieldPlate", "Item_BehemothsHeart"}

-- skill build table, 0 = Glacial Spike, 1 = Frigid Field, 2 = Flash Freeze, 3 = Absolute Zero, 4 = Attribute
object.tSkills = {
	0, 2, 0, 2, 1,
	3, 0, 2, 0, 2,
	3, 1, 1, 1, 4,
	3, 4, 4, 4, 4,
	4, 4, 4, 4, 4}

-- bonus aggression points if a skill/item is available for use
object.nGlacialSpikeUp = 5
object.nFrigidFieldUp = 6
object.nFlashFreezeUp = 7
object.nAbsoluteZeroUp = 10
object.nSheepstickUp = 7
object.nFrostplateUp = 6

-- bonus aggression points that are applied to the bot upon successfully using a skill/item
object.nGlacialSpikeUse = 10
object.nFrigidFieldUse = 12
object.nFlashFreezeUse = 18
object.nAbsoluteZeroUse = 20
object.nSheepstickUse = 14
object.nFrostplateUse = 14

--thresholds of aggression the bot must reach to use these abilities
object.nGlacialSpikeThreshold = 24
object.nFrigidFieldThreshold = 24
object.nFlashFreezeThreshold = 35
object.nAbsoluteZeroThreshold = 40

--Quick fix for better returning to well ty Kairus
function HealAtWellUtilityOverride(botBrain)
	return object.HealAtWellUtilityOld(botBrain) + (botBrain:GetGold() * 8/2000)
end
object.HealAtWellUtilityOld = behaviorLib.HealAtWellBehavior["Utility"]
behaviorLib.HealAtWellBehavior["Utility"] = HealAtWellUtilityOverride


--#####################################################################
--#####################################################################
--##																 ##
--##   					Bot Function Overrides  					 ##
--##																 ##
--#####################################################################
--#####################################################################


------------------------------
--			skills			--
------------------------------
local bSkillsValid = false
function object:SkillBuild()
	core.VerboseLog("skillbuild()")

	local unitSelf = self.core.unitSelf
	if not bSkillsValid then
		skills.abilGlacialSpike = unitSelf:GetAbility(0)
		skills.abilFrigidField  = unitSelf:GetAbility(1)
		skills.abilFlashFreeze  = unitSelf:GetAbility(2)
		skills.abilAbsoluteZero = unitSelf:GetAbility(3)
		
		if skills.abilGlacialSpike and skills.abilFrigidField and skills.abilFlashFreeze and skills.abilAbsoluteZero then
			bSkillsValid = true
		else
			return
		end
	end
	
	local nPoints = unitSelf:GetAbilityPointsAvailable()
	if nPoints <= 0 then
		return
	end
	
	local nLevel = unitSelf:GetLevel()
	for i = nLevel, (nLevel + nPoints) do
		unitSelf:GetAbility(object.tSkills[i]):LevelUp()
	end
end

----------------------------------------------
--  		OnCombatEvent Override  		--
--   use to check for inflictions (buffs)   --
----------------------------------------------

function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)

	local nAddBonus = 0

	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_Ellonia1" then
			nAddBonus = nAddBonus + object.nGlacialSpikeUse
		elseif EventData.InflictorName == "Ability_Ellonia2" then
			nAddBonus = nAddBonus + object.nFrigidFieldUse
		elseif EventData.InflictorName == "Ability_Ellonia3" then
			nAddBonus = nAddBonus + object.nFlashFreezeUse
		elseif EventData.InflictorName == "Ability_Ellonia4" then
			nAddBonus = nAddBonus + object.nAbsoluteZeroUse
		end
	elseif EventData.Type == "Item" and EventData.SourceUnit == core.unitSelf:GetUniqueID() then
		local sInflictorName = EventData.InflictorName
		local itemFrostplate = core.GetItem("Item_FrostfieldPlate")
		local itemSheepstick = core.GetItem("Item_Morph")
		if itemSheepstick and  sInflictorName == itemSheepstick:GetName() then
			nAddBonus = nAddBonus + self.nSheepstickUse
		elseif itemFrostplate and sInflictorName == itemFrostplate:GetName() then
			nAddBonus = nAddBonus + self.nFrostplateUse
		end
	end

	if nAddBonus > 0 then
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent	= object.oncombateventOverride


------------------------------------------------------
--  		 CustomHarassUtility override   		--
--  change utility according to usable spells here  --
------------------------------------------------------

local function CustomHarassUtilityFnOverride(hero)
	local nUtility = 0
	
	if skills.abilGlacialSpike:CanActivate() then
		nUtility = nUtility + object.nGlacialSpikeUp
	end
	
	if skills.abilFrigidField:CanActivate() then
		nUtility = nUtility + object.nFrigidFieldUp
	end

	if skills.abilFlashFreeze:CanActivate() then
		nUtility = nUtility + object.nFlashFreezeUp
	end
	
	if skills.abilAbsoluteZero:CanActivate() then
		nUtility = nUtility + object.nAbsoluteZeroUp
	end
	
	local itemSheepstick = core.GetItem("Item_Morph")
	if itemSheepstick and itemSheepstick:CanActivate() then
		nUtility = nUtility + object.nSheepstickUp
	end

	local itemFrostplate = core.GetItem("Item_FrostfieldPlate")
	if itemFrostplate and itemFrostplate:CanActivate() then
		nUtility = nUtility + object.nFrostplateUp
	end
	
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride   


--------------------------------------------------------------
--  				   Harass Behaviour 					--
--  All code how to use abilities against enemies goes here --
--------------------------------------------------------------

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
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)    
	local bActionTaken = false
	
	local bIsMagicImmune = bCanSee and object.isMagicImmune(unitTarget)
	
	-- GlacialSpike
	local abilGlacialSpike = skills.abilGlacialSpike
	if abilGlacialSpike:CanActivate() and nLastHarassUtility > botBrain.nGlacialSpikeThreshold and not bIsMagicImmune then
			bActionTaken = core.OrderAbilityPosition(botBrain, abilGlacialSpike, vecTargetPosition)
	end

	-- FrigidField
	if not bActionTaken then
		local abilFrigidField = skills.abilFrigidField
		if abilFrigidField:CanActivate() and nLastHarassUtility > botBrain.nFrigidFieldThreshold and not bIsMagicImmune then
			bActionTaken = core.OrderAbilityPosition(botBrain, abilFrigidField, vecTargetPosition)
		end
	end

	-- FlashFreeze
	if not bActionTaken then
		local abilFlashFreeze = skills.abilFlashFreeze
		if abilFlashFreeze:CanActivate() and nLastHarassUtility > botBrain.nFlashFreezeThreshold and bCanSee and not bIsMagicImmune then
			bActionTaken = core.OrderAbilityEntity(botBrain, abilFlashFreeze, unitTarget)
		end
	end
	
	-- AbsoluteZero
	if not bActionTaken then
		local abilAbsoluteZero = skills.abilAbsoluteZero
		if abilAbsoluteZero:CanActivate() and nLastHarassUtility > botBrain.nAbsoluteZeroThreshold and not bIsMagicImmune then
			bActionTaken = core.OrderAbilityPosition(botBrain, abilAbsoluteZero, vecTargetPosition)
		end
	end

	-- Sheepstick
	if not bActionTaken then
		local itemSheepstick = core.GetItem("Item_Morph")
		if itemSheepstick and itemSheepstick:CanActivate() and bCanSee and not bIsMagicImmune then
			bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemSheepstick, unitTarget)
		end
	end
	
	-- Frostplate
	if not bActionTaken then
		local itemFrostplate = core.GetItem("Item_FrostfieldPlate")
		if itemFrostplate and itemFrostplate:CanActivate() then
		
			local nFrostplateRadius = 900
			if nTargetDistanceSq < (nFrostplateRadius * nFrostplateRadius) and not bIsMagicImmune then
				bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemFrostplate)
			end
		end
	end
	    
	--Default auto attack
	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end 
	
	return bActionTaken
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

--------------------
-- Magic immunity --
--------------------
function object.isMagicImmune(unit)
	local tStates = { "State_Item3E", "State_Predator_Ability2", "State_Jereziah_Ability2", "State_Rampage_Ability1_Self", "State_Rhapsody_Ability4_Buff", "State_Hiro_Ability1" }
	for _, sState in ipairs(tStates) do
		if unit:HasState(sState) then
			return true
		end
	end
	return false
end

-----------------------------------
--  		Custom Chat 		 --
-----------------------------------

core.tKillChatKeys = {
	"mellow_ink_ellonia_kill1",
	"mellow_ink_ellonia_kill2",
	"mellow_ink_ellonia_kill3",
}

core.tDeathChatKeys = {
	"mellow_ink_ellonia_death1",
	"mellow_ink_ellonia_death2",
	"mellow_ink_ellonia_death3",
}
BotEcho(object:GetName()..' finished loading ellonia_main')