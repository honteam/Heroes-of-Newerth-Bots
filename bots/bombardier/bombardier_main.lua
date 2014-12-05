-- By community member Anakonda

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

BotEcho('loading bombardier_main.lua...')

object.heroName = 'Hero_Bombardier'

object.tSkills = {
    2, 1, 2, 0, 0,
    3, 0, 0, 1, 1, 
    3, 1, 2, 2, 4,
    3, 4, 4, 4, 4,
    4, 4, 4, 4, 4,
}

core.tLanePreferences = {Jungle = 0, Mid = 1, ShortSolo = 1, LongSolo = 1, ShortSupport = 5, LongSupport = 5, ShortCarry = 2, LongCarry = 2}

--------------------------------
-- Skills
--------------------------------
function object:SkillBuild()

-- takes care at load/reload, <name_#> to be replaced by some convinient name.
    local unitSelf = self.core.unitSelf
    if  skills.abilStickyBomb == nil then
        skills.abilStickyBomb = core.WrapInTable(unitSelf:GetAbility(0))
        skills.abilStickyBomb.nLastCastTime = 0
        skills.abilBombardment = unitSelf:GetAbility(1)
        skills.abilDust = core.WrapInTable(unitSelf:GetAbility(2))
        skills.abilDust.nLastCastTime = 0
        skills.abilAirStrike = unitSelf:GetAbility(3)
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

---------------------------------------------------
--                    Items                      --
---------------------------------------------------
behaviorLib.StartingItems = {"Item_PretendersCrown", "Item_PretendersCrown", "Item_MinorTotem", "Item_ManaPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = {"Item_Marchers", "Item_EnhancedMarchers", "Item_GraveLocket", "Item_Weapon1"} --ManaRegen3 is Ring of the Teacher
behaviorLib.MidItems =  {"Item_SpellShards", "Item_Lightbrand", "Item_Intelligence7"} --Intelligence7 is Staff of the Master
behaviorLib.LateItems = {"Item_Morph", "Item_BehemothsHeart", "Item_GrimoireOfPower"} --Morph is Sheepstick.

---------------------------------------------------
--                   Overrides                   --
---------------------------------------------------

----------------------------------
--	Hero specific harass bonuses
----------------------------------

object.nStickyBombUp = 10
object.nBombardmentUp = 10
object.nDustUp = 5
object.nAirStrikeUp = 35
object.nSheepstickUp = 20

object.nStickyBombUse = 20
object.nBombardmentUse = 20
object.nAirStrikeUse = 40
object.nSheepstickUse = 15

object.nStickyBombThreshold = 30
object.nBombardmentThreshold = 27
object.nAirStrikeThreshold = 70
object.nSheepstickThreshold = 40

local function AbilitiesUpUtility(hero)
	local nUtility = 0
	
	if skills.abilStickyBomb:CanActivate() then
		nUtility = nUtility + object.nStickyBombUp
	end
	
	if skills.abilBombardment:CanActivate() then
		nUtility = nUtility + object.nBombardmentUp
	end
	
	if skills.abilDust:CanActivate() then
		nUtility = nUtility + object.nDustUp
	end
	
	if skills.abilAirStrike:CanActivate() then
		nUtility = nUtility + object.nAirStrikeUp
	end
	
	local itemSheepstick = core.GetItem("Item_Morph")
	if itemSheepstick and itemSheepstick:CanActivate() then
		nUtility = nUtility + object.nSheepstickUp
	end
	return nUtility
end

function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local bDebugEchos = false
	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
		if bDebugEchos then BotEcho("  ABILILTY EVENT!  InflictorName: "..EventData.InflictorName) end
		if EventData.InflictorName == "Ability_Bombardier1" then
			nAddBonus = nAddBonus + object.nStickyBombUse
		elseif EventData.InflictorName == "Ability_Bombardier2" then
			nAddBonus = nAddBonus + object.nBombardmentUse
		elseif EventData.InflictorName == "Ability_Bombardier4" then
			nAddBonus = nAddBonus + object.nAirStrikeUse
		end
	elseif EventData.Type == "Item" then
		local itemSheepstick = core.GetItem("Item_Morph")
		if itemSheepstick ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == itemSheepstick:GetName() then
			nAddBonus = nAddBonus + self.nSheepstickUse
		end
	end
	
	if nAddBonus > 0 then
		--decay before we add
		core.DecayBonus(self)
	
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent 	= object.oncombateventOverride

--Util calc override
local function CustomHarassUtilityFnOverride(hero)
	local nUtility = AbilitiesUpUtility(hero)
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride   

----------------------------------
--           Fights             --
----------------------------------
local function HarassHeroExecuteOverride(botBrain)
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil then
		return false --Eh nothing here
	end
	
	--fetch some variables 
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	
	local bCantDodge = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 160
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)
	
	local vecTargetPosition = unitTarget:GetPosition()
	local nDistanceSQ = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	
	local nAggroValue = behaviorLib.lastHarassUtil
	local bActionTaken = false

	local nTime = HoN.GetGameTime()

	local bBombUp = skills.abilStickyBomb:CanActivate() and skills.abilStickyBomb.nLastCastTime + 10000 < nTime
	local bBombardmentUp = skills.abilBombardment:CanActivate()
	local bDustUp = skills.abilDust:CanActivate() and skills.abilDust:GetCharges() > 0
	local bAirStrikeUp = skills.abilAirStrike:CanActivate()

	--Sticky Bomb
	if bCantDodge or nAggroValue > object.nStickyBombThreshold then
		if bBombUp and bCanSee then
			vecBombPos = nil
			if bCantDodge then
				vecBombPos = vecTargetPosition
			else
				vecBombPos = vecTargetPosition + unitTarget:GetHeading() * 0.5 * unitTarget:GetMoveSpeed()
			end
			if Vector3.Distance2DSq(vecMyPosition, vecBombPos) < skills.abilStickyBomb:GetRange() ^ 2 then
				bActionTaken = core.OrderAbilityPosition(botBrain, skills.abilStickyBomb, vecBombPos)
				if bActionTaken then
					skills.abilStickyBomb.nLastCastTime = nTime
				end
			end
		end
	end

	--Sheep stick
	if not bActionTaken and not bCantDodge then
		local itemSheepstick = core.GetItem("Item_Morph")
		if itemSheepstick ~= nil and itemSheepstick:CanActivate() then
			if nAggroValue > object.nSheepstickThreshold then
				bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemSheepstick, unitTarget)
			end
		end
	end

	--Bombardment
	if not bActionTaken then
		if bBombardmentUp and nAggroValue > object.nBombardmentThreshold then
			if nDistanceSQ < skills.abilBombardment:GetRange() ^ 2 then
				local vecTarget = vecTargetPosition + 100 * (unitTarget:GetHeading() or Vector3.Create())
				actionTaken = core.OrderAbilityPosition(botBrain, skills.abilBombardment, vecTarget)
			end
		end
	end

	--Air strike
	if not bActionTaken then
		if bAirStrikeUp and nAggroValue > object.nAirStrikeThreshold then
			if bCanSee then
				--Todo some math based unitTargets runing direction
				botBrain:OrderAbilityVector(skills.abilAirStrike, vecTargetPosition + unitTarget:GetHeading() * unitTarget:GetMoveSpeed() * 2, vecTargetPosition)
				actionTaken = true
			end
		end
	end

	--Boom dust
	if not bActionTaken and bDustUp then
		if skills.abilDust.nLastCastTime + 1500 < nTime then --Dont spam all charges at once
			if nDistanceSQ < skills.abilDust:GetRange() ^ 2 then
				bActionTaken = core.OrderAbilityEntity(botBrain, skills.abilDust, unitTarget)
				if bActionTaken then
					skills.abilDust.nLastCastTime = nTime
					--core.OrderAttackClamp(botBrain, self, unitTarget, true)
				end
			end
		end
	end

	
	if not bActionTaken then
		bActionTaken = object.harassExecuteOld(botBrain)
	end
	return bActionTaken
