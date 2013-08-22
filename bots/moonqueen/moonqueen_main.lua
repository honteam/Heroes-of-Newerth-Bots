
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

object.IllusionLib = object.IllusionLib or {}
local IllusionLib = object.IllusionLib

BotEcho(' loading Moon Queen')

-----------------------
-- bot "global" vars --
-----------------------

--bounce "resets" when you die to keep track when you respawn
object.bHeroAlive = true

--To keep track day/night cycle
object.isDay = true

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

--   item buy order.
behaviorLib.StartingItems  = {"2 Item_DuckBoots", "2 Item_MinorTotem", "Item_HealthPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems  = {"Item_Marchers", "Item_HelmOfTheVictim", "Item_Steamboots"}
behaviorLib.MidItems  = {"Item_Sicarius", "Item_WhisperingHelm", "Item_Immunity"}
behaviorLib.LateItems  = {"Item_ManaBurn2", "Item_LifeSteal4", "Item_Evasion"}

------------------------------
--     skills               --
------------------------------
function object:SkillBuild()
	core.VerboseLog("skillbuild()")

	local unitSelf = self.core.unitSelf
	if skills.abilMoonbeam == nil then
		skills.abilMoonbeam = unitSelf:GetAbility(0)
		skills.abilBounce = core.WrapInTable(unitSelf:GetAbility(1))
		skills.abilAura = core.WrapInTable(unitSelf:GetAbility(2))
		skills.abilMoonFinale = unitSelf:GetAbility(3)
		skills.abilAttributeBoost = unitSelf:GetAbility(4)

		--To keep track status of 2nd and 3rd skill
		skills.abilBounce.bTargetAll = true
		skills.abilAura.bTargetAll = true
	end
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end

	local nlev = unitSelf:GetLevel()
	local nlevPts = unitSelf:GetAbilityPointsAvailable()
	for i = nlev, nlev+nlevPts do
		unitSelf:GetAbility( object.tSkills[i] ):LevelUp()

		--initialy set aura and bounce to heroes only
		if i == 1 then
			object.toggleAura(self, false)
		end
		if i == 4 then
			object.toggleBounce(self, false)
		end
	end
end

----------------------------------------------
-- Find geo, shrunken, rage, helm and boots --
----------------------------------------------

local function funcFindItemsOverride(botBrain)
	object.FindItemsOld(botBrain)
	core.ValidateItem(core.itemGeometer)
	core.ValidateItem(core.itemShrunkenHead)
	core.ValidateItem(core.itemSymbolofRage)
	core.ValidateItem(core.itemSteamBoots)

	if core.itemGeometer and core.itemShrunkenHead and core.itemSymbolofRage and core.itemSteamBoots then
		return
	end

	local inventory = core.unitSelf:GetInventory(true)
	for slot = 1, 6, 1 do
		local curItem = inventory[slot]
		if curItem ~= nil then
			if core.itemGeometer == nil and not curItem:IsRecipe() and curItem:GetName() == "Item_ManaBurn2" then
				core.itemGeometer = core.WrapInTable(curItem)
			elseif core.itemShrunkenHead == nil and not curItem:IsRecipe() and curItem:GetName() == "Item_Immunity" then
				core.itemShrunkenHead = core.WrapInTable(curItem)
			elseif core.itemSymbolofRage == nil and curItem:GetName() == "Item_LifeSteal4" then
				core.itemSymbolofRage = core.WrapInTable(curItem)
			elseif core.itemSteamBoots == nil and curItem:GetName() == "Item_Steamboots" then
				core.itemSteamBoots = core.WrapInTable(curItem)
			end
		end
	end
end

object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride

---------------------------
--    onthink override   --
-- Called every bot tick --
---------------------------
object.nSteambootsToggleDelay = 0
function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)
	local unitSelf = core.unitSelf
	local vecHeroPos = unitSelf:GetPosition()
	if unitSelf:IsAlive() and core.localUnits~=nil then
		if not object.bHeroAlive then
			--To keep track status of 2nd skill
			object.bHeroAlive = true
			skills.abilBounce.bTargetAll = true
			object.toggleBounce(self, false)
		end

		-- Keep illus near
		for _, illu in pairs(IllusionLib.myIllusions()) do
			if Vector3.Distance2DSq(illu:GetPosition(), vecHeroPos) > 160000 then
				core.OrderMoveToPos(self, illu, vecHeroPos, false)
			end
		end

	end

	if not unitSelf:IsAlive() then
		--To keep track status of 2nd skill
		object.bHeroAlive = false
	end

	--keep track of day/night only to say something stupid in all chat
	local time = HoN.GetMatchTime() --This is time since the 0:00 mark

	if time ~= 0 then
		local day = math.floor(time/(7.5*60*1000)) % 2
		--BotEcho(day)

		if day == 0 and not object.isDay then
			--Good morning
			object.isDay = true
		elseif day == 1 and object.isDay then
			--gnight
			object.isDay = false
			if math.random(5) == 1 then --math.random(upper) generates integer numbers between 1 and upper.
				sMessage = object.tNightMessages[math.random(#object.tNightMessages)]
				nDelay = 200

				core.AllChatLocalizedMessage(sMessage, nil, nDelay)
			end
		end
	end

	if core.itemSteamBoots then
		if object.nSteambootsToggleDelay ~= 0 then
			object.nSteambootsToggleDelay = object.nSteambootsToggleDelay - 1 --not to spam faster than it can handle
		else
			currentAttribute = self.SteamBootsLib.getAttributeBonus()
			if currentAttribute ~= "" and currentAttribute ~= SteamBootsLib.sDesiredAttribute then
				self:OrderItem(core.itemSteamBoots.object, "None")
				object.nSteambootsToggleDelay = 5
			end
		end
	end
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride

---------------------------
-- Togle aura and bounce --
---------------------------
local function PushExecuteOverride(botBrain)
	object.toggleBounce(botBrain, true)
	object.toggleAura(botBrain, true)
	SteamBootsLib.setAttributeBonus("agi")
	object.PushExecuteOld(botBrain)
end
object.PushExecuteOld = behaviorLib.PushBehavior["Execute"]
behaviorLib.PushBehavior["Execute"] = PushExecuteOverride

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
--Bonuses
object.geometerUseBonus = 15
object.ultUseBonus = 65
object.beamUseBonus = 5
object.SymbolofRageUseBonus = 50
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)

	local addBonus = 0
	if EventData.Type == "Ability" then	
		if EventData.InflictorName == "Ability_Krixi1" then
			addBonus = addBonus + object.beamUseBonus
		elseif EventData.InflictorName == "Ability_Krixi4" then
			addBonus = addBonus + object.ultUseBonus
		end
	elseif EventData.Type == "Item" then
		if core.itemGeometer ~= nil and EventData.InflictorName == core.itemGeometer:GetName() then
			addBonus = addBonus + object.geometerUseBonus
		elseif core.itemSymbolofRage and EventData.InflictorName == core.itemSymbolofRage:GetName() then
			addBonus = addBonus + object.SymbolofRageUseBonus
		end
	end
	
	if addBonus > 0 then
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + addBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent 	= object.oncombateventOverride

----------------------------
-- Retreat override --
----------------------------
-- Use geo and set boots to str
function behaviorLib.RetreatFromThreatExecuteOverride(botBrain)
	SteamBootsLib.setAttributeBonus("str")
	bActionTaken = false
	if core.NumberElements(core.localUnits["EnemyHeroes"]) > 0 then
		if core.itemGeometer and core.itemGeometer:CanActivate() then
			bActionTaken = core.OrderItemClamp(botBrain, unitSelf, core.itemGeometer, false, false)
		end
	end

	if not bActionTaken then
		behaviorLib.RetreatFromThreatExecuteOld(botBrain)
	end
end
behaviorLib.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatBehavior["Execute"]
behaviorLib.RetreatFromThreatBehavior["Execute"] = behaviorLib.RetreatFromThreatExecuteOverride

----------------------------------
-- customharassutility override --
----------------------------------
-- Extra value from spells and geo

object.moonbeamUpBonus = 5
object.ultUpBonus = 20
object.geometerUpBonus = 5
local function CustomHarassUtilityFnOverride(hero)
	local val = 0
	
	if skills.abilMoonbeam:CanActivate() then
		val = val + object.moonbeamUpBonus
	end
	
	if skills.abilMoonFinale:CanActivate() then
		val = val + object.ultUpBonus
	end

	if core.itemGeometer ~= nil then
		if core.itemGeometer:CanActivate() then
			val = val + object.geometerUpBonus
		end
	end
	-- Less mana less aggerssion
	val = val + (core.unitSelf:GetManaPercent() - 0.65) * 30
	return val

end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride   

---------------------
-- Harass Behavior --
---------------------
object.geometerUseThreshold = 55
object.moonbeamThreshold = 35
object.ultThresholds = {95, 85, 75}
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
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)

	local bActionTaken = false

	local bTargetMagicImmune = object.IsMagicImmune(unitTarget)

	----------------------------------------------------------------------------

	if not bActionTaken then
		if skills.abilMoonbeam:CanActivate() and nLastHarassUtility > object.moonbeamThreshold and not bTargetMagicImmune then
			bActionTaken = core.OrderAbilityEntity(botBrain, skills.abilMoonbeam, unitTarget)
		end
	end

	if not bActionTaken then
		if nLastHarassUtility > object.geometerUseThreshold and core.itemGeometer and core.itemGeometer:CanActivate() then
			bActionTaken = core.OrderItemClamp(botBrain, unitSelf, core.itemGeometer, false, false)
		end
	end

	if not bActionTaken and bCanSee and not bTargetMagicImmune then
		--at higher levels this overpowers ult behavior with lastHarassUtil like 150
		if skills.abilMoonFinale:CanActivate() and nLastHarassUtility > object.ultThresholds[skills.abilMoonFinale:GetLevel()] and nTargetDistanceSq < 600 * 600 then
			bActionTaken = behaviorLib.ultBehavior["Execute"](botBrain)
		end
	end

	for _, illu in pairs(IllusionLib.myIllusions()) do
		core.OrderAttack(botBrain, illu, unitTarget)
	end

	if not bActionTaken then
		if core.itemSymbolofRage and core.itemSymbolofRage:CanActivate() and unitSelf:GetHealthPercent() < 0.7 then
			botBrain:OrderItem(core.itemSymbolofRage.object)
		end
		return object.harassExecuteOld(botBrain)
	end 
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

