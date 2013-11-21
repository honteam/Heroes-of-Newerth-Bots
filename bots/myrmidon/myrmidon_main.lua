---------------------------------------------------
-- ___  ___                    ______       _    --
-- |  \/  |                    | ___ \     | |   --
-- | .  . |_   _ _ __ _ __ ___ | |_/ / ___ | |_  --
-- | |\/| | | | | '__| '_ ` _ \| ___ \/ _ \| __| --
-- | |  | | |_| | |  | | | | | | |_/ / (_) | |_  --
-- \_|  |_/\__, |_|  |_| |_| |_\____/ \___/ \__| --
--          __/ |                                --
--         |___/                                 --
---------------------------------------------------
--          A HoN Community Bot Project          --
---------------------------------------------------
--                  Created by:                  --
--       DarkFire       VHD       Kairus101      --
---------------------------------------------------

--BUG: Myrm stalled out - no movement, sitting in lane safe away from any units.  Yellow arrow to jungle camps still toggling.  Courier was dead...
--		Perhaps trying to buy on non-existant courier??

-- NOTE: bCanSeeTarget in HarassHeroExecute only needs to be checked if we are using OrderAbilityEntity or OrderItemEntity
-- Note2: I reverted the Steamboots change because the well provides 4% of your max mana/health per second so switching to agi has no effect

--Proposed TO-DO list
--	Items:
--		Refine item choices
--  		Need to decide on gank/support/tank/nuke build (or variable build?)
--			I propose adding Lex Talionis after red boots and chalice. Provides magic armor and nice damage amp to burst skills
--			Consider adding grimoire/lightbrand for boosted magic dmg?  Maybe insanitarious for stronger attacks in ult form?
--			Add BKB for late game so we can fight in ult form up close without getting stunned/nuked?
--		Chalice, use whenever we have > 80%(?) hp but < 60%(?) mana.

--  Retreat behavior
--		Ult if about to die (for +hp)
--		Waveform away (pick node nearest max range wave away from threat).
--			Can we detect incoming damage sources before they hit (MOA nuke, hammer stun, ellonia ult) and wave away?
--		Weed/carp to slow down pursuer?

--  Harass behavior
--		Weed:
--			Test/refine target's location prediction?  Currently using Stolen's RA meteor code, but only tracks current target...
--			If carp active, track target and carp locations.  Estimate intercept and cast weed field so that it triggers at time/location of carp intercept?
--			If target is stunned/slowed/snared/etc, boost aggression on weed?  Easy to land if target not moving!
--		Carp:
--			Cast on targets out of attack range that have HP pot on
--			Set up thresholds/sequence to cast before weed when possible (allow setup synergy for better chance of landing weed field)
--		Wave:
--			For far off targets with low hp, use to close distance in order to get nukes off?
--			For close targets, use in a way to pass through enemy target (to slow target)
--		Ult:
--			Turn on when target is slow/immobalized and we are in close/melee range?


------------------------------------------
--          Bot Initialization          --
------------------------------------------

local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic = true
object.bRunBehaviors = true
object.bUpdates = true
object.bUseShop = true

object.bRunCommands = true
object.bMoveCommands = true
object.bAttackCommands = true
object.bAbilityCommands = true
object.bOtherCommands = true

object.bReportBehavior = false
object.bDebugUtility = false
object.bDebugExecute = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core = {}
object.eventsLib = {}
object.metadata = {}
object.behaviorLib = {}
object.skills = {}

runfile "bots/core.lua"
runfile "bots/botbraincore.lua"
runfile "bots/eventsLib.lua"
runfile "bots/metadata.lua"
runfile "bots/behaviorLib.lua"

runfile "bots/jungleLib.lua"
local jungleLib = object.jungleLib

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

local sqrtTwo = math.sqrt(2)

BotEcho('loading myrmidon_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 3, ShortSolo = 3, LongSolo = 2, ShortSupport = 5, LongSupport = 5, ShortCarry = 2, LongCarry = 2}

---------------------------------
--          Constants          --
---------------------------------

-- Myrmidon
object.heroName = 'Hero_Hydromancer'

-- Item buy order. internal names
behaviorLib.StartingItems =
	{"Item_RunesOfTheBlight", "2 Item_MinorTotem", "Item_ManaBattery", "Item_HealthPotion"}
behaviorLib.LaneItems =
	{"Item_Steamboots", "Item_BloodChalice", "Item_Gloves3"} 
	--chalice on a bot will be crazy. Just time it before each kill, as you would a taunt.
	--Gloves3 is alchemists bones, faster attack speed + extra gold from jungle creeps. May as well impliment it as the first of it's type.
behaviorLib.MidItems =
	{"Item_Shield2", "Item_DaemonicBreastplate"} 
	--shield2 is HotBL. This should be changed to shamans if a high ratio of recieved damage is magic. (is this possible.)
	--I'm using a guide to set up these items, so, demonic.... maybe not.
behaviorLib.LateItems =
	{"Item_SpellShards 3", "Item_Lightning2", "Item_HarkonsBlade", "Item_BehemothsHeart"}
	--spellshards, because damage is important.
	--"Lightning2 is charged hammer. More attack speed, right?
	--harkons, solid all round.
	--heart, because we need tankyness now.

-- Skillbuild. 0 is Weed Field, 1 is Magic Carp, 2 is Wave Form, 3 is Forced Evolution, 4 is Attributes
object.tSkills = {
	0, 2, 0, 1, 0,
	3, 0, 1, 1, 2,
	3, 1, 2, 2, 4,
	3, 4, 4, 4, 4,
	4, 4, 4, 4, 4
}

-- Bonus agression points if a skill/item is available for use
object.nWeedFieldUp = 5
object.nMagicCarpUp = 3
object.nWaveFormUp = 2
object.nForcedEvolutionUp = 4

-- Bonus agression points that are applied to the bot upon successfully using a skill/item
object.nWeedFieldUse = 4
object.nMagicCarpUse = 4
object.nWaveFormUse = 2
object.nForcedEvolutionUse = 20

-- Thresholds of aggression the bot must reach to use these abilities
object.nWeedFieldThreshold = 45
object.nMagicCarpThreshold = 0 -- 0??
object.nWaveFormThreshold = 70 -- was 100
object.nWaveFormRetreatThreshold = 50
object.nForcedEvolutionThreshold = 60

-- Other variables
object.nOldRetreatFactor = 0.9--Decrease the value of the normal retreat behavior
object.nMaxLevelDifference = 4--Ensure hero will not be too carefull
object.nEnemyBaseThreat = 6--Base threat. Level differences and distance alter the actual threat level.

------------------------------
--          Skills          --
------------------------------

function object:SkillBuild()
	core.VerboseLog("SkillBuild()")

	local unitSelf = self.core.unitSelf
	if  skills.abilWeedField == nil then
		skills.abilWeedField = unitSelf:GetAbility(0)
		skills.abilMagicCarp = unitSelf:GetAbility(1)
		skills.abilWaveForm = unitSelf:GetAbility(2)
		skills.abilForcedEvolution = unitSelf:GetAbility(3)
		skills.abilAttributeBoost = unitSelf:GetAbility(4)
	end

	local nPoints = unitSelf:GetAbilityPointsAvailable()
	if nPoints <= 0 then
		return
	end

	local nLevel = unitSelf:GetLevel()
	for i = nLevel, (nLevel + nPoints) do
		unitSelf:GetAbility( self.tSkills[i] ):LevelUp()
	end
end

------------------------------------------
--          FindItems Override          --
------------------------------------------

local function funcFindItemsOverride(botBrain)
	local bUpdated = object.FindItemsOld(botBrain)

	core.ValidateItem(core.itemSteamboots)
	
	if bUpdated then
		if core.itemSteamboots and core.itemBloodChalice and core.itemAlchBones then
			return
		end

		local inventory = core.unitSelf:GetInventory(false)
		for slot = 1, 6 do
			local curItem = inventory[slot]
			if curItem then
				if core.itemSteamboots == nil and curItem:GetName() == "Item_Steamboots" then
					core.itemSteamboots = core.WrapInTable(curItem)
				end
			end
		end
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride

----------------------------------------
--          OnThink Override          --
----------------------------------------

local bTrackingCarp=false
local uCarpTarget

function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)
	jungleLib.assess(self)
	local bDebugGadgets=false
	local unitSelf=core.unitSelf
	
	if (bDebugGadgets or bTrackingCarp) then
		local tUnits = HoN.GetUnitsInRadius(unitSelf:GetPosition(), 500, core.UNIT_MASK_ALIVE + core.UNIT_MASK_GADGET)
		if tUnits then
			for _, unit in pairs(tUnits) do
				-- CARP
				--Carp speed is 600.
				--Carp gadget is "Gadget_Hydromancer_Ability2_Reveal", and it is at the position of the carp itself.
				if (bTrackingCarp and unit:GetTypeName()=="Gadget_Hydromancer_Ability2_Reveal") then--carp is alive
					if (uCarpTarget and uCarpTarget:GetPosition()) then
						--BotEcho("Time till carp hit: "..Vector3.Distance2DSq(unit:GetPosition(),uCarpTarget:GetPosition() )/(600*600))
					end
				end
				
				if (bTrackingCarp and unit:GetTypeName()=="Gadget_Hydromancer_Ability2_Reveal_Linger") then -- carp is now dead
					bTrackingCarp=false
				end
				
				if (bDebugGadgets) then
					core.DrawDebugArrow(unitSelf:GetPosition(), unit:GetPosition(), 'yellow') --flint q/r, fairy port, antipull, homecoming, kongor, chronos ult
					BotEcho(unit:GetTypeName())
				end
			end
		end
	end

	-- Toggle Steamboots for more Health/Mana
	--TODO: Change this to core.GetItem when available.
	local itemSteamboots = core.itemSteamboots
	if itemSteamboots and itemSteamboots:CanActivate() then
		local unitSelf = core.unitSelf
		local sKey = itemSteamboots:GetActiveModifierKey()
		local sCurrentBehavior = core.GetCurrentBehaviorName(self)
		if sKey == "str" then
			-- Toggle away from STR if health is high enough
			if unitSelf:GetHealthPercent() > .65 or sCurrentBehavior == "UseHealthRegen" or sCurrentBehavior == "UseManaRegen" then
				self:OrderItem(itemSteamboots.object, false)
			end
		elseif sKey == "agi" then
			-- Toggle away from AGI when we're not using Regen items or at well
			if sCurrentBehavior ~= "UseHealthRegen" and sCurrentBehavior ~= "UseManaRegen" and not unitSelf:HasState("State_RunesOfTheBlight") and not unitSelf:HasState("State_HealthPotion") then
				self:OrderItem(itemSteamboots.object, false)
			end
		elseif sKey == "int" then
			-- Toggle away from INT if health gets too low
			if unitSelf:GetHealthPercent() < .45 or sCurrentBehavior == "UseHealthRegen" or sCurrentBehavior == "UseManaRegen" then
				self:OrderItem(itemSteamboots.object, false)
			end
		end
	end
end

object.onthinkOld = object.onthink
object.onthink = object.onthinkOverride

----------------------------------------------
--          OnCombatEvent Override          --
----------------------------------------------

function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)

	local nAddBonus = 0

	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_Myrmidon1" then
			nAddBonus = nAddBonus + object.nWeedFieldUse
		elseif EventData.InflictorName == "Ability_Myrmidon2" then
			nAddBonus = nAddBonus + object.nMagicCarpUse
		elseif EventData.InflictorName == "Ability_Myrmidon3" then
			nAddBonus = nAddBonus + object.nWaveFormUse
		elseif EventData.InflictorName == "Ability_Myrmidon4" then
			nAddBonus = nAddBonus + object.nForcedEvolutionUse
		end
	end

	if nAddBonus > 0 then
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
end

object.oncombateventOld = object.oncombatevent
object.oncombatevent = object.oncombateventOverride

----------------------------------------------------
--          CustomHarassUtility Override          --
----------------------------------------------------

local function CustomHarassUtilityFnOverride(hero)
	local nUtility = 0
	
	if skills.abilWeedField:CanActivate() then
		nUtility = nUtility + object.nWeedFieldUp
	end
	
	if skills.abilMagicCarp:CanActivate() then
		nUtility = nUtility + object.nMagicCarpUp
	end
	
	if skills.abilWaveForm:CanActivate() then
		nUtility = nUtility + object.nWaveFormUp
	end
	
	if skills.abilForcedEvolution:CanActivate() then
		nUtility = nUtility + object.nForcedEvolutionUp
	end
	
	return nUtility
end

behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride

----------------------------------------
--          Weed Field Logic          --
----------------------------------------

-- A fixed list seems to be better then to check on each cycle if its  exist
-- so we create it here
local tRelativeMovements = {}
local function createRelativeMovementTable(key)
	--BotEcho('Created a relative movement table for: '..key)
	tRelativeMovements[key] = {
		vLastPos = Vector3.Create(),
		vRelMov = Vector3.Create(),
		timestamp = 0
	}
--	BotEcho('Created a relative movement table for: '..tRelativeMovements[key].timestamp)
end

createRelativeMovementTable("MyrmField") -- for landing Weed Field

-- tracks movement for targets based on a list, so its reusable
-- key is the identifier for different uses (fe. RaMeteor for his path of destruction)
-- vTargetPos should be passed the targets position of the moment
-- to use this for prediction add the vector to a units position and multiply it
-- the function checks for 100ms cycles so one second should be multiplied by 20
local function relativeMovement(sKey, vTargetPos)
	local debugEchoes = false
	
	local gameTime = HoN.GetGameTime()
	local key = sKey
	local vLastPos = tRelativeMovements[key].vLastPos
	local nTS = tRelativeMovements[key].timestamp
	local timeDiff = gameTime - nTS 
	
	if debugEchoes then
		BotEcho('Updating relative movement for key: '..key)
		BotEcho('Relative Movement position: '..vTargetPos.x..' | '..vTargetPos.y..' at timestamp: '..nTS)
		BotEcho('Relative lastPosition is this: '..vLastPos.x)
	end
	
	if timeDiff >= 90 and timeDiff <= 140 then -- 100 should be enough (every second cycle)
		local relativeMov = vTargetPos-vLastPos
		
		if vTargetPos.LengthSq > vLastPos.LengthSq
		then relativeMov =  relativeMov*-1 end
		
		tRelativeMovements[key].vRelMov = relativeMov
		tRelativeMovements[key].vLastPos = vTargetPos
		tRelativeMovements[key].timestamp = gameTime
		
		
		if debugEchoes then
			BotEcho('Relative movement -- x: '..relativeMov.x..' y: '..relativeMov.y)
			BotEcho('^r---------------Return new-'..tRelativeMovements[key].vRelMov.x)
		end
		
		return relativeMov
	elseif timeDiff >= 150 then
		tRelativeMovements[key].vRelMov =  Vector3.Create(0,0)
		tRelativeMovements[key].vLastPos = vTargetPos
		tRelativeMovements[key].timestamp = gameTime
	end
	
	if debugEchoes then BotEcho('^g---------------Return old-'..tRelativeMovements[key].vRelMov.x) end
	return tRelativeMovements[key].vRelMov
end

---------------------------------------
--          Harass Behavior          --
---------------------------------------

local function HarassHeroExecuteOverride(botBrain)
	
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil then
		return object.harassExecuteOld(botBrain)
	end

	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local bCanSeeTarget = core.CanSeeUnit(botBrain, unitTarget)
	
	local nWeedFieldDelay = 1100 -- nCastTime = 1000 --can we extract this from ability/affector? casttime="500" and castactiontime="100" and impactdelay="1000"
	local vecRelativeMov = relativeMovement("MyrmField", vecTargetPosition) * (nWeedFieldDelay / 100) --updating every 100ms

	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bActionTaken = false
	
	--Weed Field
	--Currently trying to use Stolen's Ra prediction code.  Consider reworking and track all old hero positions?
	if not bActionTaken then
		local bDebugEchoes = false
		local abilWeedField = skills.abilWeedField
		if abilWeedField:CanActivate() and nLastHarassUtility > object.nWeedFieldThreshold then
			local nRange = abilWeedField:GetRange()
			local vecTargetPredictPosition = vecTargetPosition + vecRelativeMov
			if Vector3.Distance2DSq(vecMyPosition, vecTargetPredictPosition) < nRange * nRange then
				local nCarpMovespeedSq = 600 * 600
				if not bTrackingCarp then
					bActionTaken = core.OrderAbilityPosition(botBrain, skills.abilWeedField, vecTargetPredictPosition)
					if bDebugEchoes then BotEcho("Casting weed field!") end
				-- If carp homing on target, wait till it gets close?
				elseif ((nWeedFieldDelay * nWeedFieldDelay) / (1000 * 1000)) < (Vector3.Distance2DSq(uCarpTarget:GetPosition(), vecTargetPredictPosition) / nCarpMovespeedSq) then --perfect time to cast weed field!
					bActionTaken = core.OrderAbilityPosition(botBrain, skills.abilWeedField, vecTargetPredictPosition)
				end
			end
		end
		
		if bDebugEchoes then
			local nRange = abilWeedField:GetRange()
			core.DrawXPosition(vecTargetPosition + vecRelativeMov, 'red', 100) --vecTargetPredictPosition
			core.DrawDebugArrow(vecTargetPosition, vecTargetPosition + vecRelativeMov, 'red') --predicted target movement path
			core.DrawDebugArrow(vecMyPosition, vecMyPosition + (Vector3.Normalize((vecTargetPosition + vecRelativeMov) - vecMyPosition)) * nRange, 'green') --weed field range aimed at predicted position
		end
	end

	--Magic Carp
	if not bActionTaken then
		local abilMagicCarp = skills.abilMagicCarp
		if abilMagicCarp:CanActivate() and bCanSeeTarget and nLastHarassUtility > object.nMagicCarpThreshold then
			local nRange = abilMagicCarp:GetRange()
			if nTargetDistanceSq < (nRange * nRange) then
				bActionTaken = core.OrderAbilityEntity(botBrain, skills.abilMagicCarp, unitTarget)
				if bActionTaken then
					uCarpTarget = unitTarget
					bTrackingCarp = true
				end
			end
		end
	end
	
	--Wave Form
	if not bActionTaken then
		local bDebugEchoes = true
		local abilWaveForm = skills.abilWaveForm
		if abilWaveForm:CanActivate() and nLastHarassUtility > object.nWaveFormThreshold then
			local nRange = abilWaveForm:GetRange()
			local nWaveOvershoot = 128 --try to get this many units past target to guarantee slow and position nicely to ult or block
			local vecWaveFormTarget = vecTargetPosition + nWaveOvershoot * Vector3.Normalize(vecTargetPosition - vecMyPosition)
			if Vector3.Distance2DSq(vecMyPosition, vecWaveFormTarget) < (nRange * nRange) then
				bActionTaken = core.OrderAbilityPosition(botBrain, skills.abilWaveForm, vecWaveFormTarget)
			else
				bActionTaken = core.OrderAbilityPosition(botBrain, skills.abilWaveForm, vecTargetPosition)
			end
		end
	
		if bDebugEchoes then
			local nRange = abilWaveForm:GetRange()
			local nWaveOvershoot = 128
			local vecWaveFormTarget = vecTargetPosition + nWaveOvershoot * Vector3.Normalize(vecTargetPosition - vecMyPosition)
			if Vector3.Distance2DSq(vecMyPosition, vecWaveFormTarget) < (nRange * nRange) then
				core.DrawXPosition(vecWaveFormTarget, 'blue', 100)
			else 
				core.DrawXPosition(vecMyPosition + Vector3.Normalize(vecTargetPosition - vecMyPosition) * nRange, 'blue', 100)
			end
		end
	end
	
	--ForcedEvolution
	--Need to check that target is not magic immune or our melee attack will not be effective?
	if not bActionTaken and bCanSeeTarget then
		local abilForcedEvolution = skills.abilForcedEvolution
		if abilForcedEvolution:CanActivate() and nLastHarassUtility > object.nForcedEvolutionThreshold and nTargetDistanceSq < (200 * 200) then
			bActionTaken = core.OrderAbility(botBrain, skills.abilForcedEvolution)
		end
	end
	
	if not bActionTaken then
		bActionTaken = object.harassExecuteOld(botBrain)
	end

	return bActionTaken
end

object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

local function positionOffset(pos, angle, distance) --this is used by minions to form a ring around people.
		tmp = Vector3.Create(cos(angle) * distance, sin(angle) * distance)
		return tmp + pos
end
local function waveFormToBase(botBrain)
	local vecWellPos = core.allyWell and core.allyWell:GetPosition() or behaviorLib.PositionSelfBackUp()
	local vecMyPos=core.unitSelf:GetPosition()
	if (Vector3.Distance2DSq(vecMyPos, vecWellPos)>600*600)then
		if (skills.abilWaveForm:CanActivate()) then --waveform
			return core.OrderAbilityPosition(botBrain, skills.abilWaveForm, positionOffset(core.unitSelf:GetPosition(), atan2(vecWellPos.y-vecMyPos.y,vecWellPos.x-vecMyPos.x), skills.abilWaveForm:GetRange()))
		end
	end
	return false
end

------------------------------------------------------------------
--Retreat execute
------------------------------------------------------------------
--  this is a great function to override with using retreating skills, such as blinks, travels, stuns or slows.
function behaviorLib.CustomRetreatExecute(botBrain)
	local unitSelf = core.unitSelf
	local unitTarget = behaviorLib.heroTarget
	local bActionTaken = false
	
	--Counting the enemies 	
	local tEnemies = core.localUnits["EnemyHeroes"]
	local nCount = 0
	local bCanSeeUnit = unitTarget and core.CanSeeUnit(botBrain, unitTarget) 
	for id, unitEnemy in pairs(tEnemies) do
		if core.CanSeeUnit(botBrain, unitEnemy) then
			nCount = nCount + 1
		end
	end
	if (nCount > 1 or unitSelf:GetHealthPercent() < .4) and bCanSeeUnit then -- More enemies or low on life
		local vecMyPosition = unitSelf:GetPosition()
		local vecTargetPosition = unitTarget:GetPosition()
		local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
		local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized()
	
		--WeedField
		local abilWeedField = skills.abilWeedField
		if abilWeedField:CanActivate() then
			local nRange = abilWeedField:GetRange()
			if nTargetDistanceSq < (nRange * nRange) then
				bActionTaken = core.OrderAbilityPosition(botBrain, abilWeedField, vecTargetPosition)
			end
		end
		
		--wave form
		if (not bActionTaken and behaviorLib.lastRetreatUtil> object.nWaveFormRetreatThreshold) then
			bActionTaken = waveFormToBase(botBrain)
		end
		
	end
	return bActionTaken
end

--------------------------------------------------
--             HealAtWell Override              --
--------------------------------------------------

--return to well more often. --2000 gold adds 8 to return utility, 0% mana also adds 8.
--When returning to well, use skills and items.
local function HealAtWellUtilityOverride(botBrain)
	return object.HealAtWellUtilityOld(botBrain)*1.75+(botBrain:GetGold()*8/2000)+ 8-(core.unitSelf:GetManaPercent()*8) --courageously flee back to base.
end

local function HealAtWellExecuteOverride(botBrain)
	return waveFormToBase(botBrain) or object.HealAtWellExecuteOld(botBrain)
end

object.HealAtWellUtilityOld = behaviorLib.HealAtWellBehavior["Utility"]
behaviorLib.HealAtWellBehavior["Utility"] = HealAtWellUtilityOverride
object.HealAtWellExecuteOld = behaviorLib.HealAtWellBehavior["Execute"]
behaviorLib.HealAtWellBehavior["Execute"] = HealAtWellExecuteOverride

--------------------------------------------
--          PushExecute Override          --
--------------------------------------------

-- Filters a group to be within a given range. Modified from St0l3n_ID's Chronos bot
local function filterGroupRange(tGroup, vecCenter, nRange)
	if tGroup and vecCenter and nRange then
		local tResult = {}
		for _, unitTarget in pairs(tGroup) do
			if Vector3.Distance2DSq(unitTarget:GetPosition(), vecCenter) <= (nRange * nRange) then
				tinsert(tResult, unitTarget)
			end
		end	

		if #tResult > 0 then
			return tResult
		end
	end

	return nil
end

-- Find the angle in degrees between two targets. Modified from St0l3n_ID's AngToTarget code
local function getAngToTarget(vecSelf, vecTarget)
	local nDeltaY = vecTarget.y - vecSelf.y
	local nDeltaX = vecTarget.x - vecSelf.x

	return floor( atan2(nDeltaY, nDeltaX) * 57.2957795131) -- That number is 180 / pi
end

local function getBestWeedFieldCastDirection(tLocalUnits, nMinimumCount)
	if nMinimumCount == nil then
		nMinimumCount = 1
	end
	
	if tLocalUnits and core.NumberElements(tLocalUnits) >= nMinimumCount then
		local unitSelf = core.unitSelf
		local vecMyPosition = unitSelf:GetPosition()
		local tTargetsInRange = filterGroupRange(tLocalTargets, vecMyPosition, 1000)
		if tTargetsInRange and #tTargetsInRange >= nMinimumCount then
			local tAngleOfTargetsInRange = {}
			for _, unitTarget in pairs(tTargetsInRange) do
				local vecEnemyPosition = unitTarget:GetPosition()
				local vecDirection = Vector3.Normalize(vecEnemyPosition - vecMyPosition)
				vecDirection = core.RotateVec2DRad(vecDirection, pi / 2)

				local nHighAngle = getAngToTarget(vecMyPosition, vecEnemyPosition + vecDirection * 50)
				local nMidAngle = getAngToTarget(vecMyPosition, vecEnemyPosition)
				local nLowAngle = getAngToTarget(vecMyPosition, vecEnemyPosition - vecDirection * 50)

				tinsert(tAngleOfTargetsInRange, {nHighAngle, nMidAngle, nLowAngle})
			end
		
			local tBestGroup = {}
			local tCurrentGroup = {}
			for _, tStartAngles in pairs(tAngleOfTargetsInRange) do
				local nStartAngle = tStartAngles[2]
				if nStartAngle <= -90 then
					-- Avoid doing calculations near the break in numbers
					nStartAngle = nStartAngle + 360
				end

				for _, tAngles in pairs(tAngleOfTargetsInRange) do
					local nHighAngle = tAngles[1]
					local nMidAngle = tAngles[2]
					local nLowAngle = tAngles[3]
					if nStartAngle > 90 and nStartAngle <= 270 then
						if nHighAngle < 0 then
							nHighAngle = nHighAngle + 360
						end
						
						if nMidAngle < 0 then
							nMidAngle = nMidAngle + 360
						end
							
						if nLowAngle < 0 then
							nLowAngle = nLowAngle + 360
						end
					end


					if nHighAngle >= nStartAngle and nStartAngle >= nLowAngle then
						tinsert(tCurrentGroup, nMidAngle)
					end
				end

				if #tCurrentGroup > #tBestGroup then
					tBestGroup = tCurrentGroup
				end

				tCurrentGroup = {}
			end
		
			local nBestGroupSize = #tBestGroup
			
			if nBestGroupSize >= nMinimumCount then
				tsort(tBestGroup)

				local nAvgAngle = (tBestGroup[1] + tBestGroup[nBestGroupSize]) / 2 * 0.01745329251 -- That number is pi / 180

				return Vector3.Create(cos(nAvgAngle), sin(nAvgAngle)) * 500
			end
		end
	end
	
	return nil
end

--TODO Change these to the new pushing when they are out
local function AbilityPush(botBrain)
	local bSuccess = false
	local abilWeedField = skills.abilWeedField
	local unitSelf = core.unitSelf
	local nMinimumCreeps = 3

	-- Stop the bot from trying to farm creeps if the creeps approach the spot where the bot died
	if not unitSelf:IsAlive() then
		return bSuccess
	end

	if abilWeedField:CanActivate() and unitSelf:GetManaPercent() > .4 then
		local vecCastDirection = getBestWeedFieldCastDirection(core.localUnits["EnemyCreeps"], 3)
		if vecCastDirection then 
			bSuccess = core.OrderAbilityPosition(botBrain, abilWeedField, unitSelf:GetPosition() + vecCastDirection)
		end
	end

	return bSuccess
end

local function PushExecuteOverride(botBrain)
	if not AbilityPush(botBrain) then 
		return object.PushExecuteOld(botBrain)
	end
end

object.PushExecuteOld = behaviorLib.PushBehavior["Execute"]
behaviorLib.PushBehavior["Execute"] = PushExecuteOverride

local function TeamGroupBehaviorOverride(botBrain)
	if not AbilityPush(botBrain) then 
		return object.TeamGroupBehaviorOld(botBrain)
	end
end

object.TeamGroupBehaviorOld = behaviorLib.TeamGroupBehavior["Execute"]
behaviorLib.TeamGroupBehavior["Execute"] = TeamGroupBehaviorOverride


BotEcho(object:GetName()..' finished loading myrmidon_main')