
local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic		 = true
object.bRunBehaviors	= true
object.bUpdates		 = true
object.bUseShop		 = true

object.bRunCommands	 = true 
object.bMoveCommands	 = true
object.bAttackCommands	 = true
object.bAbilityCommands = true
object.bOtherCommands	 = true

object.bReportBehavior = false
object.bDebugUtility = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core		 = {}
object.eventsLib	 = {}
object.metadata	 = {}
object.behaviorLib	 = {}
object.skills		 = {}

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

local tBottle = {}
local illusionLib = object.illusionLib

BotEcho(object:GetName()..' loading succubus_main...')

----------------------------------------------------------
--  			  bot constant definitions				--
----------------------------------------------------------

object.heroName = 'Hero_Succubis'

--   item buy order. internal names  
behaviorLib.StartingItems  = {"3 Item_MarkOfTheNovice", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems  = {"Item_Bottle", "Item_EnhancedMarchers"}
behaviorLib.MidItems  = {"Item_PortalKey", "Item_Immunity", "Item_Summon 3"}
behaviorLib.LateItems  = {"Item_Intelligence7", "Item_GrimoireOfPower"}
--item_summon is puzzlebox; Item_Intelligence7 is master staff

core.tLanePreferences = {Jungle = 0, Mid = 5, ShortSolo = 4, LongSolo = 4, ShortSupport = 3, LongSupport = 3, ShortCarry = 0, LongCarry = 0}

-- Constants for skill usage

object.nMesmeUseBonus = 5
object.nHoldUseBonus = 35
object.nHeartacheUseBonus = 15

object.nMesmeUpBonus = 5
object.nHoldUpBonus = 20
object.nHeartacheUpBonus = 10

object.nHoldThreshold = 60
object.nHeartacheThreshold = 40
object.nMesmeThreshold = 50
object.nPKThreshold = 45

------------------------------
--	 skills			   --
------------------------------
-- skillbuild table, 0=smitten, 1=heartache, 2=mesme, 3=ult, 4=attri
object.tSkills = {
	1, 2, 1, 2, 1,
	3, 1, 2, 2, 0, 
	3, 0, 0, 0, 4,
	3, 4, 4, 4, 4,
	4, 4, 4, 4, 4,
}
function object:SkillBuild()
	core.VerboseLog("skillbuild()")

	local unitSelf = self.core.unitSelf
	if  skills.smitten == nil then
		skills.smitten = unitSelf:GetAbility(0)
		skills.heartache = unitSelf:GetAbility(1)
		skills.mesme = unitSelf:GetAbility(2)
		skills.hold = unitSelf:GetAbility(3)
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

---------------------------------------------
--	This adds puzzle box to the illusions  --
---------------------------------------------

function illusionLib.updateIllusions(botBrain)
	illusionLib.tIllusions = {}
	local tPossibleIllusions = core.tControllableUnits["AllUnits"]
	if tPossibleIllusions ~= nil then
		for nUID, unit in pairs(tPossibleIllusions) do
			local sTypeName = unit:GetTypeName()
			if sTypeName ~= "Pet_GroundFamiliar" and sTypeName ~= "Pet_FlyngCourier" then
				tinsert(illusionLib.tIllusions, unit)
			end
		end
	end
end

object.retreatCastThreshold = 55
function behaviorLib.CustomRetreatExecute(botBrain)
	local unitSelf = core.unitSelf
	local mypos = unitSelf:GetPosition()

	local nLastRetreatUtil = behaviorLib.lastRetreatUtil

	local nMissingHP = unitSelf:GetMaxHealth() - unitSelf:GetHealth()

	local bActionTaken = false

	local itemPortalKey = core.GetItem("Item_PortalKey")
	if nLastRetreatUtil > object.retreatCastThreshold and itemPortalKey ~= nil then
		if itemPortalKey:CanActivate() then
			bActionTaken = core.OrderBlinkItemToEscape(botBrain, unitSelf, itemPortalKey)
		end
	end

	local nMesmeRange = skills.mesme:GetRange()
	local nHeartacheRange = skills.heartache:GetRange()
	local bMesmeCanActivate = skills.mesme:CanActivate()
	local bHeartacheCanActivate = skills.heartache:CanActivate()

	if not bActionTaken then
		if nLastRetreatUtil > object.retreatCastThreshold then
			for _, hero in pairs(core.localUnits["EnemyHeroes"]) do
				if not hero:isMagicImmune() then
					local nDistanceSQ = Vector3.Distance2DSq(mypos, hero:GetPosition())
					if bHeartacheCanActivate and nDistanceSQ < nHeartacheRange * nHeartacheRange and nMissingHP > 300 and not hero:HasState("State_Succubis_Ability3") then
						bActionTaken = core.OrderAbilityEntity(botBrain, skills.heartache, hero)
						break
					end
					if bMesmeCanActivate and nDistanceSQ < nMesmeRange * nMesmeRange then
						bActionTaken = core.OrderAbilityEntity(botBrain, skills.mesme, hero)
						break
					end
				end
			end
		end
	end

	return bActionTaken
end

function behaviorLib.CustomReturnToWellExecute(botBrain)
	return core.OrderBlinkItemToEscape(botBrain, core.unitSelf, core.GetItem("Item_PortalKey"), true)
end

------------------------------------------
--			oncombatevent override		--
------------------------------------------
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)

	local nAddBonus = 0

	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_Succubis1" then

		elseif EventData.InflictorName == "Ability_Succubis2" then
			nAddBonus = nAddBonus + object.nHeartacheUseBonus
		elseif EventData.InflictorName == "Ability_Succubis3" then
			nAddBonus = nAddBonus + object.nMesmeUseBonus
		elseif EventData.InflictorName == "Ability_Succubis4" then
			nAddBonus = nAddBonus + object.nHoldUseBonus
			object.ultTime = HoN.GetGameTime()
		end
	end

	if nAddBonus > 0 then
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent	= object.oncombateventOverride

