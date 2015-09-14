

   

--ArmadonBot v0.5
    --Coded by Sparks1992
 
local _G = getfenv(0)
local object = _G.object
 
object.myName = object:GetName()
 
object.bRunLogic		= true
object.bRunBehaviors    = true
object.bUpdates		    = true
object.bUseShop		    = true
 
object.bRunCommands     = true
object.bMoveCommands    = true
object.bAttackCommands  = true
object.bAbilityCommands = true
object.bOtherCommands   = true
 
object.bReportBehavior = false
object.bDebugUtility = false
object.bDebugExecute = false
 

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false
 
object.core	    		= {}
object.eventsLib		= {}
object.metadata	 		= {}
object.behaviorLib      = {}
object.skills			= {}
 
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
local sqrtTwo = math.sqrt(2)
BotEcho('loading armadon_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 1, ShortSolo = 3, LongSolo = 3, ShortSupport = 2, LongSupport = 2, ShortCarry = 1, LongCarry = 1}


object.heroName = 'Hero_Armadon'
   
--------------------------------
-- Leveling Order | Skills
--------------------------------
object.tSkills = {
	1, 0, 1, 2, 1,
	3, 1, 2, 2, 2,
	3, 0, 0, 0, 4,
	3, 4, 4, 4, 4,
	4, 4, 4, 4, 4,
}

---------------------------------
-- Skill Declare
---------------------------------
local bSkillsValid = false
function object:SkillBuild()
-- takes care at load/reload, <name_#> to be replaced by some convinient name.
    local unitSelf = self.core.unitSelf
       
    if not bSkillsValid then
		skills.abilSnot				= unitSelf:GetAbility(0)
		skills.abilSpine			= unitSelf:GetAbility(1)
		skills.abilArmordillo		= unitSelf:GetAbility(2)
		skills.abilRestless			= unitSelf:GetAbility(3)
 
		if skills.abilSnot and skills.abilSpine and skills.abilArmordillo and skills.abilRestless then
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
 
----------------------------------
--      Armadon items
----------------------------------
behaviorLib.StartingItems =
	{"Item_LoggersHatchet", "Item_IronBuckler", "Item_ManaPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems =
	{ "Item_Marchers", "Item_Shield2", "Item_PlatedGreaves"} -- Items: Marchers,Helm Of The Black Legion, upg Marchers to Plated Greaves
behaviorLib.MidItems =
	{"Item_MagicArmor2","Item_DaemonicBreastplate", "Item_Strength6"} -- Items: Shaman's Headress, Daemonic Breastplate, Icebrand
behaviorLib.LateItems =
	{"Item_BehemothsHeart", "Item_Freeze"} -- Items: Behemoth's Heart, Upg Icebrang into Frostwolf Skull
		   
----------------------------------
--      Armadon specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------
 
object.nSnotUp    = 5
object.nSpineUp   = 10  
 
object.nSnotUse   = 5
object.nSpineUse  = 10
	
local function AbilitiesUpUtilityFn()
	local nUtility = 0
       
	if skills.abilSnot:CanActivate() then
		nUtility = nUtility + object.nSnotUpBonus
	end
       
	if skills.abilSpine:CanActivate() then
		nUtility = nUtility + object.nSpineUpBonus
	end

	return nUtility
end
 
--ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
       
	local nAddBonus = 0
	if EventData.Type == "Ability" then
		       
		if EventData.InflictorName == "Ability_Armadon1" then
			nAddBonus = nAddBonus + object.nSnotUse
		end
		if EventData.InflictorName == "Ability_Armadon2" then
			nAddBonus = nAddBonus + object.nSpineUse
		end
 
	end
       
	if nAddBonus > 0 then
		--decay before we add
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent    = object.oncombateventOverride
 
----------------------------------
--      Armadon harass actions
----------------------------------
local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = false
       
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
		return false --can not execute, move on to the next behavior
	end
       
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
       
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
       
	local nLastHarassUtil = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)  
       
	local bActionTaken = false
       
	local abilSnot = skills.abilSnot
	local abilSpine = skills.abilSpine
 
 
	--Snot
	if not bActionTaken and abilSnot:CanActivate() and bCanSee then
		local nRange = abilSnot:GetRange()
		if abilSpine:CanActivate() and nTargetDistanceSq < (nRange * nRange) then
			bActionTaken = core.OrderAbilityEntity(botBrain, abilSnot, unitTarget)
		end
	end
       
	--Spine
	if abilSpine:CanActivate() then
		if nTargetDistanceSq < (650 * 650) then
			bActionTaken = core.OrderAbility(botBrain, abilSpine)
		elseif unitSelf:GetManaPercent() > .8 then
			bActionTaken = core.OrderAbility(botBrain, abilSpine)
		end
	end

 
	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride
 
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
	rainbows motherfucker
	invisible
--]]
 
BotEcho('finished loading armadon_main')