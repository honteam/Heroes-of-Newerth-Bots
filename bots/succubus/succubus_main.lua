
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

local bottle = {}
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

object.mesmeUseBonus = 5
object.holdUseBonus = 35
object.heartacheUseBonus = 15

object.mesmeUpBonus = 5
object.holdUpBonus = 20
object.heartacheUpBonus = 10

object.holdThreshold = 60
object.heartacheThreshold = 40
object.mesmeThreshold = 50
object.pkThreshold = 45

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

	local lastRetreatUtil = behaviorLib.lastRetreatUtil

	local missingHP = unitSelf:GetMaxHealth() - unitSelf:GetHealth()

	local mesmeRange = skills.mesme:GetRange()
	local heartacheRange = skills.heartache:GetRange()
	local mesmeCanActivate = skills.mesme:CanActivate()
	local heartacheCanActivate = skills.heartache:CanActivate()
	local bActionTaken = false

	local itemPortalKey = core.GetItem("Item_PortalKey")
	if lastRetreatUtil > object.retreatCastThreshold and itemPortalKey ~= nil then
		if itemPortalKey:CanActivate() then
			botBrain:OrderItemPosition(itemPortalKey.object, behaviorLib.GetSafeBlinkPosition(core.allyWell:GetPosition(), 1200))
			bActionTaken = true
		end
	end

	if not bActionTaken then
		if lastRetreatUtil > object.retreatCastThreshold then
			for _, hero in pairs(core.localUnits["EnemyHeroes"]) do
				if not hero:isMagicImmune() then
					distanceSq = Vector3.Distance2DSq(mypos, hero:GetPosition())
					if heartacheCanActivate and distanceSq < heartacheRange * heartacheRange and missingHP > 300 and not hero:HasState("State_Succubis_Ability3") then
						bActionTaken = core.OrderAbilityEntity(botBrain, skills.heartache, hero)
						break
					end
					if mesmeCanActivate and distanceSq < mesmeRange * mesmeRange then
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
	local itemPortalKey = core.GetItem("Item_PortalKey")
	if itemPortalKey ~= nil then
		if itemPortalKey:CanActivate() then
			botBrain:OrderItemPosition(itemPortalKey.object, behaviorLib.GetSafeBlinkPosition(core.allyWell:GetPosition(), 1200))
			bActionTaken = true
		end
	end

	return bActionTaken
end

------------------------------------------
--			oncombatevent override		--
------------------------------------------
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)

	local addBonus = 0

	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_Succubis1" then

		elseif EventData.InflictorName == "Ability_Succubis2" then
			addBonus = addBonus + object.heartacheUseBonus
		elseif EventData.InflictorName == "Ability_Succubis3" then
			addBonus = addBonus + object.heartacheUseBonus
		elseif EventData.InflictorName == "Ability_Succubis4" then
			addBonus = addBonus + object.holdUseBonus
			object.ultTime = HoN.GetGameTime()
		end
	end

	if addBonus > 0 then
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + addBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent	 = object.oncombateventOverride