local function CustomHarassUtilityFnOverride(hero)
	if hero:HasState("State_Succubis_Ability3") then
		return -100
	end

	local nVal = 0
	
	if skills.mesme:CanActivate() then
		nVal = nVal + object.nMesmeUpBonus
	end
	
	if skills.hold:CanActivate() then
		nVal = nVal + object.nHoldUpBonus
	end

	if skills.heartache:CanActivate() then
		nVal = nVal + object.nHeartacheUpBonus
	end

	local unitSelf = core.unitSelf

	if unitSelf:HasState("State_PowerupStealth") or unitSelf:HasState("State_PowerupMoveSpeed") then
		nVal = nVal + 20
	end

	-- Less mana less aggression
	nVal = nVal + (unitSelf:GetManaPercent() - 0.80) * 45
	return nVal

end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride  

---------------------------------------------------------
--					Harass Behavior					   --
---------------------------------------------------------

local function HarassHeroExecuteOverride(botBrain)
	local unitSelf = core.unitSelf

	--Cant trust to dontbreakchanneling
	if unitSelf:IsChanneling() then
		return true
	end

	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil then
		return object.harassExecuteOld(botBrain) --Target is invalid, move on to the next behavior
	end
	
	--mesme goes where it wants
	if unitTarget:HasState("State_Succubis_Ability3") then
		return false
	end

	local vecMyPosition = unitSelf:GetPosition() 
	local nAttackRange = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
	local nMyExtraRange = core.GetExtraRange(unitSelf)
	
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetnDistanceSQ = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local targetMagicImmune = unitTarget:isMagicImmune()
	
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)	
	local bActionTaken = false

	local itemPortalKey = core.GetItem("Item_PortalKey")
	local itemPuzzleBox = core.GetItem("Item_Summon")
	local itemShrunkenHead = core.GetItem("Item_Immunity")

	--damage stealth illusion movespeed regen
	local runeInBottle = tBottle.getRune()
	if runeInBottle == "damage" or runeInBottle == "illusion" or runeInBottle == "movespeed" then
		botBrain:OrderItem(core.GetItem("Item_Bottle"))
	end

	--pk suprise
	if bCanSee and itemPortalKey and itemPortalKey:CanActivate() and object.nPKThreshold < nLastHarassUtility then
		if nTargetnDistanceSQ > 800 * 800 then
			if nLastHarassUtility > behaviorLib.diveThreshold or core.NumberElements(core.GetTowersThreateningPosition(vecTargetPosition, nMyExtraRange, core.myTeam)) == 0 then
				local _, sortedTable = HoN.GetUnitsInRadius(vecTargetPosition, 1000, core.UNIT_MASK_HERO + core.UNIT_MASK_ALIVE, true)
				local EnemyHeroes = sortedTable.EnemyHeroes
				if core.NumberElements(EnemyHeroes) == 1 then
					bActionTaken = core.OrderItemPosition(botBrain, unitSelf, itemPortalKey, vecTargetPosition)
				end
			end
		end
	end

	local nMesmeRange = skills.mesme:GetRange()
	local smittenRange = skills.smitten:GetRange()
	local bMesmeCanActivate = skills.mesme:CanActivate()
	local smittenCanActivate = skills.smitten:CanActivate()

	--teamfight
	if not bActionTaken then
		if nLastHarassUtility > object.nMesmeThreshold then
			for _,hero in pairs(core.localUnits["EnemyHeroes"]) do
				if hero ~= unitTarget then
					if not hero:HasState("State_Succubis_Ability3") and not hero:HasState("State_Succubis_Ability1") and not hero:isMagicImmune() then
						local nDistanceSQ = Vector3.Distance2DSq(vecMyPosition, hero:GetPosition())
						if bMesmeCanActivate and nDistanceSQ < nMesmeRange*nMesmeRange then
							bActionTaken = core.OrderAbilityEntity(botBrain, skills.mesme, hero)
							break
						elseif smittenCanActivate and nDistanceSQ < smittenRange*smittenRange then
							bActionTaken = core.OrderAbilityEntity(botBrain, skills.smitten, hero)
							break
						end
					end
				end
			end
		end
	end

	if not bActionTaken and bCanSee then
		if not targetMagicImmune then
			if nLastHarassUtility > object.nHoldThreshold and skills.hold:CanActivate() then
				if itemPuzzleBox and itemPuzzleBox:CanActivate() then
					bActionTaken = true
					botBrain:OrderItem(itemPuzzleBox.object)
				elseif itemShrunkenHead and itemShrunkenHead:CanActivate() then
					bActionTaken = true
					botBrain:OrderItem(itemShrunkenHead.object)
				else
					bActionTaken = core.OrderAbilityEntity(botBrain, skills.hold, unitTarget)
				end
			end
			if not bActionTaken and nLastHarassUtility > object.nHeartacheThreshold and skills.heartache:CanActivate() then
				bActionTaken = core.OrderAbilityEntity(botBrain, skills.heartache, unitTarget)
			end
		end
	end

	if not bActionTaken and not unitSelf:HasState("State_PowerupStealth") then
		return object.harassExecuteOld(botBrain)
	end 
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

