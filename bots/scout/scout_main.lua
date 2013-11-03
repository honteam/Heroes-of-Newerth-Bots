--Created by SPENNERINO
--CodexScoutBot v0.3

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

BotEcho('loading scout_main...')

object.heroName = 'Hero_Scout'

--------------------------------
-- Skills
--------------------------------
function object:SkillBuild()
	core.VerboseLog("SkillBuild()")

	local unitSelf = self.core.unitSelf	
	
	if  skills.abilVanish == nil then
		skills.abilVanish			= unitSelf:GetAbility(0)
		skills.abilElectricEye		= unitSelf:GetAbility(1)
		skills.abilDisarm			= unitSelf:GetAbility(2)
		skills.abilMarksmanShot		= unitSelf:GetAbility(3)
		skills.abilAttributeBoost	= unitSelf:GetAbility(4)
		skills.abilDetonate			= unitSelf:GetAbility(5)
		skills.abilTaunt			= unitSelf:GetAbility(8)
	end
	
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	object.tSkills = {
	    1, 0, 2, 0, 0,
	    3, 0, 2, 2, 2, 
	    3, 4, 4, 4, 4,
	    3, 4, 4, 4, 4,
	    4, 4, 1, 1, 1,
	}
	
	local nLev = unitSelf:GetLevel()
    local nLevPts = unitSelf:GetAbilityPointsAvailable()
    for i = nLev, nLev+nLevPts do
        unitSelf:GetAbility( object.tSkills[i] ):LevelUp()
    end
end

---------------------------------------------------
--                Local Functions                --
---------------------------------------------------

local vecEyePosition = nil
local bEyePlaced = false

local function GetElectricEyeRadius()
	return 450
end

local function IsVanished(unitSelf)
	if unitSelf:HasState("State_Scout_Ability1") or unitSelf:IsStealth() then
		return true
	else
		return false
	end
end

local function IsLowHealth()
	local nMaxHealth = core.unitSelf:GetMaxHealth()
	local nHealth = core.unitSelf:GetHealth()
	
	if nHealth < (nMaxHealth * 0.1) or nHealth < 150 then
		return true
	else
		return false
	end
end

local function IsLowMana()
	local nMaxMana = core.unitSelf:GetMaxMana()
	local nMana = core.unitSelf:GetMana()
	
	if nMana < (nMaxMana * 0.3) then
		return true
	else
		return false
	end
end

local function HasManaRegen()
	local nLevel = skills.abilVanish:GetLevel()
	local nManaRegen = core.unitSelf:GetManaRegen()
	local nManaUpkeep = 5
	if nLevel == 1 then
		nManaUpkeep = 2
	elseif nLevel == 2 then
		nManaUpkeep = 3
	elseif nLevel == 3 then
		nManaUpkeep = 4
	elseif nLevel == 4 then
		nManaUpkeep = 5
	end

	
	if (nManaRegen - nManaUpkeep) > 1 then
		return true
	else
		return false
	end
end

local function GetCanMarksmanShotKillTarget(unitTarget)
	local nLevel = skills.abilMarksmanShot:GetLevel()
	local nMaxHealth = unitTarget:GetMaxHealth()
	local nHealth = unitTarget:GetHealth()
	local nRegen = unitTarget:GetHealthRegen()
	local nTime = skills.abilMarksmanShot:GetChannelTime()
	nTime = (nTime + skills.abilMarksmanShot:GetCastTime() + 100) * 0.001
	nHealth = nHealth + (nRegen * nTime)
	
	local nDamage = 250
	if nLevel == 1 then
		nDamage = nDamage + (nMaxHealth * 0.1)
	elseif nLevel == 2 then
		nDamage = nDamage + (nMaxHealth * 0.2)
	elseif nLevel == 3 then
		nDamage = nDamage + (nMaxHealth * 0.3)
	end
	
	local nDamageMultiplier = 1 - unitTarget:GetMagicResistance()
	local nTrueDamage = nDamage * nDamageMultiplier

	if nTrueDamage > nHealth then
		return true
	else
		return false
	end
end

local function GetCanNukeKillTarget(unitTarget)
	local nLevel = core.itemNuke:GetLevel()
	local nMaxHealth = unitTarget:GetMaxHealth()
	local nHealth = unitTarget:GetHealth()
	
	local nDamage = 400
	if nLevel == 1 then
		nDamage = 400
	elseif nLevel == 2 then
		nDamage = 500
	elseif nLevel == 3 then
		nDamage = 600
	elseif nLevel == 4 then
		nDamage = 700
	elseif nLevel == 5 then
		nDamage = 800
	end
	
	local nDamageMultiplier = 1 - unitTarget:GetMagicResistance()
	local nTrueDamage = nDamage * nDamageMultiplier

	if nTrueDamage > nHealth then
		return true
	else
		return false
	end
