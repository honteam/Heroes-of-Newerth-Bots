--tarot Bot
--V: 1.05
--Coded By: ModernSaint

--Basic Statements--
local _G = getfenv(0)
local object = _G.object
object.myName = object:GetName()

object.bRunLogic   	= true
object.bRunBehaviors	= true
object.bUpdates 		= true
object.bUseShop 		= true
object.bRunCommands 	= true
object.bMoveCommands 	= true
object.bAttackCommands 	= true
object.bAbilityCommands = true
object.bOtherCommands 	= true

object.bReportBehavior = false
object.bDebugUtility = false
object.bDebugExecute = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core 		= {}
object.eventsLib 	= {}
object.metadata 	= {}
object.behaviorLib 	= {}
object.skills 		= {}

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

BotEcho('now loading tarot_main.lua ...')

------------------------------
--			Lanes			--
------------------------------

--Preferences (Most, Least): ShortCarry, LongCarry, Mid, ShortSolo, ShortSup, LongSup, LongSolo. != Jungle.
core.tLanePreferences = {Jungle = 0, Mid = 3, ShortSolo = 3, LongSolo = 1, ShortSupport = 2, LongSupport = 2, ShortCarry = 5, LongCarry = 4}

--Hero Declare
object.heroName = 'Hero_Tarot'

----------------------------------
--			Item Build			--
----------------------------------	

behaviorLib.StartingItems = 
  {"Item_RunesOfTheBlight", "Item_ManaPotion", "Item_LoggersHatchet", "Item_IronBuckler"}
--Starting items:   BightStones, ManaPotion, 2xMinorTotem, 2xDuckBoots (agi +3), 
behaviorLib.LaneItems = 
  {"Item_Marchers", "Item_Steamboots", "Item_ElderParasite"}
--Laning items: Marchers -> SteamBoots, ElderParasite
behaviorLib.MidItems = 
	{"Item_Sicarius", "Item_ManaBurn2", "Item_Immunity"} 