function minionsDuringUlt(botBrain)
	local unitTarget = nil
	for _,hero in pairs(core.localUnits.EnemyHeroes) do
		if hero:HasState("State_Succubis_Ability4") then
			unitTarget = hero
		end
	end
	if unitTarget then
		return illusionLib.OrderIllusionsAttack(botBrain, unitTarget)
	end
end
illusionLib.tIllusionBehaviors["DontBreakChannel"] = minionsDuringUlt

----------------------
-- Healing behavior --
----------------------

function behaviorLib.healHeartacheUtility(botBrain)
	local unitSelf = core.unitSelf

	if unitSelf:HasState("State_PowerupRegen") then
		return 0
	end

	local nMissingHP = unitSelf:GetMaxHealth() - unitSelf:GetHealth()

	local nHeartacheUtil = 0

	if skills.heartache:CanActivate() and core.NumberElements(core.localUnits["Enemies"]) > 0 then
		nHeartacheUtil = core.ATanFn(nMissingHP, Vector3.Create(300, 25), Vector3.Create(0,0), 100)
	end

	return nHeartacheUtil
end

function behaviorLib.healHeartacheExecute(botBrain)
	local unitSelf = core.unitSelf
	local vecMypos = unitSelf:GetPosition()

	local bActionTaken = false

	local bHeartacheCanActivate = skills.heartache:CanActivate()
	if not bActionTaken and bHeartacheCanActivate then
		local nHeartacheRange = skills.heartache:GetRange()
		if core.NumberElements(core.localUnits["EnemyHeroes"]) > 0 then
			local unitClosestHero = nil
			local nClosestDistance = 650 * 650 -- Only units closer than 650 are valid
			for _, hero in pairs(core.localUnits["EnemyHeroes"]) do
				local distance = Vector3.Distance2DSq(hero:GetPosition(), vecMypos)
				if distance < nClosestDistance then
					nClosestDistance = distance
					unitClosestHero = hero
					if distance < nHeartacheRange*nHeartacheRange then
						break
					end
				end
			end
			if unitClosestHero then
				bActionTaken = core.OrderAbilityEntity(botBrain, skills.heartache, unitClosestHero)
			end
		else
			if core.NumberElements(core.localUnits["EnemyCreeps"]) then
				--just find creep in range or closest
				local unitClosestCreep = nil
				local nClosestDistance = 650 * 650 -- Only units closer than 650 are valid
				for _, creep in pairs(core.localUnits["EnemyCreeps"]) do
					local distance = Vector3.Distance2DSq(creep:GetPosition(), vecMypos)
					if distance < nClosestDistance then
						nClosestDistance = distance
						unitClosestCreep = creep
						if distance < nHeartacheRange*nHeartacheRange then
							break
						end
					end
				end
				if unitClosestCreep then
					bActionTaken = core.OrderAbilityEntity(botBrain, skills.heartache, unitClosestCreep)
				end
			end
		end
	end
	return bActionTaken
