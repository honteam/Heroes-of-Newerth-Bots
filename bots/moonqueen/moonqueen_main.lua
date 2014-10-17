-- MoonQueenBot v1.0

-- By community member Anakonda


--####################################################################
--####################################################################
--#                                                                 ##
--#                       Bot Initiation                            ##
--#                                                                 ##
--####################################################################
--####################################################################

local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic         = true
object.bRunBehaviors    = true
object.bUpdates         = true
object.bUseShop         = true

object.bRunCommands     = true 
object.bMoveCommands     = true
object.bAttackCommands     = true
object.bAbilityCommands = true
object.bOtherCommands     = true

object.bReportBehavior = false
object.bDebugUtility = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core         = {}
object.eventsLib     = {}
object.metadata     = {}
object.behaviorLib     = {}
object.skills         = {}

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

object.SteamBootsLib = object.SteamBootsLib or {}
local SteamBootsLib = object.SteamBootsLib

BotEcho(' loading Moon Queen')

-----------------------
-- bot "global" vars --
-----------------------

--Constants
object.heroName = 'Hero_Krixi'
behaviorLib.diveThreshold = 85

-- skillbuild table, 0=beam, 1=bounce, 2=aura, 3=ult, 4=attri
object.tSkills = {
    2, 0, 0, 1, 0,
    3, 0, 2, 2, 1,
    3, 2, 1, 1, 4,
    3, 4, 4, 4, 4,
    4, 4, 4, 4, 4,
}

----------------------------------
--	MoonQueen specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------
object.nMoonbeamUpBonus = 5
object.nUltUpBonus = 20
object.nGeometerUpBonus = 5

object.nGeometerUseBonus = 15
object.nUltUseBonus = 65
object.nBeamUseBonus = 5
object.nSymbolofRageUseBonus = 50


object.nMoonbeamThreshold = 45
object.tUltThresholds = {95, 85, 75}

--BreakPotion with MoonBeam Treshoold
object.nBreakPotionManaPercentTreshold = 0.5

--item options
behaviorLib.nGeometersThreshhold = 55
behaviorLib.nGeometersRetreatThreshhold = 50

--   item buy order.
behaviorLib.StartingItems  = {"2 Item_DuckBoots", "2 Item_MinorTotem", "Item_HealthPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems  = {"Item_Marchers", "Item_HelmOfTheVictim", "Item_Steamboots"}
behaviorLib.MidItems  = {"Item_Sicarius", "Item_WhisperingHelm", "Item_Immunity"}
behaviorLib.LateItems  = {"Item_ManaBurn2", "Item_LifeSteal4", "Item_Evasion"}

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 3, ShortSolo = 4, LongSolo = 2, ShortSupport = 1, LongSupport = 1, ShortCarry = 5, LongCarry = 4}

------------------------------
--     skills               --
------------------------------
local bSkillsValid = false
function object:SkillBuild()
  core.VerboseLog("skillbuild()")

	local unitSelf = self.core.unitSelf
	if not bSkillsValid then
		skills.abilMoonbeam		= unitSelf:GetAbility(0)
		skills.abilBounce		= core.WrapInTable(unitSelf:GetAbility(1))
		skills.abilAura			= core.WrapInTable(unitSelf:GetAbility(2))
		skills.abilMoonFinale	= unitSelf:GetAbility(3)

		--To keep track status of 2nd and 3rd skill
		skills.abilBounce.bTargetAll = true
		skills.abilAura.bTargetAll = true
		
		if skills.abilMoonbeam and skills.abilBounce and skills.abilAura and skills.abilMoonFinale then
			bSkillsValid = true
		else
			return
		end		
	end
	
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end

	local nLev = unitSelf:GetLevel()
	local nLevPts = unitSelf:GetAbilityPointsAvailable()
	for i = nLev, nLev+nLevPts do
		unitSelf:GetAbility( object.tSkills[i] ):LevelUp()

		--initialy set aura and bounce to heroes only
		if i == 1 then
			object.toggleAura(self, false)
		elseif i == 4 then
			object.toggleBounce(self, false)
		end
	end