--Mid items: Firebrand, ManaBurn2 (Geomenter's Bane), Immunity (Shrunken Head)
behaviorLib.LateItems = 
	{"Item_Weapon3", "Item_Evasion", "Item_Damage9" } 
--Late items: Savage Mace, Item_Evasion (Wingbow), and Item_Damage9 (Doombringer)

----------------------------------
-- Levelling Order | Skills		--
----------------------------------
-- 0 = Ricochet	1 = Far_Scry
-- 2 = Bound_by_Fate	3 = Luck_of_the_Draw
-- 4 = Attribute Boost	

object.tSkills = {
	0, 1, 2, 0, 0,
	3, 0, 2, 2, 2, 
	3, 1, 1, 1, 4,
	3, 4, 4, 4, 4,
	4, 4, 4, 4, 4,
}

------------------------------------------
--			skill Declaration			--
------------------------------------------
local bSkillsValid = false
function object:SkillBuild()
-- takes care at load/reload, <name_#> to be replaced by some convenient name.
	local unitSelf = self.core.unitSelf
	
	if not bSkillsValid then
		skills.abilRicochet 		= unitSelf:GetAbility(0)
		skills.abilFarScry 			= unitSelf:GetAbility(1)
		skills.abilBoundByFate		= unitSelf:GetAbility(2)
		skills.abilLuckOfTheDraw 	= unitSelf:GetAbility(3)
		skills.abilAttributeBoost	= unitSelf:GetAbility(4)
		
		if skills.abilRicochet and skills.abilFarScry and skills.abilBoundByFate and skills.abilLuckOfTheDraw and skills.abilAttributeBoost then
			bSkillsValid = true
		else 
			return
		end
	end
	
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
    
	local nlev = unitSelf:GetLevel()
	local nlevpts = unitSelf:GetAbilityPointsAvailable()
	for i = nlev, nlev+nlevpts do
		unitSelf:GetAbility( object.tSkills[i] ):LevelUp()
	end
end

------------------------------------------
--		Harass Utility Calculations		--
------------------------------------------

-- bonus aggression points if a skill/item is available for use
object.nRicochetUp			= 35
object.nFarScryUp 			= 25
object.nBoundByFateUp		= 15
object.nEPup				= 15
object.nSicariusUp		= 10

-- bonus aggression points that are applied to the bot upon successfully using a skill/item
object.nRicochetUse			= 50
object.nFarScryUse 			= 30
object.nBoundByFateUse 		= 40
object.nChanceUse			= 30
object.nEPUse				= 25
object.nSicariusUse		=15

-- thresholds of aggression the bot must reach to use these abilities
object.nRicochetThreshold		= 40
object.nFarScryThreshold 		= 25
object.nBoundByFateThreshold	= 55
object.nEPThreshold				= 25
object.nSicariusThreshold	= 30

-- Additional Modifiers (items, etc.)

--weight overrides
behaviorLib.nCreepPushbackMul		= 0.3
behaviorLib.nTargetPositioningMul	= 0.8

	--Ability is currently up, add possible utility
local function AbilitiesUpUtilityFn()
	local nUtility = 0
	
	if skills.abilRicochet:CanActivate() then
		nUtility = nUtility + object.nRicochetUp
	end
	
	if skills.abilFarScry:CanActivate() then
		nUtility = nUtility + object.nFarScryUp
	end
	
	if skills.abilMarked:CanActivate() then
		nUtility = nUtility + object.nBoundByFateUp
	end
	
	if object.itemElderParasite and object.itemElderParasite:CanActivate() then
		nUtility = nUtility + object.nEPUp
	end
	
	if object.itemSicarius and object.itemSicarius:CanActivate() then
		nUtility = nUtility + object.nSicariusUp
	end
	
	return nUtility
	
end
	--Ability has been used, add a bonus!
function object:oncombateventOverride(EventData)
self:oncombateventOld(EventData)

	local addBonus = 0
	
	if EventData.Type == "Ability" then	
	
		if EventData.InflictorName == "Ability_Tarot1" then
			addBonus = addBonus + object.nRicochetUse
		end
	
		if EventData.InflictorName == "Ability_Tarot2" then
			addBonus = addBonus + object.nFarScryUse
		end

		if EventData.InflictorName == "Ability_Tarot3" then
			addBonus = addBonus + object.nBoundByFateUse
		end	
		--ulti is passive, but still has a resulting effect
		if EventData.InflictorName == "Ability_Tarot4" then
			addBonus = addBonus + object.nChanceUse
		end
		
		--Additional Modifiers; ex: Items
	elseif EventData.Type == "Item" then
		if core.itemElderParasite ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemElderParasite:GetName() then
			addBonus = addBonus + object.nEPUse
		end
		if core.itemSicarius ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemSicarius:GetName() then
			addBonus = addBonus + object.nSicariusUse
		end
	end

	if addBonus > 0 then
		--decay before we add
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + addBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent = object.oncombateventOverride

--------------------------------------
--			harass actions			--
--------------------------------------

local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = true
	--HunterKiller Sequencing
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
		return false --No enemy to kill == NoJoy
	end
	--Equations/TimeSavers
	local unitSelf = core.unitSelf
	local tLocalEnemyHeroes = core.localUnits["EnemyHeroes"]
	local vecMyPosition = unitSelf:GetPosition()
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local nIsSighted = core.CanSeeUnit(botBrain, unitTarget)
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized()
	--Le bActionTaken
	local bActionTaken = false
	--Ability Declares
	local abilBounce = skills.abilRicochet
	local abilSight = skills.abilFarScry
	local abilBind = skills.abilBoundByFate
	local abilChance = skills.abilLuckOfTheDraw
	--Item Declares
		--ElderParasite
	local itemElderParasite = core.itemElderParasite
	--Effective Hit Point Calculation--
	local GetHealthE = unitTarget:GetHealth()
	local MagicResist = unitTarget:GetMagicResistance()
	--local nEffectiveHP = ((MagicResist + 1) * GetHealthE)	--Sometimes reports MagicResist as a nil, discontinued due to error
	
	--Ability0	Ricochet
	--	Richochet causes multiple hits between targets in close range. It fairly
	--	expensive to cast, so restraints are in place for it to be used more conservitively.
	--	The ability can also output serious damage in teamfights.
	if abilBounce:CanActivate() and nIsSighted then
		local nRange = abilBounce:GetRange()
		if nTargetDistanceSq < (nRange * nRange) then	--Target is in range
			--Target is near death or utility larger than Threshold or self's mana is over 80% 
			--	or Major Conflict is occurring or self is near death
			if (GetHealthE < 180) 
			  or (nLastHarassUtility > botBrain.nRicochetThreshold) 
			  or (unitSelf:GetManaPercent() > 0.80 ) 
			  or (core.NumberElements(tLocalEnemyHeroes) > 2)  
			  or (unitSelf:GetHealthPercent() < 0.10) then	
				bActionTaken = core.OrderAbilityEntity(botBrain, abilBounce, unitTarget)	--Execute, Target
			end
		end
	end
	
	--Ability1	FarScry
	--	Farscry is primarily a harassive ability that allows tarot to bounce hits 
	--	from any enemy hit towards a target under its effect. due to its long range
	--	and cheap cost this ability is ideal for spamming. It also has the potential
	-- 	to whittle down enemies during a teamfight.
	if not bActionTaken and abilSight:CanActivate() and nIsSighted then
		local nRange = abilSight:GetRange()
		if (nTargetDistanceSq < (nRange * nRange)) then	--At least a single target is in range,
			--Target is slightly wounded or Utility larger than Threshold or mana is below 65% 
			--	or Major Conflict is occurring or self is near death
			if (GetHealthE < 350) 
			  or (nLastHarassUtility > botBrain.nFarScryThreshold) 
			  or (unitSelf:GetManaPercent() > .65 ) 
			  or (core.NumberElements(tLocalEnemyHeroes) > 2)  then	
				bActionTaken = core.OrderAbilityEntity(botBrain, abilSight, unitTarget)	--Execute, Target
			end
		end
	end
	
	--Ability2	BoundByFate
	--	BoundByFate tethers two units to each other and, if the tether is broken,
	--	stuns and damages the targets. This can be useful when fighting high mobility
	--	enemies and for forcing enemy positioning. It also applies a blunt 5% slow on
	--	any unit under its effect, even if it is not tethered to a target.
	if not bActionTaken and abilBind:CanActivate() and nIsSighted then
		local nRange = abilBind:GetRange()
		if nTargetDistanceSq < (nRange * nRange) and (core.NumberElements(tLocalEnemyHeroes) > 1) then	--At least two targets is in range,
			--Target is slightly wounded or Utility larger than Threshold or mana is below 80% 
			if (nLastHarassUtility > botBrain.nBoundByFateThreshold) 
			  or (unitSelf:GetManaPercent() > 0.80 )  then
				bActionTaken = core.OrderAbilityEntity(botBrain, abilBind, unitTarget)	--Execute, Target
			end
		elseif nTargetDistanceSq < (nRange * nRange) then	--a single target is in range
			--Target is near death (likely fleeing
			if (unitTarget:GetHealthPercent() < 0.25) then
				bActionTaken = core.OrderAbilityEntity(botBrain, abilBind, unitTarget)	--Execute, Target
			end
		end
	end
	
	--Elder Parasite
	if not bActionTaken and itemElderParasite then	--Activate EP if,
		if nTargetDistanceSq < (225 * 225) then	--Target is close
			bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemElderParasite)	--EP ACTIVATED
		elseif (core.NumberElements(tLocalEnemyHeroes) > 2) then	--Major Conflict is occurring,
			bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemElderParasite)	--EP ACTIVATED
		end
	end
	
	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