end

behaviorLib.healHeartache = {}
behaviorLib.healHeartache["Utility"] = behaviorLib.healHeartacheUtility
behaviorLib.healHeartache["Execute"] = behaviorLib.healHeartacheExecute
behaviorLib.healHeartache["Name"] = "healHeartache"
tinsert(behaviorLib.tBehaviors, behaviorLib.healHeartache)


-- Change default behaviors if we have rune
function behaviorLib.newUseBottleBehaviorUtility(botBrain)
	if core.unitSelf:HasState("State_PowerupRegen") or core.unitSelf:HasState("State_PowerupStealth") then
		return 0
	end

	nUtility = behaviorLib.oldUseBottleBehaviorUtility(botBrain)
	if tBottle.getRune() == "regen" then
		nUtility = nUtility * 0.8
	end
	return nUtility
end

behaviorLib.oldUseBottleBehaviorUtility = behaviorLib.tItemBehaviors["Item_Bottle"]["Utility"]
behaviorLib.tItemBehaviors["Item_Bottle"]["Utility"] = behaviorLib.newUseBottleBehaviorUtility

function behaviorLib.newAttackCreepsUtility(botBrain)
	if  core.unitSelf:HasState("State_PowerupStealth") then
		return 0
	end

	return behaviorLib.oldAttackCreepsUtility(botBrain)
end
behaviorLib.oldAttackCreepsUtility = behaviorLib.AttackCreepsBehavior["Utility"]
behaviorLib.AttackCreepsBehavior["Utility"] = behaviorLib.newAttackCreepsUtility

