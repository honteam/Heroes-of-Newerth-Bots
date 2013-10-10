--[[
Gemini Bot v0.3

Skills:
Twin Breath:

Twin Fangs:

Fie And Ice:

toDO:

Laning
Pushing
Reset Bools if timeout
Items
Retreat
--]]
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
runfile "bots/Gemini/gemini_PositionFunctions.lua"

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

BotEcho('loading Gemini_main...')

---------------------------------------------------
---------------------------------------------------
--Important variables and const.
---------------------------------------------------
---------------------------------------------------

object.heroName = 'Hero_Gemini'

-- skillbuild table, 0=q, 1=w, 2=e, 3=r, 4=attri
-- TwinBreath, TwinFangs, TwinStrikes, FireAndIce
object.tSkills = {
    2, 1, 0, 0, 0,
    3, 0, 1, 1, 1,
    3, 2, 2, 2, 4,
    3, 4, 4, 4, 4,
    4, 4, 4, 4, 4,
}

---------------------------------------------------
--Harass related const.
---------------------------------------------------

---------------------------------------------------
--Retreat related const.
---------------------------------------------------

---------------------------------------------------
--Fire and Ice related stuff
---------------------------------------------------


---------------------------------------------------
---------------------------------------------------
-- Skillbuild
---------------------------------------------------
---------------------------------------------------
function object:SkillBuild()
	--core.VerboseLog("SkillBuild()")

	local unitSelf = self.core.unitSelf

	if skills.TwinBreath == nil then
		skills.TwinBreath = unitSelf:GetAbility(0)
		skills.TwinFangs = unitSelf:GetAbility(1)
		skills.TwinStrike = unitSelf:GetAbility(2)
		skills.FireAndIce = unitSelf:GetAbility(3)
		skills.attributeBoost = unitSelf:GetAbility(4)
		skills.Taunt = unitSelf:GetAbility(8)
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

--Gemini ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local addBonus = 0
	
	if EventData.Type == "Ability" then
		--BotEcho("  ABILILTY EVENT!  InflictorName: "..EventData.InflictorName)
		if EventData.InflictorName == "Ability_Gemini1" then
			addBonus = addBonus + object.TwinBreathUseBonus
		elseif EventData.InflictorName == "Ability_Gemini2" then
			addBonus = addBonus + object.TwinFangsUseBonus
		elseif EventData.InflictorName == "Ability_Gemini4" then
			addBonus = addBonus + object.FireAndIceUseBonus
		end
	elseif EventData.Type == "Item" then
		if core.itemEnergizer and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemEnergizer:GetName() then
			addBonus = addBonus + object.nEnergizerUse
		elseif core.itemNullfireBlade and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemNullfireBlade:GetName() then
			addBonus = addBonus + object.nNullfireBladeUse
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

---------------------------------------------------
---------------------------------------------------
-- On Think
---------------------------------------------------
---------------------------------------------------
local bIsFireAndIce = false
--Change behaviors, if we transform between Gemini and Fire and Ice
function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)
	
	local nNow = HoN.GetGameTime()
	
	if not object.bTest then
		funcInitializeHeroPositions()
		object.bTest = true
	end
	funcUpdatePositionData (nNow)
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride



---------------------------------------------------
---------------------------------------------------
-- Harass
---------------------------------------------------
---------------------------------------------------


--	Gemini harass utility
----------------------------------
local function CustomHarassUtilityOverride(hero)
	return 0
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride   

----------------------------------
--	Gemini harass execute
----------------------------------
local function HarassHeroExecuteOverride(botBrain)
		
		--normal harass
		if not bActionTaken then
			if bDebugEchos then BotEcho("No action taken, running my base harass") end
			return object.harassExecuteOld(botBrain)
		end
	
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride


---------------------------------------------------
---------------------------------------------------
-- Retreat
---------------------------------------------------
---------------------------------------------------


---------------------------------------------------
---------------------------------------------------
-- Pushing
---------------------------------------------------
---------------------------------------------------


---------------------------------------------------
---------------------------------------------------
-- Back To Base
---------------------------------------------------
---------------------------------------------------



---------------------------------------------------
-- Standard Item Lists
---------------------------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" 
Item_Lightning2 ChagedHammer  || Item_Weapon3 Savage || 	Item_Brutalizer Brutalizer || 	Item_ManaBurn1 Nullfire || Item_Sicarius firebrand
Item_Strength6 Icebrand || 	Item_Dawnbringer  Dawnbringer || 	Item_LifeSteal5 || abyssal
Boots // abyssal // savage // chargedhammer // Dawnbringer // Nullfire/ Brutalizer	
--]]
behaviorLib.StartingItems = {"Item_LoggersHatchet", "Item_IronBuckler", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = {"Item_Marchers", "Item_ManaRegen3", "Item_Energizer", "Item_Steamboots"} --Item_Strength6 is Frostbrand
behaviorLib.MidItems = {"Item_LifeSteal5", "Item_Lightning1", "Item_Strength6", "Item_Sicarius"} --Immunity is Shrunken Head, Item_StrengthAgility is Frostburn
behaviorLib.LateItems = {"Item_Brutalizer", "Item_Weapon3", "Item_Dawnbringer", "Item_Lightning2", "Item_PostHaste", "Item_Damage9"} --Item_Damage9 is doombringer

BotEcho('finished loading Gemini_main')