--------------------------------------
--			Retreat execute			--
--------------------------------------
--Modelled after Schnarchnase's GraveKeeper custom retreat code.
--  this is a great function to override with using retreating skills, such as blinks, travels, stuns or slows.
--Allows tarot to cast spells while retreating if enemies are pursuing her. The current supported spells are
--	Richochet(bounce) and BoundByFate(Bind).
function behaviorLib.CustomRetreatExecute(botBrain)
	bActionTaken = false

	local unitSelf = core.unitSelf
	local unitTarget = behaviorLib.heroTarget
	local vecRetreatPos = behaviorLib.PositionSelfBackUp()
	
	--Counting the enemies
	local tEnemies = core.localUnits["EnemyHeroes"]
	local nCount = 0

	local bCanSeeUnit = unitTarget and core.CanSeeUnit(botBrain, unitTarget)
	for id, unitEnemy in pairs(tEnemies) do
		if core.CanSeeUnit(botBrain, unitEnemy) then
			nCount = nCount + 1
		end
	end

	-- More enemies or low on life
	if nCount > 1 or unitSelf:GetHealthPercent() < .35 then

		if bCanSeeUnit then
			local vecMyPosition = unitSelf:GetPosition()
			local vecTargetPosition = unitTarget:GetPosition()
			
			local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
			local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized()
			
			local abilBounce = skills.abilRicochet
			local abilBind = skills.abilBoundByFate
			
			--Bounce
			if abilBounce:CanActivate() then
				local nRange = abilBounce:GetRange()	--target in range
				if nTargetDistanceSq < (nRange * nRange) and not bTargetRooted then	--Target is in range and not already rooted,
					bActionTaken = core.OrderAbilityEntity(botBrain, abilBounce, unitTarget)	--Execute, Target
				end
			--Bind
			elseif not bActionTaken and abilBind:CanActivate() then
				local nRange = abilBind:GetRange()
				if nTargetDistanceSq < (nRange * nRange) and not bTargetRooted then	--Target is in range and not already rooted,
					bActionTaken = core.OrderAbilityEntity(botBrain, abilBind, unitTarget)	--Execute, Target
				end
			end
		end
	end -- critical situation RIP

	--Activate ElderParasite for speed buff (also increases damage taken, but worth it)
	local itemElderParasite	= core.itemElderParasite
	
	if not bActionTaken and itemElderParasite and itemElderParasite:CanActivate() then
		bActionTaken = core.OrderItemClamp(botBrain, core.unitSelf, itemElderParasite)
	end
	--Activate Geo's for disjoint and illusion blocking
	local itemSicarius	= core.itemSicarius
	
	if not bActionTaken and itemSicarius and itemSicarius:CanActivate() then
		bActionTaken = core.OrderItemClamp(botBrain, core.unitSelf, itemSicarius)
	end

	bActionTaken = core.OrderMoveToPosClamp(botBrain, core.unitSelf, vecRetreatPos, false)
	
	return bActionTaken