function behaviorLib.newattackEnemyMinionsUtility(botBrain)
	if  core.unitSelf:HasState("State_PowerupStealth") then
		return 0
	end

	return behaviorLib.oldattackEnemyMinionsUtility(botBrain)
end
behaviorLib.oldattackEnemyMinionsUtility = behaviorLib.attackEnemyMinionsBehavior["Utility"]
behaviorLib.attackEnemyMinionsBehavior["Utility"] = behaviorLib.newattackEnemyMinionsUtility

---------------------------
-- Override rune picking --
---------------------------
function behaviorLib.newPickRuneUtility(botBrain)
	local rune = core.teamBotBrain.GetNearestRune(core.unitSelf:GetPosition())
	if rune == nil then
		return 0
	end

	behaviorLib.runeToPick = rune

	local nUtility = 25

	if rune.unit then
		nUtility = nUtility + 10
	end

	if core.GetItem("Item_Bottle") ~= nil then
		nUtility = nUtility + 20 - tBottle.getCharges() * 5
	end

	return nUtility - Vector3.Distance2DSq(rune.vecLocation, core.unitSelf:GetPosition())/(2000*2000)
end
behaviorLib.PickRuneBehavior["Utility"] = behaviorLib.newPickRuneUtility

function behaviorLib.newPickRuneExecute(botBrain)
	bActionTaken = false
	if core.NumberElements(core.localUnits["EnemyHeroes"]) > 0 then
		local nMesmeRange = skills.mesme:GetRange()
		local mypos = core.unitSelf:GetPosition()
		if skills.mesme:CanActivate() then
			for _,hero in pairs(core.localUnits["EnemyHeroes"]) do
				if Vector3.Distance2DSq(mypos, hero:GetPosition()) <= nMesmeRange * nMesmeRange then
					bActionTaken = core.OrderAbilityEntity(botBrain, skills.mesme, hero)
				end
			end
		end
	end
	if tBottle.getCharges() > 0 and behaviorLib.newUseBottleBehaviorUtility(botBrain) > 0 then
		botBrain:OrderItem(core.GetItem("Item_Bottle").object)
	end

	if not bActionTaken then
		itemPortalKey = core.GetItem("Item_PortalKey")
		if itemPortalKey ~= nil and itemPortalKey:CanActivate() then
			botBrain:OrderItemPosition(itemPortalKey.object, behaviorLib.GetSafeBlinkPosition(behaviorLib.runeToPick.vecLocation, 1200))
			bActionTaken = true
		end
	end

	if not bActionTaken then
		bActionTaken = behaviorLib.pickRune(botBrain, behaviorLib.runeToPick)
	end
	return bActionTaken
end

behaviorLib.PickRuneBehavior["Execute"] = behaviorLib.newPickRuneExecute

----------------
--    Misc    --
----------------

------------------------
-- helpers for bottle --
------------------------

function tBottle.getCharges()
	local itemBottle = core.GetItem("Item_Bottle")
	if itemBottle == nil then
		return 0
	end

	local nCharges = nil
	local modifier = itemBottle:GetActiveModifierKey()
	if modifier == "bottle_empty" then
		nCharges = 0
	elseif modifier == "bottle_1" then
		nCharges = 1
	elseif modifier == "bottle_2" then
		nCharges = 2
	elseif modifier == "bottle_3" then
		nCharges = 3
	else
		nCharges = 4 --rune
	end
	return nCharges
end

--damage stealth illusion movespeed regen
function tBottle.getRune()
	local itemBottle = core.GetItem("Item_Bottle")
	if itemBottle == nil then
		return ""
	end
	local modifier = itemBottle:GetActiveModifierKey()
	local sKey = string.gmatch(modifier, "bottle_%w")
	if sKey == "1" or sKey == "2" or sKey == "3" or sKey =="empty" then
		return ""
	else
		return sKey
	end
end