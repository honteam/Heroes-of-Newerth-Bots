--ArachnaBot v1.0


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

BotEcho('loading arachna_main...')

object.heroName = 'Hero_Arachna'

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 5, ShortSolo = 4, LongSolo = 3, ShortSupport = 1, LongSupport = 1, ShortCarry = 5, LongCarry = 4}

--------------------------------
-- Skills
--------------------------------
local bSkillsValid = false
function object:SkillBuild()
--Arachna specific
	local unitSelf = self.core.unitSelf

	if not bSkillsValid then
		skills.webbedShot = unitSelf:GetAbility(0)
		skills.hardenCarapace = unitSelf:GetAbility(1)
		skills.precision = unitSelf:GetAbility(2)
		skills.spiderSting = unitSelf:GetAbility(3)
		skills.attributeBoost = unitSelf:GetAbility(4)
		
		if skills.webbedShot and skills.hardenCarapace and skills.precision and skills.spiderSting and skills.attributeBoost then
			bSkillsValid = true
		else
			return
		end
	end
		
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	--speicific level ordering first {precision, web, web, harden}
	if not (skills.precision:GetLevel() >= 1) then
		skills.precision:LevelUp()
	elseif not (skills.webbedShot:GetLevel() >= 2) then
		skills.webbedShot:LevelUp()
	elseif not (skills.hardenCarapace:GetLevel() >= 1) then
		skills.hardenCarapace:LevelUp()
	--max in this order {ult, web, precision, carapace, stats}
	elseif skills.spiderSting:CanLevelUp() then
		skills.spiderSting:LevelUp()
	elseif skills.webbedShot:CanLevelUp() then
		skills.webbedShot:LevelUp()
	elseif skills.precision:CanLevelUp() then
		skills.precision:LevelUp()
	elseif skills.hardenCarapace:CanLevelUp() then
		skills.hardenCarapace:LevelUp()
	else
		skills.attributeBoost:LevelUp()
	end	
end

---------------------------------------------------
--                   Overrides                   --
---------------------------------------------------

----------------------------------
--	Arachna specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

object.webUpBonus = 5
object.spiderUpBonus = 20
object.spiderUseBonus = 45

local function AbilitiesUpUtilityFn()
	local val = 0
	
	if skills.webbedShot:CanActivate() then
		val = val + object.webUpBonus
	end
	
	if skills.spiderSting:CanActivate() then
		val = val + object.spiderUpBonus
	end
	
	return val
end

--Arachna ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local addBonus = 0
	
	if EventData.Type == "Ability" then
		--BotEcho("ABILILTY EVENT!  InflictorName: "..EventData.InflictorName)		
		if EventData.InflictorName == "Ability_Arachna4" then
			addBonus = addBonus + object.spiderUseBonus
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

--Util override
local function CustomHarassUtilityOverride(hero)
	local nUtility = AbilitiesUpUtilityFn()
	
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride   

----------------------------------
--	Arachna specific push strength
----------------------------------
local function PushingStrengthUtilOverride(myHero)
	local myDamage = core.GetFinalAttackDamageAverage(myHero)
	local myAttackDuration = myHero:GetAdjustedAttackDuration()
	local myDPS = myDamage * 1000 / (myAttackDuration) --ms to s
	
	local vTop = Vector3.Create(300, 100)
	local vBot = Vector3.Create(100, 0)
	local m = ((vTop.y - vBot.y)/(vTop.x - vBot.x))
	local b = vBot.y - m * vBot.x 
	
	local util = m * myDPS + b
	util = Clamp(util, 0, 100)
	
	--BotEcho(format("MyDPS: %g  util: %g  myMin: %g  myMax: %g  myAttackAverageL %g", 
	--	myDPS, util, myHero:GetFinalAttackDamageMin(), myHero:GetFinalAttackDamageMax(), myDamage))

	return util
end
behaviorLib.PushingStrengthUtilFn = PushingStrengthUtilOverride


----------------------------------
--	Arachna harass actions
----------------------------------
local function HarassHeroExecuteOverride(botBrain)
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
		return false --can not execute, move on to the next behavior
	end
	
	local unitSelf = core.unitSelf
	
	local bActionTaken = false
	
	--since we are using an old pointer, ensure we can still see the target for entity targeting
	if core.CanSeeUnit(botBrain, unitTarget) then
		local dist = Vector3.Distance2D(unitSelf:GetPosition(), unitTarget:GetPosition())
		local attkRange = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget);
		
		local itemGhostMarchers = core.itemGhostMarchers
		
		local sting = skills.spiderSting
		local stingRange = sting and (sting:GetRange() + core.GetExtraRange(unitSelf) + core.GetExtraRange(unitTarget)) or 0
		local web = skills.webbedShot

		local bUseSting = true
		if core.nDifficulty == core.nEASY_DIFFICULTY and not unitTarget:IsBotControlled() then
			bUseSting = false
		end
		
		if sting and sting:CanActivate() and bUseSting and dist < stingRange then
			bActionTaken = core.OrderAbilityEntity(botBrain, sting, unitTarget)
		elseif dist < attkRange and unitSelf:IsAttackReady() and web and web:CanActivate() then
			bActionTaken = core.OrderAbilityEntity(botBrain, web, unitTarget)
		elseif (sting and sting:CanActivate() and bUseSting and dist > stingRange) then
			--move in when we want to ult			
			local desiredPos = unitTarget:GetPosition()
			
			if itemGhostMarchers and itemGhostMarchers:CanActivate() then
				bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemGhostMarchers)
			end
			
			if not bActionTaken and behaviorLib.lastHarassUtil < behaviorLib.diveThreshold then
				desiredPos = core.AdjustMovementForTowerLogic(desiredPos)
			end
			core.OrderMoveToPosClamp(botBrain, unitSelf, desiredPos, false)
			bActionTaken = true
		end
	end
	
	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride


behaviorLib.StartingItems = {"2 Item_DuckBoots", "2 Item_MinorTotem", "Item_HealthPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = 
	{"Item_Marchers", "2 Item_Soulscream", "Item_EnhancedMarchers"}
behaviorLib.MidItems = 
	{"Item_Sicarius", "Item_Immunity", "Item_ManaBurn2"} 
	--Item_Sicarius is Firebrand, ManaBurn2 is Geomenter's Bane, Immunity is Shrunken Head
behaviorLib.LateItems = 
	{"Item_Weapon3", "Item_Evasion", "Item_BehemothsHeart", "Item_Damage9" } 
	--Weapon3 is Savage Mace, Item_Evasion is Wingbow, and Item_Damage9 is Doombringer


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

BotEcho('finished loading arachna_main')
