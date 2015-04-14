-- TutorialBot1 v1.0

------------------------------------------
--  	Bot Initialization  	--
------------------------------------------
local _G = getfenv(0)
local object = _G.object
object.myName = object:GetName()
object.bRunLogic, object.bRunBehaviors, object.bUpdates, object.bUseShop, object.bRunCommands, object.bMoveCommands, object.bAttackCommands, object.bAbilityCommands, object.bOtherCommands = true
object.logger = {}
object.bReportBehavior, object.bDebugUtility, object.logger.bWriteLog, object.logger.bVerboseLog = false
object.core 		= {}
object.eventsLib	= {}
object.metadata 	= {}
object.behaviorLib  	= {}
object.skills   	= {}
runfile "bots/core.lua"
runfile "bots/botbraincore.lua"
runfile "bots/eventslib.lua"
runfile "bots/metadata.lua"
runfile "bots/behaviorlib.lua"
runfile "bots/shoppingLib.lua"

local itemHandler = object.itemHandler
local shoppingLib = object.shoppingLib
--Implement changes to default settings
local tSetupOptions = {
	bCourierCare = false,
	bWaitForLaneDecision = false, --don't wait for lane decision before shopping
	tConsumableOptions = true
}
--call setup function
shoppingLib.Setup(tSetupOptions)
--object.shoppingLib.setup({bReserveItems=true, bWaitForLaneDecision=false, tConsumableOptions=true, bCourierCare=false})

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills
local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub 	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random, sqrt = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random, _G.math.sqrt
local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

BotEcho('loading tutorialBot1...')

--------------------------------
-- Skills - level stats
--------------------------------
function object:SkillBuild()
	local unitSelf = self.core.unitSelf	
	
	if  skills.abilAttributeBoost == nil then
		skills.abilAttributeBoost	= unitSelf:GetAbility(4)
	end
	
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	if skills.abilAttributeBoost:CanLevelUp() then
		skills.abilAttributeBoost:LevelUp()
	end
end

---------------------------------------------------
--				  Behavior changes				 --
---------------------------------------------------
-- We don't want anything running other than last hitting and positioning.
behaviorLib.tBehaviors = {}
tinsert(behaviorLib.tBehaviors, behaviorLib.AttackCreepsBehavior)
tinsert(behaviorLib.tBehaviors, behaviorLib.attackEnemyMinionsBehavior)
tinsert(behaviorLib.tBehaviors, behaviorLib.DontBreakChannelBehavior)
tinsert(behaviorLib.tBehaviors, behaviorLib.PositionSelfBehavior)
tinsert(behaviorLib.tBehaviors, behaviorLib.RetreatFromThreatBehavior)
tinsert(behaviorLib.tBehaviors, behaviorLib.PreGameBehavior)
tinsert(behaviorLib.tBehaviors, behaviorLib.ShopBehavior) -- This has courier included. 
tinsert(behaviorLib.tBehaviors, behaviorLib.StashBehavior)


----------------------------------
--	Items - These don't particularly matter.
----------------------------------
behaviorLib.StartingItems = 
	{"Item_RunesOfTheBlight", "Item_GuardianRing", "Item_HealthPotion", "2 Item_ManaPotion", "2 Item_MinorTotem", }
behaviorLib.LaneItems = 
	{"Item_ManaRegen3", "Item_Marchers", "Item_Shield2", "Item_PlatedGreaves"} --ManaRegen3 is Ring of the Teacher, Shield2 is Helm of the Black Legion
behaviorLib.MidItems = 
	{"Item_MysticVestments", "Item_Lightbrand", "Item_MagicArmor2", "Item_GrimoireOfPower"} --MagicArmor2 is Shaman's
behaviorLib.LateItems = 
	{"Item_FrostfieldPlate", "Item_Morph", "Item_BehemothsHeart", 'Item_Damage9'} --Morph is Sheepstick. Item_Damage9 is Doombringer

BotEcho('finished loading tutorialBot1')