----------------------
-- Custom behaviors --
----------------------

-------------------------------------------------------------------
--Use ult when there are good change and harashero is too afraid --
-------------------------------------------------------------------
function behaviorLib.UltimateUtility(botBrain)

	if not skills.abilMoonFinale:CanActivate() then
		return 0
	end

	local vecMyPosition = core.unitSelf:GetPosition()

	--range of ult is 700, check 800 cause we are going to move during ult
	--check heroes in range 600, they try to run
	local unitlist = HoN.GetUnitsInRadius(vecMyPosition, 800, core.UNIT_MASK_UNIT + core.UNIT_MASK_HERO + core.UNIT_MASK_ALIVE)
	local localUnits = {}
	core.SortUnitsAndBuildings(unitlist, localUnits, true)

	local enemyheroes = {}

	for _, hero in pairs(localUnits["enemyHeroes"]) do
		if Vector3.Distance2DSq(vecMyPosition, hero:GetPosition()) < 600*600 and not object.IsMagicImmune(hero) then
			tinsert(enemyheroes, hero)
		end
	end

	if core.NumberElements(enemyheroes) == 0 then
		return 0
	end

	local utilityvalue = 0
	if core.NumberElements(localUnits["tEnemyUnits"]) <= skills.abilMoonFinale:GetLevel() + 1 then
		utilityvalue = utilityvalue + 30
	end
	if core.NumberElements(localUnits["tEnemyUnits"]) == core.NumberElements(enemyheroes) then
		utilityvalue = utilityvalue + 40
	elseif core.NumberElements(localUnits["tEnemyUnits"]) < core.NumberElements(enemyheroes) *2 then
		utilityvalue = utilityvalue + 20
	end
	return utilityvalue * core.unitSelf:GetHealthPercent()
