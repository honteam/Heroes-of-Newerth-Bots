--Magebane Bot v 0.69 (yeah baby)

--[[----------------------------------------------------------------------------
--
--
--
--	  Magebane *RIP IN PEACE MANA*
--
--
--
------------------------------------------------------------------------------]]
--V 1.00
--Coded By: Pure`Light
--[[Current Issues:
		* Enemy team keeps dying
--]]


--Basic Statements--
local _G = getfenv(0)
local object = _G.object
object.myName = object:GetName()

object.bRunLogic		= true
object.bRunBehaviors	= true
object.bUpdates				 = true
object.bUseShop				 = true
object.bRunCommands	 = true
object.bMoveCommands	= true
object.bAttackCommands  = true
object.bAbilityCommands = true
object.bOtherCommands   = true

object.bReportBehavior = false  --TODO: Disable b/f release
object.bDebugUtility = false	--TODO: Disable b/f release
object.bDebugExecute = false	--TODO: Disable b/f release

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core			 = {}
object.eventsLib		= {}
object.metadata		 = {}
object.behaviorLib	  = {}
object.skills		   = {}

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

BotEcho('loading Magebane...')

-------------------
--	 Lanes	 --
-------------------
--Preferences (Most, Least): ShortCarry, LongCarry, Mid, ShortSolo, LongSolo, LongSup, ShortSup. != Jungle.
core.tLanePreferences = {Jungle = 0, Mid = 3, ShortSolo = 3, LongSolo = 2, ShortSupport = 1, LongSupport = 1, ShortCarry = 5, LongCarry = 4}
--Hero Declare
object.heroName = 'Hero_Javaras'

------------------------
--	 Item Build	 --
------------------------

behaviorLib.StartingItems =
  {"Item_RunesOfTheBlight", "Item_MinorTotem", "Item_LoggersHatchet", "Item_IronBuckler"}
behaviorLib.LaneItems =
  {"Item_Marchers", "Item_Steamboots", "Item_ElderParasite"}
behaviorLib.MidItems =
  { "Item_ManaBurn1", "Item_Brutalizer", "Item_ManaBurn2"}
behaviorLib.LateItems =
  { "Item_Freeze", "Item_Evasion", "Item_Damage9"}


--------------------------------------
--	 Levelling Order | Skills	 --
--------------------------------------
-- 0 = Mana Consumption 1 = Flash
-- 2 = Master of the Mantra	 3 = Mana Rift
-- 4 = Attribute Boost
object.tSkills = {
		1, 0, 0, 2, 0,
		3, 0, 1, 1, 1,
		3, 2, 2, 2, 4,
		3, 4, 4, 4, 4,
		4, 4, 4, 4, 4,
}

-------------------------------
--	 skill Declaration	 --
-------------------------------

local bSkillsValid = false
function object:SkillBuild()
-- takes care at load/reload, <name_#> to be replaced by some convenient name.
	local unitSelf = self.core.unitSelf

	if not bSkillsValid then
		skills.abilManaBurn			= unitSelf:GetAbility(0)
		skills.abilFlash			= unitSelf:GetAbility(1)
		skills.abilAura				= unitSelf:GetAbility(2)
		skills.abilManaRift			= unitSelf:GetAbility(3)

		if skills.abilManaBurn and skills.abilFlash and skills.abilAura and skills.abilManaRift then
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

-----------------------------------------
--	 Harass Utility Calculations	 --
-----------------------------------------



-- bonus aggression points if a skill/item is available for use

object.nFlashUp					= 13
object.nManaRiftUp				= 40
object.nEPup					= 15

-- bonus aggression points that are applied to the bot upon successfully using a skill/item

object.nFlashUse				= 45
object.nManaRiftUse				= 70
object.nEPUse					= 25

-- thresholds of aggression the bot must reach to use these abilities

object.nFlashThreshold		  = 35
object.nManaRiftThreshold	  = 50


-- Additional Modifiers (items, etc.)

--weight overrides (Melee?)
behaviorLib.nCreepPushbackMul		   = 0.3
behaviorLib.nTargetPositioningMul	   = 0.8


	--Ability is currently up

local function AbilitiesUpUtilityFn()
	local nUtility = 0

	if skills.abilFlash:CanActivate() then
		nUtility = nUtility + object.nFlashUp
	end

	if skills.abilManaRift:CanActivate() then
		nUtility = nUtility + object.nManaRiftUp
	end

	if object.itemElderParasite and object.itemElderParasite:CanActivate() then
		nUtility = nUtility + object.nEPUp
	end

	return nUtility
end

--Ability has been used
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)

	local addBonus = 0
	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_Magebane2" then
			addBonus = addBonus + object.nFlashUse
		end

		if EventData.InflictorName == "Ability_Magebane4" then
			addBonus = addBonus + object.nManaRiftUse
		end

			--Additional Modifiers; ex: Items
	elseif EventData.Type == "Item" then
		if core.itemElderParasite ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemElderParasite:GetName() then
			addBonus = addBonus + object.nEPUse
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

----------------------------
--	 harass actions	 --
----------------------------

local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = false
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
	local bSelfRooted = unitSelf:IsStunned() or unitSelf:IsImmobilized()
	--Le bActionTaken
	local bActionTaken = false

	--Ability Declares
	local abilManaBurn = skills.abilManaBurn
	local abilManaRift = skills.abilManaRift
	local abilFlash	= skills.abilFlash
	--Item Declares
			--ElderParasite
	local itemElderParasite = core.itemElderParasite

	--Ability1	  Flash
	if not bSelfRooted and nLastHarassUtility > botBrain.nFlashThreshold and abilFlash:CanActivate() then
		if bDebugEchos then BotEcho("  No action yet, checking time leap") end
			local vecTargetTraveling = nil
			if unitTarget.bIsMemoryUnit and unitTarget.lastStoredPosition then
				vecTargetTraveling = Vector3.Normalize(vecTargetPosition - unitTarget.lastStoredPosition)
			else
				local unitEnemyWell = core.enemyWell
				if unitEnemyWell then
					vecTargetTraveling = Vector3.Normalize(unitEnemyWell:GetPosition() - vecTargetPosition)
				end
			end

			local vecAbilityTarget = vecTargetPosition
			if vecTargetTraveling then
				vecAbilityTarget = vecTargetPosition + vecTargetTraveling
			end

			bActionTaken = core.OrderAbilityPosition(botBrain, abilFlash, vecAbilityTarget)
		end

		--Ability3	  ManaRift
		if not bActionTaken and abilManaRift:CanActivate() and nIsSighted then
		--Attempting to get ulti working
			if unitTarget:GetManaPercent() < .25 then
				bActionTaken = core.OrderAbilityEntity(botBrain, abilManaRift, unitTarget)
			end
		end

		--Elder Parasite
		if not bActionTaken and itemElderParasite then  --Activate EP if,
			if nTargetDistanceSq < (225 * 225) then --Target is close
				bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemElderParasite)	   --EP ACTIVATED
			elseif (core.NumberElements(tLocalEnemyHeroes) > 2) then		--Major Conflict is occurring,
				bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemElderParasite)	   --EP ACTIVATED
			end
		end


	if not bActionTaken then
			return object.harassExecuteOld(botBrain)
	end
	return bActionTaken
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

-----------------------------
--	 Retreat execute	 --
-----------------------------

--Modelled after Schnarchnase's GraveKeeper custom retreat code.
--  this is a great function to override with using retreating skills, such as blinks, travels, stuns or slows.

function behaviorLib.CustomRetreatExecute(botBrain)
	bActionTaken = false

	local unitSelf = core.unitSelf
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
		return false --No enemy to kill == NoJoy
	end
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
	if nCount > 1 or unitSelf:GetHealthPercent() < .25 then

		if bCanSeeUnit then

			local abilFlash = skills.abilFlash
			local bSelfRooted = unitSelf:IsStunned() or unitSelf:IsImmobilized()

			--Ability1	  Flash
			if not bSelfRooted and abilFlash:CanActivate() and behaviorLib.lastRetreatUtil > botBrain.nFlashThreshold then

				bActionTaken = core.OrderBlinkAbilityToEscape(botBrain, abilFlash)
			end
		end
	end -- critical situation


	--Activate ElderParasite for speed buff (also increases damage taken, but worth it)
	local itemElderParasite = core.itemElderParasite

	if not bActionTaken and itemElderParasite and itemElderParasite:CanActivate() then
		bActionTaken = core.OrderItemClamp(botBrain, core.unitSelf, itemElderParasite)
	end

	return bActionTaken
end

---------------------
--	 Pushing	 --
---------------------
--Modified from fane_macuica's RhapBot
function behaviorLib.customPushExecute(botBrain)
	local bSuccess = false
	local unitSelf = core.unitSelf

	local itemElderParasite = core.itemElderParasite

	local nMinimumCreeps = 4

	local vecCreepCenter, nCreeps = core.GetGroupCenter(core.localUnits["EnemyCreeps"])

	if vecCreepCenter == nil or nCreeps == nil or nCreeps < nMinimumCreeps then
		return false
	end

	--Activate ElderParasite when pushing (hopefully he is already hitting creeps)
	if itemElderParasite and itemElderParasite:CanActivate() then
		bActionTaken = core.OrderItemClamp(botBrain, core.unitSelf, itemElderParasite)
	end

	return bSuccess
end

-----------------------------------
--	 Heal At Well Override	 --
-----------------------------------
--2000 gold adds 6 to return utility, slightly reduced need to return.
--Modified from kairus101's BalphBot!
local function HealAtWellUtilityOverride(botBrain)
	local vecBackupPos = core.allyWell and core.allyWell:GetPosition() or behaviorLib.PositionSelfBackUp()

	local nGoldSpendingDesire = 6 / 2000

	if (Vector3.Distance2DSq(core.unitSelf:GetPosition(), vecBackupPos) < 400 * 400 and core.unitSelf:GetHealthPercent() * 100 < 15) then
		return 80
	end
	return object.HealAtWellUtilityOld(botBrain) + (botBrain:GetGold() * nGoldSpendingDesire) --courageously flee back to base.
end
object.HealAtWellUtilityOld = behaviorLib.HealAtWellBehavior["Utility"]
behaviorLib.HealAtWellBehavior["Utility"] = HealAtWellUtilityOverride


BotEcho('finished loading Magebane_main')