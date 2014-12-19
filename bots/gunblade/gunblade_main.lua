-----------------------------------------------------------------------------
--	 _________                   __        _                 __  
--	/   _____ |                 |  |      | |               |  |  
--	|  /    |_|                 |  |      | |               |  |   
--	| |          _   _   _      |  |___   | |   ____     ___|  |   ___
--	| |    ____ | | | | | |___  |   _  \  | |  / _  \   /  _   |  / _ \
--	|  \___\  / | \_/ | |  _  | |  |_|  | | | | /_|  \ |  |_|  | |  __/
--	\________/   \___/  |_| |_|  \_____/  |_|  \___/\_\ \______/  \___|
------------------------------------------------------------------------------
--V 1.05
--Coded By: ModernSaint
--Basic Equations--
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

BotEcho('loading Gunbladebot...')

--------------------------------
-- Lanes
--------------------------------

core.tLanePreferences = {Jungle = 0, Mid = 5, ShortSolo = 3, LongSolo = 1, ShortSupport = 2, LongSupport = 2, ShortCarry = 4, LongCarry = 4}

object.heroName = 'Hero_Gunblade'

----------------------------------
--	Item Build
----------------------------------	

behaviorLib.StartingItems = 
  {"Item_RunesOfTheBlight", "Item_ManaPotion", "Item_HealthPotion", "Item_DuckBoots"}
behaviorLib.LaneItems = 
  {"Item_Marchers",  "Item_Soulscream", "Item_EnhancedMarchers"}
behaviorLib.MidItems = 
  { "Item_Energizer", "Item_Lightning2", "Item_Critical1 4", "Item_SolsBulwark"}
behaviorLib.LateItems = 
  { "Item_Evasion", "Item_DaemonicBreastplate", "Item_Weapon3"}

--------------------------------
-- Skills
--------------------------------

local bSkillsValid = false
function object:SkillBuild()

	local unitSelf = self.core.unitSelf

	if not bSkillsValid then
		skills.CripplingSlugs = unitSelf:GetAbility(0)
		skills.DemonicShield = unitSelf:GetAbility(1)
		skills.LethalRange = unitSelf:GetAbility(2)
		skills.GrapplingShot = unitSelf:GetAbility(3)
		skills.attributeBoost = unitSelf:GetAbility(4)
		
		if skills.CripplingSlugs and skills.DemonicShield and skills.GrapplingShot and skills.attributeBoost then
			bSkillsValid = true
		else
			return
		end
	end
		
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	--Leveling order:
	if not (skills.CripplingSlugs:GetLevel() >= 1) then --CS to lvl 1
		skills.CripplingSlugs:LevelUp()
	elseif not (skills.DemonicShield:GetLevel() >= 1) then --DS to lvl 1
		skills.DemonicShield:LevelUp()
	elseif not (skills.LethalRange:GetLevel() >= 3) then --LR to lvl 2
		skills.LethalRange:LevelUp()
	--Will maximize ability is in this order.
	elseif skills.GrapplingShot:CanLevelUp() then
		skills.GrapplingShot:LevelUp()
	elseif skills.CripplingSlugs:CanLevelUp() then
		skills.CripplingSlugs:LevelUp()
	elseif skills.LethalRange:CanLevelUp() then
		skills.LethalRange:LevelUp()
	elseif skills.DemonicShield:CanLevelUp() then
		skills.DemonicShield:LevelUp()
	else
		skills.attributeBoost:LevelUp()
	end	
end

----------------------------------
--	Harass Bonuses
----------------------------------

-- bonus agression points if a skill/item is available for use
object.nCripplingSlugsUp = 20
object.nDemonicShieldUp = 12
object.nGrapplingShotUp = 22
object.nEnergizerUp = 10

-- bonus agression points that are applied to the bot upon successfully using a skill/item
object.nCripplingSlugsUse = 18
object.nDemonicShieldUse = 14
object.nGrapplingShotUse = 30
object.nEnergizerUse = 13

