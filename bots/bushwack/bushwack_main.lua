--BushwackBot v 1.0
--Coded by `IceCube`

local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic 		= true
object.bRunBehaviors	= true
object.bUpdates 		= true
object.bUseShop 		= true

object.bRunCommands 	= true 
object.bMoveCommands 	= true
object.bAttackCommands 	= true
object.bAbilityCommands = true
object.bOtherCommands 	= true

object.bReportBehavior = true
object.bDebugUtility = true
object.bDebugExecute = true

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

BotEcho('loading bushwack_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 5, ShortSolo = 3, LongSolo = 1, ShortSupport = 2, LongSupport = 2, ShortCarry = 4, LongCarry = 3}

object.heroName = 'Hero_Bushwack'

--------------------------------
-- Skills
--------------------------------
function object:SkillBuild()

	local unitSelf = self.core.unitSelf

	if skills.abilDart	== nil then
		skills.abilDart = unitSelf:GetAbility(0)
		skills.abilJump = unitSelf:GetAbility(1)
		skills.abilSplit = unitSelf:GetAbility(2)
		skills.abilToxin = unitSelf:GetAbility(3)
		skills.attributeBoost = unitSelf:GetAbility(4)
	end
	
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	if skills.abilToxin:CanLevelUp() then
		skills.abilToxin:LevelUp()		
	elseif skills.abilDart:CanLevelUp() then
		skills.abilDart:LevelUp()
	elseif skills.abilJump:GetLevel() < 1 then
		skills.abilJump:LevelUp()
	elseif skills.abilSplit:CanLevelUp() then
		skills.abilSplit:LevelUp()	
	elseif skills.abilJump:CanLevelUp() then
		skills.abilJump:LevelUp()
	else
		skills.attributeBoost:LevelUp()
	end	
end

---------------------------------------------------
--                   Utilities                   --
---------------------------------------------------

-- bonus aggression points if a skill/item is available for use
object.nDartUp = 10
object.nJumpUp = 10
object.nEnergizerUp = 8
-- bonus aggression points that are applied to the bot upon successfully using a skill/item
object.nDartUse = 10
object.nJumpUse = 10
object.nEnergizerUse = 10
--thresholds of aggression the bot must reach to use these abilities
object.nDartThreshold = 20
object.nJumpThreshold = 20
object.nEnergizerThreshold = 18
----------------------------------------------
--  		  oncombatevent override		--
----------------------------------------------
local function AbilitiesUpUtilityFn()
	local val = 0

	if skills.abilDart:CanActivate() then
		val = val + object.nDartUp
	end
	
	if skills.abilJump:CanActivate() then
		val = val + object.nJumpUp
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
		if EventData.InflictorName == "Ability_Bushwack1" then
			addBonus = addBonus + object.nDartUse
		end

		if EventData.InflictorName == "Ability_Bushwack2" then
			addBonus = addBonus + object.nJumpUse
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
object.oncombatevent = object.oncombateventOverride

----------------------------------
--	Bushwack harass actions
----------------------------------
local function HarassHeroExecuteOverride(botBrain)
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
		return false --can not execute, move on to the next behavior
	end
	
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bActionTaken = false
	local abilDart = skills.abilDart
	local abilJump = skills.abilJump
	
		--Jump
	local nRange = abilJump:GetRange()
	if abilJump:CanActivate() and nTargetDistanceSq < ((nRange * nRange) * 4) and  nLastHarassUtility > botBrain.nJumpThreshold then
		 
		local vecAbilityTarget = unitTarget:GetPosition()
		bAction = core.OrderAbilityPosition(botBrain, abilJump, vecAbilityTarget)
	end	
		
		--Dart
	if not bActionTaken and abilDart:CanActivate()then
		if ( nLastHarassUtility > botBrain.nDartThreshold and unitSelf:GetMana() > 0.80 ) or ( unitTarget:GetHealth() < 0.45 )  then
			local nRange = abilDart:GetRange()
			if nTargetDistanceSq < (nRange * nRange) then  --Dart if target is in range
				bActionTaken = core.OrderAbilityEntity(botBrain, abilDart, unitTarget)
			elseif abilJump:CanActivate() and nTargetDistanceSq > (nRange * nRange) then --Jump at target in range
				local vecAbilityTarget = unitTarget:GetPosition()
				bAction = core.OrderAbilityPosition(botBrain, abilJump, vecAbilityTarget)
			end		
		end
	end
		--Energizer
	if core.itemEnergizer and core.itemEnergizer:CanActivate() and (nLastHarassUtility > object.nEnergizerThreshold) then
		botBrain:OrderItem(core.itemEnergizer.object or core.itemEnergizer, false)
	end
	
	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end	
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

----------------------------------------------------
-- Heal At Well Override --
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

	if itemEnergizer and itemEnergizer:CanActivate() and behaviorLib.lastRetreatUtil >= object.nEnergizerThreshold then
		botBrain:OrderItem(core.itemEnergizer.object or core.itemEnergizer, false)
	end

	return false
end
object.HealAtWellUtilityOld = behaviorLib.HealAtWellBehavior["Utility"]
behaviorLib.HealAtWellBehavior["Utility"] = HealAtWellUtilityOverride

----------------------------------
--	Bushwack items
----------------------------------
behaviorLib.StartingItems = {"2 Item_DuckBoots", "2 Item_MinorTotem", "Item_HealthPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = 
	{"Item_Marchers", "Item_Soulscream", "Item_Steamboots"}
behaviorLib.MidItems = 
	{"Item_Energizer", "Item_ElderParasite", "item_Lighting1", "Item_DawnBringer"} 
behaviorLib.LateItems = 
	{"Item_Weapon3", "Item_Evasion", "item_Immunity", "item_lighting2"} 

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
	lilac
	fuchsia == magenta
	invisible
--]]

BotEcho('finished loading bushwack_main')
