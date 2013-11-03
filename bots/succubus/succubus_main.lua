
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
runfile "bots/rune.lua"

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

local runelib = object.runelib

BotEcho(object:GetName()..' loading succubus_main...')

----------------------------------------------------------
--  			  bot constant definitions				--
----------------------------------------------------------

object.heroName = 'Hero_Succubis'

--   item buy order. internal names  
behaviorLib.StartingItems  = {"Item_MarkOfTheNovice", "Item_MarkOfTheNovice", "Item_RunesOfTheBlight", "Item_MarkOfTheNovice"}
behaviorLib.LaneItems  = {"Item_Bottle", "Item_EnhancedMarchers"}
behaviorLib.MidItems  = {"Item_PortalKey", "Item_Immunity", "Item_Summon 3"}
behaviorLib.LateItems  = {"Item_Intelligence7", "Item_GrimoireOfPower"}
--item_summon is puzzlebox; Item_Intelligence7 is master staff

object.ultTime = 0

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

-- takes care at load/reload, <name_#> to be replaced by some convinient name.
	local unitSelf = self.core.unitSelf
	if  skills.smitten == nil then
		skills.smitten = unitSelf:GetAbility(0)
		skills.heartache = unitSelf:GetAbility(1)
		skills.mesme = unitSelf:GetAbility(2)
		skills.hold = unitSelf:GetAbility(3)
		skills.abilAttributeBoost = unitSelf:GetAbility(4)
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

----------------------------------
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)
	object.FindItemsOld(botBrain)

	if core.itemPortalKey ~= nil and not core.itemPortalKey:IsValid() then
		core.itemPortalKey = nil
	end
	if core.itemPuzzlebox ~= nil and not core.itemPuzzlebox:IsValid() then
		core.itemPortalKey = nil
	end
	if core.itemShrunkenHead ~= nil and not core.itemShrunkenHead:IsValid() then
		core.itemShrunkenHead = nil
	end

	if core.itemPortalKey and core.itemPuzzlebox and core.itemShrunkenHead then
		return
	end

	local inventory = core.unitSelf:GetInventory(true)
	for slot = 1, 6, 1 do
		local curItem = inventory[slot]
		if curItem then
			if core.itemPortalKey == nil and curItem:GetName() == "Item_PortalKey" then
				core.itemPortalKey = core.WrapInTable(curItem)
			elseif core.itemShrunkenHead == nil and not curItem:IsRecipe() and curItem:GetName() == "Item_Immunity" then
				core.itemShrunkenHead = core.WrapInTable(curItem)
			elseif core.itemPuzzlebox == nil and curItem:GetName() == "Item_Summon" then
				core.itemPuzzlebox = core.WrapInTable(curItem)
			end
		end
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride

------------------------------------------
--			oncombatevent override		--
------------------------------------------
object.mesmeUseBonus = 5
object.holdUseBonus = 35
object.heartacheUseBonus = 15
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

object.mesmeUpBonus = 5
object.holdUpBonus = 20
object.heartacheUpBonus = 10

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

	-- Less mana less aggerssion
	val = val + (core.unitSelf:GetManaPercent() - 0.80) * 45
	return val

end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride  

---------------------------------------------------------
--					Harass Behavior					   --
---------------------------------------------------------