end

--press R to kill
function behaviorLib.UltimateExecute(botBrain)
	bActionTaken = core.OrderAbility(botBrain, skills.abilMoonFinale)

	if core.itemShrunkenHead and bActionTaken then
		botBrain:OrderItem(core.itemShrunkenHead.object)
	end
	return bActionTaken
end

behaviorLib.ultBehavior = {}
behaviorLib.ultBehavior["Utility"] = behaviorLib.UltimateUtility
behaviorLib.ultBehavior["Execute"] = behaviorLib.UltimateExecute
behaviorLib.ultBehavior["Name"] = "Moon Finale"
tinsert(behaviorLib.tBehaviors, behaviorLib.ultBehavior)

------------------------------------------------
-- Behavior to break channels and remove pots --
------------------------------------------------
behaviorLib.enemyToStun = nil
function behaviorLib.stunUtility(botBrain)
	if not skills.abilMoonbeam:CanActivate() then
		return 0
	end

	local vecMyPosition = core.unitSelf:GetPosition()

	local nRadiusSQ = (skills.abilMoonbeam::GetRange() + 200) * (skills.abilMoonbeam::GetRange() + 200)

	for _,enemy in pairs(core.localUnits["EnemyHeroes"]) do
		if enemy:IsChanneling() or enemy:HasState("State_ManaPotion") or enemy:HasState("State_HealthPotion")
			or enemy:HasState("State_Bottle") or enemy:HasState("State_PowerupRegen") then
			if Vector3.Distance2DSq(vecMyPosition, enemy:GetPosition()) < nRadiusSQ then
				behaviorLib.enemyToStun = enemy
				return 70
			end
		end
	end
	return 0