end

---------------------------
--    onthink override   --
-- Called every bot tick --
---------------------------
object.nCustomThinkInterval = 5
function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)
	local unitSelf = core.unitSelf
	if unitSelf:IsAlive() and core.localUnits~=nil then
		if object.nCustomThinkInterval ~=0 then
			object.nCustomThinkInterval = object.nCustomThinkInterval - 1
		else
			object.nCustomThinkInterval = 5
			local itemSteamBoots = core.GetItem("Item_Steamboots")
			if itemSteamBoots then
				local sCurrentAttribute = SteamBootsLib.getAttributeBonus()
				if sCurrentAttribute ~= "" and sCurrentAttribute ~= SteamBootsLib.sDesiredAttribute then
					self:OrderItem(itemSteamBoots.object, "None")
				end
			end
		end
	end
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride

---------------------------
-- Togle aura and bounce --
---------------------------
function behaviorLib.customPushExecute(botBrain)
	object.toggleBounce(botBrain, true)
	object.toggleAura(botBrain, true)
	SteamBootsLib.setAttributeBonus("agi")
	return false
end

function behaviorLib.PositionSelfExecuteOverride(botBrain)
	object.toggleBounce(botBrain, false)
	object.toggleAura(botBrain, false)
	behaviorLib.PositionSelfExecuteOld(botBrain)
end
behaviorLib.PositionSelfExecuteOld = behaviorLib.PositionSelfBehavior["Execute"]
behaviorLib.PositionSelfBehavior["Execute"] = behaviorLib.PositionSelfExecuteOverride

----------------------------
-- oncombatevent override --
----------------------------

function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)

	local nAddBonus = 0
	if EventData.Type == "Ability" then	
		if EventData.InflictorName == "Ability_Krixi1" then
			nAddBonus = nAddBonus + object.nBeamUseBonus
		elseif EventData.InflictorName == "Ability_Krixi4" then
			nAddBonus = nAddBonus + object.nUltUseBonus
		end
	elseif EventData.Type == "Item" then
		local sInflictorName = EventData.InflictorName
		local itemGeometer = core.GetItem("Item_ManaBurn2")
		local itemSymbolOfRage = core.GetItem("Item_LifeSteal4")
		if itemGeometer and sInflictorName == itemGeometer:GetName() then
			nAddBonus = nAddBonus + object.nGeometerUseBonus
		elseif itemSymbolofRage and sInflictorName == itemSymbolofRage:GetName() then
			nAddBonus = nAddBonus + object.nSymbolofRageUseBonus
		end
	elseif EventData.Type == "Respawn" then
		if skills.abilBounce ~= nil then --To keep track status of 2nd skill
			skills.abilBounce.bTargetAll = true
			object.toggleBounce(self, false)
		end
	end
	
	if nAddBonus > 0 then
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent 	= object.oncombateventOverride

----------------------------
-- Retreat override --
----------------------------
-- set boots to str
function behaviorLib.RetreatFromThreatExecuteOverride(botBrain)
	SteamBootsLib.setAttributeBonus("str")

	return false
end
behaviorLib.CustomRetreatExecute = behaviorLib.RetreatFromThreatExecuteOverride

----------------------------------
-- customharassutility override --
----------------------------------

local function CustomHarassUtilityFnOverride(hero)
	local nReturnValue = 0
	
	local unitSelf = core.unitSelf
	if skills.abilMoonbeam:CanActivate() then
		nReturnValue = nReturnValue + object.nMoonbeamUpBonus
	end
	
	if skills.abilMoonFinale:CanActivate() then
		nReturnValue = nReturnValue + object.nUltUpBonus
	end

	local itemGeometer = core.GetItem("Item_ManaBurn2")
	if itemGeometer and itemGeometer:CanActivate() then
			nReturnValue = nReturnValue + object.nGeometerUpBonus
	end
	-- Less mana less aggerssion
	nReturnValue = nReturnValue + (unitSelf:GetManaPercent() - 1) * 20

	--Low level less aggression
	nLevel = unitSelf:GetLevel()
	if nLevel < 5 then
		nReturnValue = nReturnValue - (5 - nLevel) * 4
	end

	return nReturnValue