object.holdThreshold = 60
object.heartacheThreshold = 40
object.mesmeThreshold = 50
object.pkThreshold = 45
local function HarassHeroExecuteOverride(botBrain)
	local unitSelf = core.unitSelf

	--Cant trust to dontbreakchanneling
	if object.ultTime + 300 > HoN.GetGameTime() or unitSelf:IsChanneling() then
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
	local targetMagicImmune = IsMagicImmune(unitTarget)
	
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)	
	local bActionTaken = false

	--pk suprise
	if bCanSee and core.itemPortalKey and core.itemPortalKey:CanActivate() and object.pkThreshold < nLastHarassUtility then
		if Vector3.Distance2DSq(vecMyPosition, vecTargetPosition) > 800 * 800 then
			if core.NumberElements(core.GetTowersThreateningPosition(vecTargetPosition, nMyExtraRange, core.myTeam)) == 0 or nLastHarassUtility > behaviorLib.diveThreshold then
				local _,secondtable = HoN.GetUnitsInRadius(vecTargetPosition, 1000, core.UNIT_MASK_HERO + core.UNIT_MASK_ALIVE, true)
				local EnemyHeroes = secondtable.EnemyHeroes
				if core.NumberElements(EnemyHeroes) == 1 then
					bActionTaken = core.OrderItemPosition(botBrain, unitSelf, core.itemPortalKey, vecTargetPosition)
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
					if not hero:HasState("State_Succubis_Ability3") and not hero:HasState("State_Succubis_Ability1") and not IsMagicImmune(hero) then
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
				if core.itemPuzzlebox and core.itemPuzzlebox:CanActivate() then
					botBrain:OrderItem(core.itemPuzzlebox.object)
				elseif core.itemShrunkenHead and core.itemShrunkenHead:CanActivate() then
					bActionTaken = true
					botBrain:OrderItem(core.itemShrunkenHead.object)
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

function behaviorLib.newDontBreakChannelExecute(botBrain)
	local unitTarget = nil
	for _,hero in pairs(core.localUnits.EnemyHeroes) do
		if hero:HasState("State_Succubis_Ability4") then
			unitTarget = hero
		end
	end
	if unitTarget then
		for _,unit in pairs(core.tControllableUnits["AllUnits"]) do
			local typeName = unit:GetTypeName()
			if typeName ~= "Pet_GroundFamiliar" and typeName ~= "Pet_FlyngCourier" then
				core.OrderAttack(botBrain, unit, core.localUnits.EnemyHeroes)
			end
		end
	end
end
behaviorLib.DontBreakChannelBehavior["Execute"] = behaviorLib.newDontBreakChannelExecute

---------------
-- Pick Rune --
---------------
behaviorLib.runeToPick = nil
function behaviorLib.PickRuneUtility(botBrain)
	local rune = runelib.GetNearestRune()
	if rune == nil then
		return 0
	end

	behaviorLib.runeToPick = rune

	local utility = 20

	if rune.unit then
		utility = utility + 10
	end

	return utility - Vector3.Distance2DSq(rune.location, core.unitSelf:GetPosition())/(2000*2000)
end

function behaviorLib.PickRuneExecute(botBrain)
	if core.NumberElements(core.localUnits["EnemyHeroes"]) > 0 then
		local mesmeRange = skills.mesme:GetRange()
		local mypos = core.unitSelf:GetPosition()
		if skills.mesme:CanActivate() then
			for _,hero in pairs(core.localUnits["EnemyHeroes"]) do
				if Vector3.Distance2DSq(mypos, hero:GetPosition()) <= mesmeRange * mesmeRange then
					return core.OrderAbilityEntity(botBrain, skills.mesme, hero)
				end
			end
		end
	end
	return runelib.pickRune(botBrain, behaviorLib.runeToPick)
end

behaviorLib.PickRuneBehavior = {}
behaviorLib.PickRuneBehavior["Utility"] = behaviorLib.PickRuneUtility
behaviorLib.PickRuneBehavior["Execute"] = behaviorLib.PickRuneExecute
behaviorLib.PickRuneBehavior["Name"] = "Pick Rune"
tinsert(behaviorLib.tBehaviors, behaviorLib.PickRuneBehavior)

----------------
--    Misc    --
----------------

function IsMagicImmune(unit)
	local states = { "State_Item3E", "State_Predator_Ability2", "State_Jereziah_Ability2", "State_Rampage_Ability1_Self", "State_Rhapsody_Ability4_Buff", "State_Hiro_Ability1" }
	for _, state in ipairs(states) do
		if unit:HasState(state) then
			return true
		end
	end
	return false
end