end

function behaviorLib.stunExecute(botBrain)
	return core.OrderAbilityEntity(botBrain, skills.abilMoonbeam, behaviorLib.enemyToStun)
end

behaviorLib.stunBehavior = {}
behaviorLib.stunBehavior["Utility"] = behaviorLib.stunUtility
behaviorLib.stunBehavior["Execute"] = behaviorLib.stunExecute
behaviorLib.stunBehavior["Name"] = "stun"
tinsert(behaviorLib.tBehaviors, behaviorLib.stunBehavior)

-----------------------------------------------
--                  Misc                     --
-----------------------------------------------

---------------------------------
--Helppers for bounce and aura --
---------------------------------
function object.toggleAura(botBrain, state)
	if object.getAuraState() == state or not skills.abilAura:CanActivate() then
		return false
	end
	local success = core.OrderAbility(botBrain, skills.abilAura)
	if success then
		skills.abilAura.bTargetAll = not skills.abilAura.bTargetAll
	end
	return true
end

function object.toggleBounce(botBrain, state)
	if object.getBounceState() == state or not skills.abilBounce:CanActivate() then
		return false
	end

	local success = core.OrderAbility(botBrain, skills.abilBounce)
	if success then
		skills.abilBounce.bTargetAll = not skills.abilBounce.bTargetAll
	end
	return true
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

--------------------
-- Magic immunity --
--------------------
function object.IsMagicImmune(unit)
	local states = { "State_Item3E", "State_Predator_Ability2", "State_Jereziah_Ability2", "State_Rampage_Ability1_Self", "State_Rhapsody_Ability4_Buff", "State_Hiro_Ability1" }
	for _, state in ipairs(states) do
		if unit:HasState(state) then
			return true
		end
	end
	return false
end

----------------------------
-- Wrappers for illusions --
----------------------------

function IllusionLib.myIllusions()
	if core.tControllableUnits ~= nil then
		local illus = {}

		for _, unit in pairs(core.tControllableUnits["InventoryUnits"]) do
			if unit:IsHero() and IllusionLib.IsIllusion(unit) then
				tinsert(illus, unit)
			end
		end
		return illus
	else
		return {}
	end
end

function IllusionLib.IsIllusion(unit)
	if unit:GetTeam() ~= object.core.myTeam then --Dont "cheat"
		return false
	end
	return core.tableContains(core.teamBotBrain.tAllyHeroes, unit) == 0
end

-----------------------------
-- Wrappers for steamboots --
-----------------------------

SteamBootsLib.sDesiredAttribute = "agi"

function SteamBootsLib.getAttributeBonus()
	if not core.itemSteamBoots then
		return ""
	end
	local sAttribute = core.itemSteamBoots:GetActiveModifierKey()
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


object.tNightMessages = {
	"anakonda_moonqueen_night1",
	"anakonda_moonqueen_night2",
	"anakonda_moonqueen_night3"
}

BotEcho('finished loading Moon Queen')