end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride   

---------------------
-- Harass Behavior --
---------------------
local function HarassHeroExecuteOverride(botBrain)

	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil then
		return false --Target is invalid, move on to the next behavior
	end

	SteamBootsLib.setAttributeBonus("agi")

	if not core.CanSeeUnit(botBrain, unitTarget) then
		return object.harassExecuteOld(botBrain)
	end

	--some vars
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()

	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)

	local nLastHarassUtility = behaviorLib.lastHarassUtil


	local bActionTaken = false

	local bTargetMagicImmune = unitTarget:isMagicImmune()

	----------------------------------------------------------------------------

	local abilMoonbeam = skills.abilMoonbeam
	if abilMoonbeam:CanActivate() and nLastHarassUtility > object.nMoonbeamThreshold and not bTargetMagicImmune then
		local nRange = abilMoonbeam:GetRange()
		if nTargetDistanceSq < (nRange * nRange) then
			bActionTaken = core.OrderAbilityEntity(botBrain, abilMoonbeam, unitTarget)
		end
	end

	if not bActionTaken and not bTargetMagicImmune then
		local abilMoonFinale = skills.abilMoonFinale
		--at higher levels this overpowers ult behavior with lastHarassUtil like 150
		if abilMoonFinale and abilMoonFinale:CanActivate() and nTargetDistanceSq < 600 * 600 and nLastHarassUtility - core.NumberElements(core.localUnits["EnemyCreeps"]) * 4 > object.tUltThresholds[abilMoonFinale:GetLevel()] then
			bActionTaken = behaviorLib.ultBehavior["Execute"](botBrain)
		end
	end

	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end

	return bActionTaken
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

----------------------
-- Custom behaviors --
----------------------

-------------------------------------------------------------------
--Use ult when there are good change and harashero is too afraid --
-------------------------------------------------------------------
function behaviorLib.ultimateUtility(botBrain)

	if not skills.abilMoonFinale:CanActivate() then
		return 0
	end

	local vecMyPosition = core.unitSelf:GetPosition()

	local tLocalUnits = core.localUnits

	--range of ult is 700, check 800 cause we are going to move during ult
	--check heroes in range 600, they try to run

	local nEnemyHeroes = 0
	local nEnemyCreeps = 0

	for _, unitHero in pairs(tLocalUnits["EnemyHeroes"]) do
		if Vector3.Distance2DSq(vecMyPosition, unitHero:GetPosition()) < 600*600 and not unitHero:isMagicImmune() then
			nEnemyHeroes = nEnemyHeroes + 1
		end
	end

	if nEnemyHeroes == 0 then
		return 0
	end

	for _, unitCreep in pairs(tLocalUnits["EnemyCreeps"]) do
		if Vector3.Distance2DSq(vecMyPosition, unitCreep:GetPosition()) < 800*800 then
			nEnemyCreeps = nEnemyCreeps + 1
		end
	end

	local nUtilityValue = 25
	local nUtilityPerLevel = 15

	nUtilityValue = nUtilityValue + skills.abilMoonFinale:GetLevel() * nUtilityPerLevel 

	local nDropPerHero = 5 + nEnemyHeroes
	nUtilityValue = nUtilityValue - (nEnemyHeroes - 1) * nDropPerHero

	local nDropPerCreep = 5
	if nEnemyCreeps >= nEnemyHeroes then
		nDropPerCreep = 8
	end

	nUtilityValue = nUtilityValue - nEnemyCreeps * nDropPerCreep
	return nUtilityValue * core.unitSelf:GetHealthPercent()
end