end

---------------------------------------------------
--                   Overrides                   --
---------------------------------------------------

--[[for testing
function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)
	
	--behaviorLib.HarassHeroBehavior["Utility"](self)
	--behaviorLib.HarassHeroBehavior["Execute"](self)
	
	BotEcho("Harass: "..behaviorLib.lastHarassUtil)
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride
--]]


--melee weight overrides
behaviorLib.nCreepPushbackMul = 0.5
behaviorLib.nTargetPositioningMul = 0.6

----------------------------------
--	Scout' specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

object.nVanishUp =  5
object.nElectricEyeUp = 5
object.nDisarmUp = 0
object.nMarksmanShotUp = 10
object.nNukeUp = 30

object.nVanishUse = 5
object.nDisarmUse = 5
object.nElectricEyeUse = 0
object.nDetonateUse = 5
object.nMarksmanShotUse = 50
object.nNukeUse = 10

object.nVanishThreshold = 30
object.nElectricEyeThreshold = 40
object.nMarksmanShotThreshold = 60
object.nNukeThreshold = 40

local function AbilitiesUpUtility(hero)
	local bDebugLines = false
	local bDebugEchos = false
	
	local nUtility = 0
	local nBonusDown = 10
	
	if skills.abilDisarm:CanActivate() and not IsLowHealth()  then
		nUtility = nUtility + object.nDisarmUp
	end

	if skills.abilElectricEye:CanActivate() and not IsLowHealth()  then
		nUtility = nUtility + object.nElectricEyeUp
	end

	if skills.abilMarksmanShot:CanActivate() then
		nUtility = nUtility + object.nMarksmanShotUp
	end

	if core.itemNuke and core.itemNuke:CanActivate() then
		nUtility = nUtility + object.nNukeUp
	end
	
	if skills.abilVanish:CanActivate() and not IsLowHealth() then
		nUtility = nUtility + object.nVanishUp
	else
		nUtility = core.Clamp(nUtility - nBonusDown,0,100)
	end
	
	if IsLowHealth() then
		nUtility = core.Clamp(nUtility - nBonusDown,0,100)
	end
	
	if IsLowMana() then
		nUtility = core.Clamp(nUtility - nBonusDown,0,100)
	end
	
	if bDebugLines then
		local lineLen = 150
		local myPos = core.unitSelf:GetPosition()
		local vTowards = Vector3.Normalize(hero:GetPosition() - myPos)
		local vOrtho = Vector3.Create(-vTowards.y, vTowards.x) --quick 90 rotate z
		core.DrawDebugArrow(myPos - vOrtho * lineLen * 1.4, (myPos - vOrtho * lineLen * 1.4 ) + vTowards * nUtility * (lineLen/100), 'cyan')
	end
	
	return nUtility
end

--Scout ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local bDebugEchos = false
	local nAddBonus = 0
	
	if nAddBonus > 0 then
		--decay before we add
		if IsLowHealth() then
			nAddBonus = nAddBonus / 2
		end
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent 	= object.oncombateventOverride

--Utility calc override
local function CustomHarassUtilityFnOverride(hero)
	local nUtility = AbilitiesUpUtility(hero)
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride   