-- thresholds of aggression the bot must reach to use these abilities
object.nCripplingSlugsThreshold = 24
object.nDemonicShieldThreshold = 22
object.nGrapplingShotThreshold = 34
object.nEnergizerThreshold = 12

-- Additional Modifiers

--weight overrides
behaviorLib.nCreepPushbackMul = 1
behaviorLib.nTargetPositioningMul = 1

local function AbilitiesUpUtilityFn()
	local val = 0
	
	if skills.CripplingSlugs:CanActivate() then
		val = val + object.nCripplingSlugsUpBonus
	end
	if skills.DemonicShield:CanActivate() then
		val = val + object.nDemonicShieldUpBonus
	end
	if skills.GrapplingShot:CanActivate() then
		val = val + object.nGrapplingShotUpBonus
	end
	if core.itemEnergizer and core.itemEnergizer:CanActivate() then
		val = val + object.nEnergizerUp
	end
	
	return val
end

function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local addBonus = 0
	
	if EventData.Type == "Ability" then	
		if EventData.InflictorName == "Ability_Gunblade1" then
			addBonus = addBonus + object.nCripplingSlugsUse
		end
		if EventData.InflictorName == "Ability_Gunblade2" then
			addBonus = addBonus + object.nDemonicShieldUse
		end
		if EventData.InflictorName == "Ability_Gunblade4" then
			addBonus = addBonus + object.nGrapplingShotUse
		end
	
	elseif EventData.Type == "Item" then
		if core.itemEnergizer ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemEnergizer:GetName() then
			addBonus = addBonus + self.nEnergizerUse
		end
	end

	
	if addBonus > 0 then
		--decay before we add
		core.DecayBonus(self)
	
		core.nHarassBonus = core.nHarassBonus + addBonus
	end
end

object.oncombateventOld = object.oncombatevent
object.oncombatevent 	= object.oncombateventOverride

----------------------------------
--	harass actions
----------------------------------

local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = false
	
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
		return false --can not execute, move on to the next behaviour
	end
	
	local unitSelf = core.unitSelf
	
	local nAttackRange = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
	local nAttackRangeSq = nAttackRange * nAttackRange

	local vecMyPosition = unitSelf:GetPosition()	
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	
	local bActionTaken = false
	local abilDemonicShield = skills.DemonicShield
	local abilCripplingSlugs = skills.CripplingSlugs
	local abilGrapplingShot = skills.GrapplingShot
	core.itemEnergizer = core.GetItem("Item_Energizer")
	
	--Energizer
	if core.itemEnergizer and core.itemEnergizer:CanActivate() and (nLastHarassUtility > object.nEnergizerThreshold) then
		botBrain:OrderItem(core.itemEnergizer.object or core.itemEnergizer, false)
	end
	
	--GrapplingShot
	if (nLastHarassUtility > object.nGrapplingShotThreshold) and abilGrapplingShot:CanActivate() then
		local nRange = abilGrapplingShot:GetRange()
		if nTargetDistanceSq < (nRange * nRange) then
			bActionTaken = core.OrderAbilityEntity(botBrain, abilGrapplingShot, unitTarget)
		else  --if not in range get closer. Speed items will be activated as well as DS b/c chances are he will take damage.			
			if itemGhostMarchers and itemGhostMarchers:CanActivate() then
				core.OrderItemClamp(botBrain, itemGhostMarchers) --activate GM
			end
			if abilDemonicShield:CanActivate() then --activate DemonicShield
				bActionTaken = core.OrderAbility(botBrain, abilDemonicShield)
			end
			if not bActionTaken and behaviorLib.lastHarassUtil < behaviorLib.diveThreshold then --Check willingness to dive towers
				local desiredPos = core.AdjustMovementForTowerLogic(vecTargetPosition)
				core.OrderMoveToPosClamp(botBrain, unitSelf, desiredPos, false) --Move order to close in
			end
				bActionTaken = true
		end
	end
	
	--CripplingSlugs
	if not bActionTaken and nLastHarassUtility > object.nCripplingSlugsThreshold then
		if abilCripplingSlugs:CanActivate() then
			local nRange = abilCripplingSlugs:GetRange()
			if nTargetDistanceSq < ((nRange * nRange) * .80) and (unitSelf:GetManaPercent() > .45 or unitTarget:GetHealth() < .60) then --Reserves some mana, unless a kill is likely 
				bActionTaken = core.OrderAbilityPosition(botBrain, abilCripplingSlugs, vecTargetPosition)
			elseif nTargetDistanceSq < (nAttackRangeSq * .30) then --Use ability if an enemy is close
				bActionTaken = core.OrderAbilityPosition(botBrain, abilCripplingSlugs, vecTargetPosition)		
			end
		end
	end
	
	--DemonicShield
	if not bActionTaken and abilDemonicShield:CanActivate() then
		if (nLastHarassUtility > object.nDemonicShieldThreshold and (.45 > unitSelf:GetHealthPercent() or core.NumberElements(tLocalEnemyHeroes)) > 0) or (core.NumberElements(tLocalEnemyHeroes) > 2) then--activate on utility calc or if more than 2 hostiles nearby or lower than 45% health with an enemy nearby
			bActionTaken = core.OrderAbility(botBrain, abilDemonicShield)
		end
	end
	
	if not bActionTaken then
		if bDebugEchos then BotEcho("  No action yet, proceeding with normal harass execute.")end
		return object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

