--HammerstormBot v1.0


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

BotEcho('loading hammerstorm_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 3, ShortSolo = 3, LongSolo = 3, ShortSupport = 2, LongSupport = 2, ShortCarry = 5, LongCarry = 5}

object.heroName = 'Hero_Hammerstorm'


---------------------------------------
-- Most effective stunable target function
---------------------------------------
local function funcBestTargetStun(tEnemyHeroes, unitTarget, nRange)
	local nHeroes = core.NumberElements(tEnemyHeroes)
	if nHeroes <= 1 then 
		return unitTarget 
	end

	local tTemp = core.CopyTable(tEnemyHeroes)

	local nRangeSq = nRange*nRange
	local nDistSq = 0
	local unitBestTarget = nil
	local nBestTargetsHit = 0

	for nTargetID,unitTarget in pairs(tEnemyHeroes) do
		local nTargetsHit = 1
		local vecCurrentTargetsPosition = unitTarget:GetPosition()
		for nHeroID,unitHero in pairs(tTemp) do
			if nTargetID ~= nHeroID then
				nDistSq = Vector3.Distance2DSq(vecCurrentTargetsPosition, unitHero:GetPosition())
				if nDistSq < nRangeSq then
					nTargetsHit = nTargetsHit + 1
				end
			end
		end
		
		if nTargetsHit > nBestTargetsHit then
			nBestTargetsHit = nTargetsHit
			unitBestTarget = unitTarget
		end
	end

	return unitTarget
end


----------------------------------
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)
	object.FindItemsOld(botBrain)

	core.ValidateItem(core.itemPortalKey)
	
	if core.itemPortalKey then
		return
	end

	local inventory = core.unitSelf:GetInventory(false)
	for slot = 1, 6, 1 do
		local curItem = inventory[slot]
		if curItem and not curItem:IsRecipe() then
			if core.itemPortalKey == nil and curItem:GetName() == "Item_PortalKey" then
				core.itemPortalKey = core.WrapInTable(curItem)
			end
		end
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride


--------------------------------
-- Skills
--------------------------------
local bSkillsValid = false
function object:SkillBuild()
	local unitSelf = self.core.unitSelf

	if not bSkillsValid then
		skills.abilHammerThrow = unitSelf:GetAbility(0)
		skills.abilMightySwing = unitSelf:GetAbility(1)
		skills.abilGalvanize = unitSelf:GetAbility(2)
		skills.abilBruteStrength = unitSelf:GetAbility(3)
		skills.abilAttributeBoost = unitSelf:GetAbility(4)
		
		if skills.abilHammerThrow and skills.abilMightySwing and skills.abilGalvanize and skills.abilBruteStrength and skills.abilAttributeBoost then
			bSkillsValid = true
		else
			return
		end		
	end
	
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	--Ult, HammerThrow, 2 in stats, Galvanzie, Mighty Swing, Stats
	if skills.abilBruteStrength:CanLevelUp() then
		skills.abilBruteStrength:LevelUp()
	elseif skills.abilHammerThrow:CanLevelUp() then
		skills.abilHammerThrow:LevelUp()
	elseif skills.abilAttributeBoost:GetLevel() < 1 then
		skills.abilAttributeBoost:LevelUp()
	elseif skills.abilGalvanize:CanLevelUp() then
		skills.abilGalvanize:LevelUp()
	elseif skills.abilMightySwing:CanLevelUp() then
		skills.abilMightySwing:LevelUp()
	else
		skills.abilAttributeBoost:LevelUp()
	end
end

---------------------------------------------------
--                   Overrides                   --
---------------------------------------------------

--[[for testing
--object.bHeld = false
function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)
	
	-- Insert code here
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride
--]]

behaviorLib.nCreepPushbackMul = 0.5
behaviorLib.nTargetPositioningMul = 0.6

----------------------------------
--	Hammerstorm specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

object.nHammerThrowUp = 13
object.nBruteStrengthUp = 17

object.nHammerThrowUse = 25
object.nGalvanizeActive = 5
object.nBruteStrengthActive = 25
object.nPortalKeyUse = 20