local function CustomHarassUtilityFnOverride(hero)
	if hero:HasState("State_Succubis_Ability3") then
		return -100
	end

	local val = 0
	
	if skills.mesme:CanActivate() then
		val = val + object.mesmeUpBonus
	end
	
	if skills.hold:CanActivate() then
		val = val + object.holdUpBonus
	end

	if skills.heartache:CanActivate() then
		val = val + object.heartacheUpBonus
	end

	local unitSelf = core.unitSelf

	if unitSelf:HasState("State_PowerupStealth") or unitSelf:HasState("State_PowerupMoveSpeed") then
		val = val + 20
	end

	-- Less mana less aggerssion
	val = val + (unitSelf:GetManaPercent() - 0.80) * 45
	return val

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
	local nTargetExtraRange = core.GetExtraRange(unitTarget)
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local targetMagicImmune = unitTarget:isMagicImmune()
	
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)	
	local bActionTaken = false

	local portalKey = core.GetItem("Item_PortalKey")
	local puzzleBox = core.GetItem("Item_Summon")
	local shrunkenHead = core.GetItem("Item_Immunity")

	--damage stealth illusion movespeed regen
	local runeInBottle = bottle.getRune()
	if runeInBottle == "damage" or runeInBottle == "illusion" or runeInBottle == "movespeed" then
		botBrain:OrderItem(core.GetItem("Item_Bottle"))
	end

	--pk suprise
	if bCanSee and portalKey and portalKey:CanActivate() and object.pkThreshold < nLastHarassUtility then
		if nTargetDistanceSq > 800 * 800 then
			if nLastHarassUtility > behaviorLib.diveThreshold or core.NumberElements(core.GetTowersThreateningPosition(vecTargetPosition, nMyExtraRange, core.myTeam)) == 0 then
				local _, sortedTable = HoN.GetUnitsInRadius(vecTargetPosition, 1000, core.UNIT_MASK_HERO + core.UNIT_MASK_ALIVE, true)
				local EnemyHeroes = sortedTable.EnemyHeroes
				if core.NumberElements(EnemyHeroes) == 1 then
					bActionTaken = core.OrderItemPosition(botBrain, unitSelf, portalKey, vecTargetPosition)
				end
			end
		end
	end

	local mesmeRange = skills.mesme:GetRange()
	local smittenRange = skills.smitten:GetRange()
	local mesmeCanActivate = skills.mesme:CanActivate()
	local smittenCanActivate = skills.smitten:CanActivate()

	--teamfight
	if not bActionTaken then
		if nLastHarassUtility > object.mesmeThreshold then
			for _,hero in pairs(core.localUnits["EnemyHeroes"]) do
				if hero ~= unitTarget then
					if not hero:HasState("State_Succubis_Ability3") and not hero:HasState("State_Succubis_Ability1") and not hero:isMagicImmune() then
						distanceSq = Vector3.Distance2DSq(vecMyPosition, hero:GetPosition())
						if mesmeCanActivate and distanceSq < mesmeRange*mesmeRange then
							bActionTaken = core.OrderAbilityEntity(botBrain, skills.mesme, hero)
							break
						elseif smittenCanActivate and distanceSq < smittenRange*smittenRange then
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
			if nLastHarassUtility > object.holdThreshold and skills.hold:CanActivate() then
				if puzzleBox and puzzleBox:CanActivate() then
					bActionTaken = true
					botBrain:OrderItem(puzzleBox.object)
				elseif shrunkenHead and shrunkenHead:CanActivate() then
					bActionTaken = true
					botBrain:OrderItem(shrunkenHead.object)
				else
					bActionTaken = core.OrderAbilityEntity(botBrain, skills.hold, unitTarget)
				end
			end
			if not bActionTaken and nLastHarassUtility > object.heartacheThreshold and skills.heartache:CanActivate() then
				bActionTaken = core.OrderAbilityEntity(botBrain, skills.heartache, unitTarget)
			end
		end
	end
	
	for _,unit in pairs(core.tControllableUnits["AllUnits"]) do
		local typeName = unit:GetTypeName()
		if typeName ~= "Pet_GroundFamiliar" and typeName ~= "Pet_FlyngCourier" then
			core.OrderAttack(botBrain, unit, unitTarget)
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

	local missingHP = unitSelf:GetMaxHealth() - unitSelf:GetHealth()

	local heartacheUtil = 0

	if skills.heartache:CanActivate() and core.NumberElements(core.localUnits["Enemies"]) > 0 then
		heartacheUtil = core.ATanFn(missingHP, Vector3.Create(300, 25), Vector3.Create(0,0), 100)
	end

	return heartacheUtil
end