----------------------------------------
--  	Retreat Behaviour   	  --
----------------------------------------

function behaviorLib.CustomRetreatExecute(botBrain)
	
	--Energizer use
	if itemEnergizer and itemEnergizer:CanActivate() and behaviorLib.lastRetreatUtil >= object.nEnergizerThreshold then
		botBrain:OrderItem(core.itemEnergizer.object or core.itemEnergizer, false)
	end
	--Use demonicSheild when fleeing
	local abilDemonicShield = skills.DemonicShield
	if (abilDemonicShield:CanActivate() and behaviorLib.lastRetreatUtil >= object.nDemonicShieldThreshold) then
		core.OrderAbility(botBrain, abilDemonicShield)
	end
	
	return false
end

----------------------------------------------------
--  	   Heal At Well Override		  --
----------------------------------------------------

--2000 gold adds 6 to return utility, slightly reduced need to return.
--Modified from kairus101's BalphBot!
local function HealAtWellUtilityOverride(botBrain)
	local vecBackupPos = core.allyWell and core.allyWell:GetPosition() or behaviorLib.PositionSelfBackUp()

	local nGoldSpendingDesire = 6 / 2000
	
	if (Vector3.Distance2DSq(core.unitSelf:GetPosition(), vecBackupPos) < 400 * 400 and core.unitSelf:GetManaPercent() * 100 < 95) then
		return 80
	end
	return object.HealAtWellUtilityOld(botBrain) + (botBrain:GetGold() * nGoldSpendingDesire) --courageously flee back to base.
end

--When returning to well, use skills and items.
function behaviorLib.CustomReturnToWellExecute(botBrain)
	local bAction = false
	local abilDemonicShield = skills.DemonicShield
	if abilDemonicShield:CanActivate() then --activate shield when heading back
		bAction = core.OrderAbility(botBrain, abilDemonicShield)
	end
	if itemEnergizer and itemEnergizer:CanActivate() and behaviorLib.lastRetreatUtil >= object.nEnergizerThreshold then
		botBrain:OrderItem(core.itemEnergizer.object or core.itemEnergizer, false)
	end
	return false
end
object.HealAtWellUtilityOld = behaviorLib.HealAtWellBehavior["Utility"]
behaviorLib.HealAtWellBehavior["Utility"] = HealAtWellUtilityOverride

BotEcho('finished loading Gunblade_main')



----------------------------------------
--- Extras
----------------------------------------

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
	maroon
	yellow
	orange
	fuchsia == magenta
	invisible
--]]