object.nGalvanizeExpireTime = 0
object.sGalvanizeStateName = "State_Hammerstorm_Ability3"
object.nBruteStrengthExpireTime = 0
object.sBruteStrengthStateName = "State_Hammerstorm_Ability4"

object.nPortalKeyThreshold = 45
object.nHammerThrowThreshold = 33
object.nGalvanizeThreshold = 45

local function AbilitiesUpUtilityFn(hero)
	local bDebugLines = false
	local bDebugEchos = false
	
	local val = 0
	
	if skills.abilHammerThrow:CanActivate() then
		val = val + object.nHammerThrowUp
	end
	
	if skills.abilBruteStrength:CanActivate() then
		val = val + object.nBruteStrengthUp
	end
	
	if bDebugEchos then BotEcho(" HARASS - abilitiesUp: "..val) end
	if bDebugLines then
		local lineLen = 150
		local myPos = core.unitSelf:GetPosition()
		local vTowards = Vector3.Normalize(hero:GetPosition() - myPos)
		local vOrtho = Vector3.Create(-vTowards.y, vTowards.x) --quick 90 rotate z
		core.DrawDebugArrow(myPos - vOrtho * lineLen * 1.4, (myPos - vOrtho * lineLen * 1.4 ) + vTowards * val * (lineLen/100), 'cyan')
	end
	
	return val
end

local function BruteStrengthActiveUtility()
	local nUtility = 0
	if object.nBruteStrengthExpireTime > HoN.GetGameTime() then
		nUtility = object.nBruteStrengthActive
	end
		
	return nUtility
end


--Hammerstorm ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local bDebugEchos = false
	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
		if bDebugEchos then BotEcho("  ABILILTY EVENT!  InflictorName: "..EventData.InflictorName) end
		if EventData.InflictorName == "Ability_Hammerstorm1" then
			nAddBonus = nAddBonus + object.nHammerThrowUse
		end		
	elseif EventData.Type == "State" or EventData.Type == "Buff" then
		if EventData.StateName == object.sGalvanizeStateName then
			if bDebugEchos then BotEcho(format("Galvanize applied for %d at %d", EventData.StateDuration, EventData.TimeStamp)) end
			object.nGalvanizeExpireTime = EventData.TimeStamp + EventData.StateDuration
		elseif EventData.StateName == object.sBruteStrengthStateName then
			if bDebugEchos then BotEcho(format("Brute Strength applied for %d at %d", EventData.StateDuration, EventData.TimeStamp)) end
			object.nBruteStrengthExpireTime = EventData.TimeStamp + EventData.StateDuration
		end
	elseif EventData.Type == "Item" then
		--eventsLib.printCombatEvent(EventData)
		if core.itemPortalKey ~= nil and EventData.InflictorName == core.itemPortalKey:GetName() then
			nAddBonus = nAddBonus + self.nPortalKeyUse
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
local function CustomHarassUtilityOverride(hero)
	local nUtility = AbilitiesUpUtilityFn(hero) + BruteStrengthActiveUtility()
	
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride   

----------------------------------
--	Hammer harass actions
----------------------------------