end

object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

--Run away. Run away
function behaviorLib.CustomRetreatExecute(botBrain)
	local bActionTaken = false
	local heroes = HoN.GetUnitsInRadius(core.unitSelf:GetPosition(), 700, core.UNIT_MASK_ALIVE + core.UNIT_MASK_HERO)
	local unitClosestEnemy = nil
	local nClosestDistance = 999999
	local vecMyPosition = core.unitSelf:GetPosition()
	for i, hero in ipairs(heroes) do
		if hero:GetTeam() ~= core.unitSelf:GetTeam() then
			local nDistanceSQ = Vector3.GetDistance2DSq(vecMyPosition, hero:GetPosition())
			if nDistanceSQ < nClosestDistance then
				nClosestDistance = nDistanceSQ
				unitClosestEnemy = hero
			end
		end
	end

	if unitClosestEnemy ~= nil then
		--Todo if multiple do some math
		bActionTaken = core.OrderAbilityPosition(botBrain, skills.abilBombardment, unitClosestEnemy.GetPosition())
	end

	return bActionTaken
end

function object.PushExecuteOverride(botBrain)
	local bActionTaken = false
	if core.unitSelf:GetManaPercent() > 0.5 and core.NumberElements(core.localUnits["EnemyCreeps"]) > 0 then
		bActionTaken = core.OrderAbilityPosition(botBrain, skills.abilBombardment, HoN.GetGroupCenter(core.localUnits["EnemyCreeps"]))
	end

	if not bActionTaken then
		bActionTaken = object.PushExecuteOld(botBrain)
	end
	return bActionTaken
end
object.PushExecuteOld = behaviorLib.PushBehavior["Execute"]
behaviorLib.PushBehavior["Execute"] = object.PushExecuteOverride


BotEcho('finished loading bombardier_main.lua')
