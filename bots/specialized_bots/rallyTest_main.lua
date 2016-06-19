--RallyTest v0.1


local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic 		= true
object.bRunBehaviors	= false
object.bUpdates 		= true
object.bUseShop 		= true

object.bRunCommands 	= true
object.bMoveCommands 	= true
object.bAttackCommands 	= true
object.bAbilityCommands = true
object.bOtherCommands 	= true

object.bReportBehavior = true
object.bDebugUtility = true
object.bDebugExecute = true

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

BotEcho('loading magmus_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 1, ShortSolo = 5, LongSolo = 4, ShortSupport = 2, LongSupport = 2, ShortCarry = 4, LongCarry = 5}

object.heroName = 'Hero_Magmar'


--------------------------------
-- Skills
--------------------------------
function object:SkillBuild()
	local unitSelf = self.core.unitSelf

	if  skills.abilCompell == nil then
		skills.abilCompell		= unitSelf:GetAbility(0)
		skills.abilAttributeBoost	= unitSelf:GetAbility(4)
	end
	
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	--Ult, Lava Surge, 1 in Steam Bath, 1 in stats, Volcanic Touch, Steam Bath, Stats
	if skills.abilCompell:CanLevelUp() then
		skills.abilCompell:LevelUp()
	elseif skills.abilAttributeBoost:CanLevelUp() then
		skills.abilAttributeBoost:LevelUp()
	end
end

---------------------------------------------------
--                   Overrides                   --
---------------------------------------------------

-- [[for testing
function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)
	
	core.unitSelf:TeamShare()
	
	if self.nDeg == nil then
		self.nDeg = 0
	end

	local unitSelf = core.unitSelf
	local myPos = unitSelf:GetPosition()
	
	local vecDirection = Vector3.Create(1, 0)
	vecDirection = core.RotateVec2D(vecDirection, self.nDeg)
	core.DrawDebugArrow(myPos, myPos + vecDirection * 150, 'yellow')
	
	local abilCompell = skills.abilCompell
	if abilCompell:CanActivate() then
		core.OrderAbilityEntityVector(self, abilCompell, unitSelf, vecDirection)
	end	
	
	self.nDeg = (self.nDeg + 20) % 360
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride
--]]

BotEcho('finished loading magmus_main')