local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = false
	
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
		return false --can not execute, move on to the next behavior
	end
	
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
	nAttackRangeSq = nAttackRangeSq * nAttackRangeSq
	local nMyExtraRange = core.GetExtraRange(unitSelf)
	
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetExtraRange = core.GetExtraRange(unitTarget)
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200
	
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)	
	
	if bDebugEchos then BotEcho("Hammerstorm HarassHero at "..nLastHarassUtility) end
	local bActionTaken = false
	local bMoveIn = false
	
	--portalkey
	if not bActionTaken then
		local itemPortalKey = core.itemPortalKey
		if itemPortalKey then
			local nPortalKeyRange = itemPortalKey:GetRange()
			local nHammerRange = skills.abilHammerThrow:GetRange()
			if itemPortalKey:CanActivate() and behaviorLib.lastHarassUtil > object.nPortalKeyThreshold then
				if nTargetDistanceSq > (nHammerRange * nHammerRange) and nTargetDistanceSq < (nPortalKeyRange*nPortalKeyRange + nHammerRange*nHammerRange) then
					vecCenter = core.GetGroupCenter(core.localUnits["EnemyHeroes"])
					if vecCenter then
						bActionTaken = core.OrderItemPosition(botBrain, unitSelf, itemPortalKey, vecCenter)
					end
				end
			end
		end
	end
	
	--hammer throw
	local nHammerThrowAoERadius = 300
	if not bActionTaken and bCanSee and not bTargetRooted and nLastHarassUtility > botBrain.nHammerThrowThreshold then
		if bDebugEchos then BotEcho("  No action yet, checking hammer throw") end
		local abilHammerThrow = skills.abilHammerThrow
		if abilHammerThrow:CanActivate() then
			local nRange = abilHammerThrow:GetRange()
			if nTargetDistanceSq < (nRange * nRange) then
				local unitBestTarget = funcBestTargetStun(core.localUnits["EnemyHeroes"], unitTarget, nHammerThrowAoERadius)
				bActionTaken = core.OrderAbilityEntity(botBrain, abilHammerThrow, unitBestTarget)
			else
				bMoveIn = true
			end
		end
	end
	
	--brute strength
	if not bActionTaken then
		if bDebugEchos then BotEcho("  No action yet, checking brute strength") end
		local abilBruteStrength = skills.abilBruteStrength
		--activate when just out of melee range of target
		if abilBruteStrength:CanActivate() and nTargetDistanceSq < nAttackRangeSq * (1.25 * 1.25) then
			bActionTaken = core.OrderAbility(botBrain, abilBruteStrength)
		end
	end

	--galvanize
	if not bActionTaken and (bMoveIn or nLastHarassUtility > botBrain.nGalvanizeThreshold) then
		if bDebugEchos then BotEcho("  No action yet, checking galvanize") end
		local abilGalvanize = skills.abilGalvanize
		if abilGalvanize:CanActivate() then
			bActionTaken = core.OrderAbility(botBrain, abilGalvanize)
		end
	end
	
	if not bActionTaken then
		if bDebugEchos then BotEcho("  No action yet, proceeding with normal harass execute.") end
		return object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride


----------------------------------
--	Hammerstorm specific push
----------------------------------

object.nMightySwingPushWeight = 0.6

--hammer's splash is {15,30,45,60}% in {175,200,225,250} radius
local function MightySwingPushUtility()
	local abilMightySwing = skills.abilMightySwing
	local nLevel = abilMightySwing:GetLevel()
	
	local m = 25 --(100/4)
	
	local nUtility = m * nLevel
	
	return nUtility	
end

local function PushingStrengthUtilityOverride(myHero)
	local nUtility = object.funcPushUtilityOld(myHero)
	
	local nMightySwingUtility = MightySwingPushUtility() * object.nMightySwingPushWeight
	
	nUtility = nUtility + nMightySwingUtility
	nUtility = Clamp(nUtility, 0, 100)

	return nUtility
end
object.funcPushUtilityOld = behaviorLib.PushingStrengthUtility
behaviorLib.PushingStrengthUtility = PushingStrengthUtilityOverride

-----------------------
-- Return to well
-----------------------
--this is a great function to override with using retreating skills, such as blinks, travels, stuns or slows.
function behaviorLib.CustomReturnToWellExecute(botBrain)
	return core.OrderBlinkItemToEscape(botBrain, core.unitSelf, core.itemPortalKey, true)
end

----------------------------------
--	Hammerstorm items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
behaviorLib.StartingItems = {"Item_CrushingClaws", "Item_MarkOfTheNovice", "2 Item_RunesOfTheBlight", "2 Item_ManaPotion"}
behaviorLib.LaneItems = {"Item_BloodChalice", "Item_Marchers", "Item_Strength5", "Item_Steamboots"} --Item_Strength5 is Fortified Bracelet
behaviorLib.MidItems = {"Item_PortalKey", "Item_Insanitarius", "Item_Immunity", "Item_Critical1 4"} --Immunity is Shrunken Head, Item_Critical1 is Riftshards
behaviorLib.LateItems = {"Item_Warpcleft", "Item_SolsBulwark", "Item_DaemonicBreastplate", "Item_BehemothsHeart", "Item_Damage9"} --Item_Damage9 is doombringer



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

BotEcho('finished loading hammerstorm_main')