--press R to kill
function behaviorLib.ultimateExecute(botBrain)
	bActionTaken = core.OrderAbility(botBrain, skills.abilMoonFinale)

	local itemShrunkenHead = core.GetItem("Item_Immunity")
	if itemShrunkenHead and bActionTaken then
		botBrain:OrderItem(itemShrunkenHead.object)
	end
	return bActionTaken
end

behaviorLib.ultBehavior = {}
behaviorLib.ultBehavior["Utility"] = behaviorLib.ultimateUtility
behaviorLib.ultBehavior["Execute"] = behaviorLib.ultimateExecute
behaviorLib.ultBehavior["Name"] = "Moon Finale"
tinsert(behaviorLib.tBehaviors, behaviorLib.ultBehavior)

------------------------------------------------
-- Behavior to break channels and remove pots --
------------------------------------------------
behaviorLib.unitEnemyToStun = nil
function behaviorLib.stunUtility(botBrain)
	if not skills.abilMoonbeam:CanActivate() then
		return 0
	end

	local vecMyPosition = core.unitSelf:GetPosition()

	local nRadiusSQ = (skills.abilMoonbeam:GetRange() + 200) * (skills.abilMoonbeam:GetRange() + 200)

	for _, unitEnemyHero in pairs(core.localUnits["EnemyHeroes"]) do
		if unitEnemyHero:IsChanneling() and Vector3.Distance2DSq(vecMyPosition, unitEnemyHero:GetPosition()) < nRadiusSQ then
			behaviorLib.unitEnemyToStun = unitEnemyHero
			return 70
		end
	end
	return 0
end

function behaviorLib.stunExecute(botBrain)
	return core.OrderAbilityEntity(botBrain, skills.abilMoonbeam, behaviorLib.unitEnemyToStun)
end

behaviorLib.stunBehavior = {}
behaviorLib.stunBehavior["Utility"] = behaviorLib.stunUtility
behaviorLib.stunBehavior["Execute"] = behaviorLib.stunExecute
behaviorLib.stunBehavior["Name"] = "stun"
tinsert(behaviorLib.tBehaviors, behaviorLib.stunBehavior)


behaviorLib.unitEnemyToAttack = nil
function behaviorLib.breakPotsUtility(botBrain)

	local vecMyPosition = core.unitSelf:GetPosition()

	local nRadiusSQ = (skills.abilMoonbeam:GetRange() + 200) * (skills.abilMoonbeam:GetRange() + 200)

	for _, unitEnemyHero in pairs(core.localUnits["EnemyHeroes"]) do
		if (unitEnemyHero:HasState("State_ManaPotion") or unitEnemyHero:HasState("State_HealthPotion")
			or unitEnemyHero:HasState("State_Bottle") or unitEnemyHero:HasState("State_PowerupRegen"))
			and Vector3.Distance2DSq(vecMyPosition, unitEnemyHero:GetPosition()) < nRadiusSQ then
				behaviorLib.unitEnemyToAttack = unitEnemyHero
				return 35
		end
	end
	return 0
end

function behaviorLib.breakPotsExecute(botBrain)
	local bActionTaken = false

	local unitSelf = core.unitSelf
	local unitTarget = behaviorLib.unitEnemyToAttack

	if core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget, true) > Vector3.Distance2DSq(unitSelf:GetPosition(), unitTarget:GetPosition()) then
		bActionTaken = core.OrderAttackClamp(botBrain, unitSelf, unitTarget)
	end

	local abilMoonbeam = skills.abilMoonbeam
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)
	if not bActionTaken and bCanSee and abilMoonbeam and abilMoonbeam:CanActivate() then
		local nUnitManaPercent = unitSelf:GetManaPercent()
		if nUnitManaPercent >= object.nBreakPotionManaPercentTreshold then
			bActionTaken = core.OrderAbilityEntity(botBrain, abilMoonbeam, unitTarget)
		end
	end

	return bActionTaken
end