----------------------------------
--	Scout harass actions
----------------------------------
object.nElectricEyeCheckRangeBuffer = 200
local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = false
	
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil then
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
	
	local nLastHarassUtility = behaviorLib.lastHarassUtil	
	local bActionTaken = false
	
	--unitTarget property helpers
	local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200
	local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized()
	local bTargetSilenced = unitTarget:IsSilenced()
	local bTargetDisarmed = unitTarget:IsDisarmed()
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)

	--Ability and Item Pointers
	local abilVanish = skills.abilVanish
	local abilElectricEye = skills.abilElectricEye
	local abilDetonate = skills.abilDetonate
	local abilMarksmanShot = skills.abilMarksmanShot
	local abilTaunt = skills.abilTaunt
	
	core.FindItems()
	local itemNuke = core.itemNuke
	local itemHarkonsBlade = core.itemHarkonsBlade

	--Marksman Shot
	if not bActionTaken then
		local nRange = abilMarksmanShot:GetRange() + core.GetExtraRange(unitSelf) + core.GetExtraRange(unitTarget)
		
		if bCanSee then
			if nLastHarassUtility > botBrain.nMarksmanShotThreshold and itemNuke then
				if abilMarksmanShot:CanActivate() and nTargetDistanceSq < (nRange * nRange) 
				and nTargetDistanceSq > (abilMarksmanShot:GetRange() * .75) then
					if bDebugEchos then BotEcho("Casting Marksman Shot") end
					bActionTaken = core.OrderAbilityEntity(botBrain, abilMarksmanShot, unitTarget)
				end
			elseif GetCanMarksmanShotKillTarget(unitTarget) 
			and not itemNuke and nTargetDistanceSq > (abilMarksmanShot:GetRange() * .5) then 
				if abilMarksmanShot:CanActivate() and nTargetDistanceSq < (nRange * nRange) then
					if abilTaunt:CanActivate() then
						--if bDebugEchos then BotEcho("Taunt Tha Fool!!!") end
						bActionTaken = core.OrderAbilityEntity(botBrain, abilTaunt, unitTarget)
						BotEcho("Taunting like a boss")
					else
						if bDebugEchos then BotEcho("Killing with Marksman Shot") end
						bActionTaken = core.OrderAbilityEntity(botBrain, abilMarksmanShot, unitTarget)
						BotEcho("KSin like a boss")
					end
				end
			end	
		end
	end
		
	--since we are using an old pointer, ensure we can still see the target for entity targeting
	if bCanSee then
		
		--Codex
		if not bActionTaken and not bTargetVuln then 
			if itemNuke then
				local nRange = itemNuke:GetRange()
				if itemNuke:CanActivate() and nLastHarassUtility > botBrain.nNukeThreshold and GetCanNukeKillTarget(unitTarget) then
					if nTargetDistanceSq < (nRange * nRange) then
						if bDebugEchos then BotEcho("Using Codex") end
						if abilTaunt:CanActivate() then
							--if bDebugEchos then BotEcho("Taunt Tha Fool!!!") end
							bActionTaken = core.OrderAbilityEntity(botBrain, abilTaunt, unitTarget)
							BotEcho("Taunting like a boss")
						else
							BotEcho("KSin like a boss")
							if random(1, 20) == 1 then
								if random(1, 2) == 1 then
									core.AllChat("HUEHUEHUEHUE")
								else
									core.AllChat("JAJAJAJA")
								end
							end
							bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemNuke, unitTarget)
						end
					end
				end
			end
		end

		--Vanish
		if not bActionTaken then
			--activate when just out of melee range of target
			if not IsVanished(unitSelf) and abilVanish:CanActivate() then
				if HasManaRegen() and not IsLowMana() then
					if bDebugEchos then BotEcho("Spaming Vanish") end
					bActionTaken = core.OrderAbility(botBrain, abilVanish)
				elseif nLastHarassUtility > botBrain.nVanishThreshold 
				and (not IsLowMana() or HasManaRegen()) then
					if bDebugEchos then BotEcho("Casting Vanish") end
					bActionTaken = core.OrderAbility(botBrain, abilVanish)
				end
			elseif IsVanished(unitSelf) and abilVanish:CanActivate() 
			and IsLowMana() and not HasManaRegen() then
				if bDebugEchos then BotEcho("Turning Off Vanish, Low Mana") end
				bActionTaken = core.OrderAbility(botBrain, abilVanish)
			end
		end	
	
		--Electric Eye
		if not bActionTaken and nLastHarassUtility > botBrain.nElectricEyeThreshold and not IsLowMana() then
			if abilElectricEye:CanActivate() and not bTargetSilenced and not bTargetVuln then
				local vecAbilityPosition = core.AoETargeting(core.unitSelf, nCheckRange, nRadius, true, unitTarget, core.enemyTeam, nil)
		
				if vecAbilityPosition == nil then
					vecAbilityPosition = vecTargetPosition
				end
				
				if bDebugEchos then BotEcho("Casting Electric Eye") end
				bActionTaken = core.OrderAbilityPosition(botBrain, abilElectricEye, vecAbilityPosition)
				bEyePlaced = true
				vecEyePosition = vecAbilityPosition
			end
		end
		
		--Detonate
		if not bActionTaken then
			if abilDetonate:CanActivate() and not bTargetSilenced and not bTargetVuln then
				if bEyePlaced and vecEyePosition ~= nil then
					local nEyeTargetDistanceSq = Vector3.Distance2DSq(vecEyePosition, vecTargetPosition)
					if nEyeTargetDistanceSq < (GetElectricEyeRadius() * GetElectricEyeRadius()) then
						if bDebugEchos then BotEcho("Casting Detonate") end
						bActionTaken = core.OrderAbility(botBrain, abilDetonate)
						bEyePlaced = false
						vecEyePosition = nil
					end	
				end
			end
		end
	end	
	
	--Harkons
	if not bActionTaken then 
		if itemHarkonsBlade and itemHarkonsBlade:GetActiveModifierKey() ~= "harkons_toggle_on" then
			--if bDebugEchos then BotEcho("Toggling on Harkons") end
			--bActionTaken = botBrain:OrderItem2(itemHarkonsBlade)
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
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)
	local bUpdated = object.FindItemsOld(botBrain)

	if bUpdated then
		--only update if we need to
		if core.itemNuke and core.itemHarkonsBlade then
			return
		end

		local inventory = core.unitSelf:GetInventory(true)
		for slot = 1, 12, 1 do
			local curItem = inventory[slot]
			if curItem then
				if core.itemHarkonsBlade == nil and curItem:GetName() == "Item_HarkonsBlade" then
					core.itemHarkonsBlade = core.WrapInTable(curItem) 
				elseif core.itemNuke == nil and curItem:GetName() == "Item_Nuke" then
					core.itemNuke = core.WrapInTable(curItem)
				end
			end
		end
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride

----------------------------------
--  RetreatFromThreat Override
----------------------------------
object.nRetreatStealthThreshold = 35
behaviorLib.nRecentDamageMul = 0.50

--Unfortunately this utility is kind of volatile, so we basically have to deal with util spikes
function funcRetreatFromThreatExecuteOverride(botBrain)
	local bDebugEchos = false
	
	local bActionTaken = false
	local unitSelf = core.unitSelf
	
	--Vanish
	if not bActionTaken then
		local abilVanish = skills.abilVanish
		
		if behaviorLib.lastRetreatUtil >= object.nRetreatStealthThreshold and 
		abilVanish:CanActivate() and not IsVanished(unitSelf) then
			if bDebugEchos then BotEcho("RETREAT! Casting Vanish") end
			bActionTaken = core.OrderAbility(botBrain, abilVanish)
			return object.RetreatFromThreatExecuteOld(botBrain)
		end
	end
	
	if behaviorLib.lastRetreatUtil > 60 then
		if random(1, 200) == 1 then
			core.AllChat("Team? TEAM?!?!?!?!! WHERES MY TEAM!?!?!?")
		end
	end
	
	if not bActionTaken then
		return object.RetreatFromThreatExecuteOld(botBrain)
	end
end
object.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatExecute
behaviorLib.RetreatFromThreatBehavior["Execute"] = funcRetreatFromThreatExecuteOverride

function funcHealAtWellExecuteOverride(botBrain)
	local bDebugEchos = false
	
	local bActionTaken = false
	local unitSelf = core.unitSelf
	
	--Vanish
	if not bActionTaken then
		local abilVanish = skills.abilVanish
		
		if abilVanish:CanActivate() then
			if not IsVanished(unitSelf) and IsLowHealth() or not IsLowMana() or HasManaRegen() then
				if bDebugEchos then BotEcho("GO HOME! Casting Vanish") end
				bActionTaken = core.OrderAbility(botBrain, abilVanish)
				return object.HealAtWellExecuteOld(botBrain)
			elseif IsVanished(unitSelf) and IsLowMana() and not HasManaRegen() then
				--bActionTaken = core.OrderAbility(botBrain, abilVanish)
				return object.HealAtWellExecuteOld(botBrain)
			end
		end
	end
	
	if not bActionTaken then
		return object.HealAtWellExecuteOld(botBrain)
	end
end
object.HealAtWellExecuteOld = behaviorLib.HealAtWellExecute
behaviorLib.HealAtWellBehavior["Execute"] = funcHealAtWellExecuteOverride

----------------------------------
--	Scout items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
	
behaviorLib.StartingItems = 
	{"Item_LoggersHatchet", "Item_IronBuckler", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = 
	{"Item_Marchers", "Item_Steamboots", "Item_Nuke 1"}
behaviorLib.MidItems = 
	{"Item_SpellShards 3", "Item_Nuke 5"}
behaviorLib.LateItems =
	{"Item_Brutalizer", "Item_Pierce 3", "Item_SpellShards 3", "Item_Nuke 5", "Item_BehemothsHeart"} 
	--{"Item_HarkonsBlade", "Item_BehemothsHeart", 'Item_Damage9'} --Item_Lightning2 is Charged Hammer. Item_Damage9 is Doombringer

 

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

BotEcho('finished loading scout_main')