function behaviorLib.healHeartacheExecute(botBrain)
	local unitSelf = core.unitSelf
	local mypos = unitSelf:GetPosition()

	local bActionTaken = false

	local heartacheCanActivate = skills.heartache:CanActivate()
	if not bActionTaken and heartacheCanActivate then
		local heartacheRange = skills.heartache:GetRange()
		if core.NumberElements(core.localUnits["EnemyHeroes"]) > 0 then
			local closestHero = nil
			local closestDistance = 650 * 650 -- Only units closer than 650 are valid
			for _, hero in pairs(core.localUnits["EnemyHeroes"]) do
				local distance = Vector3.Distance2DSq(hero:GetPosition(), mypos)
				if distance < closestDistance then
					closestDistance = distance
					closestHero = hero
					if distance < heartacheRange*heartacheRange then
						break
					end
				end
			end
			if closestHero then
				bActionTaken = core.OrderAbilityEntity(botBrain, skills.heartache, closestHero)
			end
		else
			if core.NumberElements(core.localUnits["EnemyCreeps"]) then
				--just find creep in range or closest
				local closestCreep = nil
				local closestDistance = 650 * 650 -- Only units closer than 650 are valid
				for _, creep in pairs(core.localUnits["EnemyCreeps"]) do
					local distance = Vector3.Distance2DSq(creep:GetPosition(), mypos)
					if distance < closestDistance then
						closestDistance = distance
						closestCreep = creep
						if distance < heartacheRange*heartacheRange then
							break
						end
					end
				end
				if closestCreep then
					bActionTaken = core.OrderAbilityEntity(botBrain, skills.heartache, closestCreep)
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

	utility = behaviorLib.oldUseBottleBehaviorUtility(botBrain)
	if bottle.getRune() == "regen" then
		utility = utility * 0.8
	end
	return utility
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

	local utility = 25

	if rune.unit then
		utility = utility + 10
	end

	if core.GetItem("Item_Bottle") ~= nil then
		utility = utility + 20 - bottle.getCharges() * 5
	end

	return utility - Vector3.Distance2DSq(rune.vecLocation, core.unitSelf:GetPosition())/(2000*2000)
end
behaviorLib.PickRuneBehavior["Utility"] = behaviorLib.newPickRuneUtility

function behaviorLib.newPickRuneExecute(botBrain)
	bActionTaken = false
	if core.NumberElements(core.localUnits["EnemyHeroes"]) > 0 then
		local mesmeRange = skills.mesme:GetRange()
		local mypos = core.unitSelf:GetPosition()
		if skills.mesme:CanActivate() then
			for _,hero in pairs(core.localUnits["EnemyHeroes"]) do
				if Vector3.Distance2DSq(mypos, hero:GetPosition()) <= mesmeRange * mesmeRange then
					bActionTaken = core.OrderAbilityEntity(botBrain, skills.mesme, hero)
				end
			end
		end
	end
	if bottle.getCharges() > 0 and behaviorLib.newUseBottleBehaviorUtility(botBrain) > 0 then
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

function bottle.getCharges()
	local itemBottle = core.GetItem("Item_Bottle")
	if itemBottle == nil then
		return nil
	end

	local charges = nil
	local modifier = itemBottle:GetActiveModifierKey()
	if modifier == "bottle_empty" then
		charges = 0
	elseif modifier == "bottle_1" then
		charges = 1
	elseif modifier == "bottle_2" then
		charges = 2
	elseif modifier == "bottle_3" then
		charges = 3
	else
		charges = 4 --rune
	end
	return charges
end

--damage stealth illusion movespeed regen
function bottle.getRune()
	local itemBottle = core.GetItem("Item_Bottle")
	if itemBottle == nil then
		return ""
	end
	local modifier = itemBottle:GetActiveModifierKey()
	local key = string.gmatch(modifier, "bottle_%w")
	if key == "1" or key == "2" or key == "3" or key =="empty" then
		return ""
	else
		return key
	end
end