behaviorLib.breakPotsBehavior = {}
behaviorLib.breakPotsBehavior["Utility"] = behaviorLib.breakPotsUtility
behaviorLib.breakPotsBehavior["Execute"] = behaviorLib.breakPotsExecute
behaviorLib.breakPotsBehavior["Name"] = "Behavior to remove enemy potions"
tinsert(behaviorLib.tBehaviors, behaviorLib.breakPotsBehavior)

-----------------------------------------------
--                  Misc                     --
-----------------------------------------------

---------------------------------
--Helppers for bounce and aura --
---------------------------------
function object.toggleAura(botBrain, bState)
	local abilAura = skills.abilAura
	if not abilAura or not abilAura:CanActivate() or object.getAuraState() == bState then
		return false
	end
	local bSuccess = core.OrderAbility(botBrain, abilAura)
	if bSuccess then
		skills.abilAura.bTargetAll = bState
	end
	return bSuccess
end

function object.toggleBounce(botBrain, bState)
	local abilBounce = skills.abilBounce
	if not abilBounce or not abilBounce:CanActivate() or object.getBounceState() == bState then
		return false
	end

	local bSuccess = core.OrderAbility(botBrain, abilBounce)
	if bSuccess then
		skills.abilBounce.bTargetAll = bState
	end
	return bSuccess
end

--true when target is "all" false when heroes only
function object.getAuraState()
	if skills.abilAura:GetLevel() == 0 then
		return false
	end
	return skills.abilAura.bTargetAll
end

function object.getBounceState()
	if skills.abilBounce:GetLevel() == 0 then
		return false
	end
	return skills.abilBounce.bTargetAll 
end

-----------------------------
-- Wrappers for steamboots --
-----------------------------

SteamBootsLib.sDesiredAttribute = "agi"

function SteamBootsLib.getAttributeBonus()
	local itemSteamBoots = core.GetItem("Item_Steamboots")
	if not itemSteamBoots then
		return ""
	end
	local sAttribute = itemSteamBoots:GetActiveModifierKey()
	if sAttribute == nil then
		--a bug?
		return ""
	end
	return sAttribute
end

function SteamBootsLib.setAttributeBonus(attribute)
	if attribute == "str" or attribute == "agi" or attribute == "int" then
		SteamBootsLib.sDesiredAttribute = attribute
	end
end

--------------
-- Messages --
--------------
object.tCustomKillChatKeys={
	"anakonda_moonqueen_kill1",
	"anakonda_moonqueen_kill2",
	"anakonda_moonqueen_kill3",
	"anakonda_moonqueen_kill4",
	"anakonda_moonqueen_kill5"
}

local function GetKillKeysOverride(unitTarget)
	local tChatKeys = object.funcGetKillKeysOld(unitTarget)
	core.InsertToTable(tChatKeys, object.tCustomKillChatKeys)
	return tChatKeys
end
object.funcGetKillKeysOld = core.GetKillKeys
core.GetKillKeys = GetKillKeysOverride


object.tCustomDeathChatKeys = {
	"anakonda_moonqueen_death1",
}

local function GetDeathKeysOverride(unitSource)
	local tChatKeys = object.funcGetDeathKeysOld(unitSource)
	core.InsertToTable(tChatKeys, object.tCustomDeathChatKeys)
	BotEcho(#tChatKeys)
	return tChatKeys
end
object.funcGetDeathKeysOld = core.GetDeathKeys
core.GetDeathKeys = GetDeathKeysOverride


object.tCustomRespawnChatKeys = {
	"anakonda_moonqueen_respawn1",
	"anakonda_moonqueen_respawn2"
}

local function GetRespawnKeysOverride()
	local tChatKeys = object.funcGetRespawnKeysOld()
	core.InsertToTable(tChatKeys, object.tCustomRespawnChatKeys)
	return tChatKeys
end
object.funcGetRespawnKeysOld = core.GetRespawnKeys
core.GetRespawnKeys = GetRespawnKeysOverride

BotEcho('finished loading Moon Queen')