end

------------------------------
--			Pushing			--
------------------------------
--Modified from fane_macuica's RhapBot
--Allows tarot to use spells on creeps to increase farming capability. Richochet is the
--	only supported spell.
function behaviorLib.customPushExecute(botBrain)

	local bSuccess = false
	local unitSelf = core.unitSelf
	
	local abilBounce = skills.abilRicochet
	local itemElderParasite = core.itemElderParasite
	local itemSicarius	= core.itemSicarius
	
	local nMinimumCreeps = 4

	local vecCreepCenter, nCreeps = core.GetGroupCenter(core.localUnits["EnemyCreeps"])
	
	local unitTarget = behaviorLib.creepTarget
	
	--Not enough creeps to bother casting
	if nCreeps < nMinimumCreeps then 
		return false
	end
	
	--don't use bounce if low on health and mana, it is assumed all creeps are bunched close enough to cause bounces
	if abilBounce:CanActivate() and (unitSelf:GetManaPercent() > 0.15) and (unitSelf:GetHealthPercent() > 0.20) then 
		bSuccess = core.OrderAbilityEntity(botBrain, abilBounce, unitTarget)	--Execute, Target
	end
	
	--Activate ElderParasite when pushing (hopefully he is already hitting creeps)
	if itemElderParasite and itemElderParasite:CanActivate() then
		bActionTaken = core.OrderItemClamp(botBrain, core.unitSelf, itemElderParasite)
	end
	
	--Activate Geo's for illusion auto attacks
	if not bActionTaken and itemSicarius and itemSicarius:CanActivate() then
		bActionTaken = core.OrderItemClamp(botBrain, core.unitSelf, itemSicarius)
	end
	
	return bSuccess
end



----------------------------------------------
--			Heal At Well Override			--
----------------------------------------------
--2000 gold adds 6 to return utility, slightly reduced need to return.
--Modified from kairus101's BalphBot!
local function HealAtWellUtilityOverride(botBrain)
	local vecBackupPos = core.allyWell and core.allyWell:GetPosition() or behaviorLib.PositionSelfBackUp()

	local nGoldSpendingDesire = 6 / 2000
	
	if (Vector3.Distance2DSq(core.unitSelf:GetPosition(), vecBackupPos) < 400 * 400) and core.unitSelf:GetHealthPercent() * 100 < 15 then
		return 80
	end
	return object.HealAtWellUtilityOld(botBrain) + (botBrain:GetGold() * nGoldSpendingDesire) --courageously flee back to base.
end
object.HealAtWellUtilityOld = behaviorLib.HealAtWellBehavior["Utility"]
behaviorLib.HealAtWellBehavior["Utility"] = HealAtWellUtilityOverride

------------------------------
---			Extras			--
------------------------------

--[[ colors:
	red
	aqua == cyan
	gray
	navy
	teal
	blue
	lime
	black
	brown
	green
	olive
	white
	silver
	purple
	salmon
	pink
	maroon
	yellow
	orange
	fuchsia == magenta
	invisible
--]]


BotEcho('finished loading tarot_main.lua')
