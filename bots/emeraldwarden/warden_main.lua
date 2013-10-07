--WardenBot v0.000001
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

local sqrtTwo = math.sqrt(2)

BotEcho('loading warden_main...')

object.heroName = 'Hero_EmeraldWarden'

--------------------------------
-- Skills
--------------------------------
function object:SkillBuild()
	--core.VerboseLog("SkillBuild()")
	
	local unitSelf = self.core.unitSelf

	if skills.trap == nil then
		skills.silence		= unitSelf:GetAbility(0)
		skills.wolves	= unitSelf:GetAbility(1)
		skills.trap		= unitSelf:GetAbility(2)
		skills.bird		= unitSelf:GetAbility(3)
		skills.bird1	= unitSelf:GetAbility(5)
		skills.bird2	= unitSelf:GetAbility(6)
		skills.bird3	= unitSelf:GetAbility(7)
		skills.attributeBoost = unitSelf:GetAbility(4)
	end
	
	--[[ ability property test
	local sting = self.flare
	if sting then
		core.BotEcho(format("range: %g  manaCost: %g  canActivate: %s  isReady: %s  cooldownTime: %g  remainingCooldownTime: %g", 
		sting:GetRange(), sting:GetManaCost(), tostring(sting:CanActivate()), tostring(sting:IsReady()), sting:GetCooldownTime(), sting:GetRemainingCooldownTime()
		))
	end --]]
	
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	--speicific level 1 skill
	if skills.trap:GetLevel() < 1 then
		skills.trap:LevelUp()
	elseif skills.bird:CanLevelUp() then
		skills.bird:LevelUp()
	elseif skills.silence:CanLevelUp() then
		skills.silence:LevelUp()
	elseif skills.wolves:CanLevelUp() then
		skills.wolves:LevelUp()
	elseif skills.trap:CanLevelUp() then
		skills.trap:LevelUp()
	else
		skills.attributeBoost:LevelUp()
	end	
end


---------------------------------------------------
--                   Overrides                   --
---------------------------------------------------

--[[for testing
function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)
	
	core.unitSelf:TeamShare()
	
	if false then
		local unitSelf = core.unitSelf
		local nAttackSpeed = unitSelf:GetAttackSpeed()
		local nAdjustedAttackCD = unitSelf:GetAdjustedAttackCooldown() / 1000
		BotEcho(format(
			"AS: %g  Adusted Attack CD: %g  AttacksPerSecond: %g", nAttackSpeed, nAdjustedAttackCD, 1/nAdjustedAttackCD
			)
		)
	end
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride
--]]


----------------------------------
--	Flint specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

object.wolvesUpBonus = 8
object.silenceUpBonus = 5
object.trapUp = 0
object.birdAttackUp = 9
object.birdHealUp = 10
object.birdStormUp = 7

object.wolvesUsed = 10
object.silenceUsed = 5
object.trappedBonus = 35
object.birdAttackBonus = 10
object.birdHealBonus = 10
object.birdStormBonus = 10

object.wolvesThreshold = 65 -- wolves threshold is high, but if we're near more than one enemy we'll use them to harass
object.silenceThreshold = 50 -- main harass / initiation method

local function AbilitiesUpUtilityFn()
	local val = 0
	
	if skills.wolves:CanActivate() then
		val = val + object.wolvesUpBonus
	end
	
	if skills.silence:CanActivate() then
		val = val + object.silenceUpBonus
	end
	
	if skills.trap:CanActivate() then
		val = val + object.trapUp
	end
	
	if skills.bird1:CanActivate() then
		val = val + object.birdAttackUp
	end
	
	if skills.bird2:CanActivate() then
		val = val + object.birdHealUp
	end
	
	if skills.bird3:CanActivate() then
		val = val + object.birdStormUp
	end	
	
	return val
end

----------------------
--Item Harras Values
----------------------
local function HasItemsUtilityFn()
	local val = 0
	
	core.FindItems()
	
	--Scale up the aggression depending on how many Items we have
	--elseif structure should work since the item build order is static
	
	if core.itemProtect then
		val = val + 5
	elseif core.itemStrengthAgility then
		val = val + 10
	elseif core.itemWeapon3 then
		val = val + 20
	elseif core.itemLightning2 then
		val = val + 30
	end
	
	return val
end

--Warden ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local addBonus = 0
	
	if EventData.Type == "Ability" then
		--BotEcho("ABILILTY EVENT!  InflictorName: "..EventData.InflictorName)		
		if EventData.InflictorName == "Ability_EmeraldWarden1" then
			addBonus = addBonus + object.wolvesUsed
		end
		if EventData.InflictorName == "Ability_EmeraldWarden2" then
			addBonus = addBonus + object.silenceUsed
		end
		if EventData.InflictorName == "Ability_EmeraldWarden3" then
			addBonus = addBonus + object.trappedBonus
		end
		if EventData.InflictorName == "Ability_EmeraldWarden4_a" then
			addBonus = addBonus + object.birdAttackBonus
		end
		if EventData.InflictorName == "Ability_EmeraldWarden4_b" then
			addBonus = addBonus + object.birdHealBonus
		end
		if EventData.InflictorName == "Ability_EmeraldWarden4_c" then
			addBonus = addBonus + object.birdStormBonus
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


--Util calc override
local function CustomHarassUtilityOverride(hero)
	local nUtility = AbilitiesUpUtilityFn()	
	nUtility = nUtility + HasItemsUtilityFn()
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride  


----------------------------------
--	warden harass actions
----------------------------------
local function HarassHeroExecuteOverride(botBrain)

	local unitTarget = behaviorLib.heroTarget 
	local vecTargetPos = unitTarget and unitTarget:GetPosition()	
	
	local unitSelf = core.unitSelf	
	local vecMyPosition = unitSelf:GetPosition()
	local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
	nAttackRangeSq = nAttackRangeSq * nAttackRangeSq
	local nMyExtraRange = core.GetExtraRange(unitSelf)
	local nCurrentMana = unitSelf:GetMana()
	local nDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecTargetPos)
	
	local unitTarget = behaviorLib.heroTarget 
	
	local nTargetExtraRange = core.GetExtraRange(unitTarget)
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPos)	
		
	local nLastHarassUtility = behaviorLib.lastHarassUtil	
	local bActionTaken = false
	
	local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200
	local bTargetSilenced = unitTarget:IsSilenced()
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)
	
	local abilWolves = skills.wolves
	local abilTrap = skills.trap
	local abilSilence = skills.silence
	
	if unitTarget == nil or vecTargetPos == nil then
		return false -- we can't procede, reassess behaviors
	end
	
	
	--wolves harass
	if not bActionTaken then
		--If we have lots of mana and there are 2 or more enemies around harass with wolves				
		if abilWolves:GetLevel() > 1 then
			if abilWolves:CanActivate() and nCurrentMana > (unitSelf:GetMaxMana() * .5) then						
				local tEnemies = core.localUnits["EnemyHeroes"]
				local nCount = 0
				
				--check to see if there are 2 or more enemies around
				for id, unitEnemy in pairs(tEnemies) do
					if core.CanSeeUnit(botBrain, unitEnemy) then
						nCount = nCount + 1
					end
				end
				
				
				if nCount > 1 then
					--BotEcho(format("ultDamage: %d  damageMul: %g  trueDmg: %g  health: %d", nDamage, nDamageMultiplier, nTrueDamage, nHealth))
					bActionTaken = core.OrderAbility(botBrain, abilWolves)
				end
			end
		end
	end
	
	--wolves when chasing/atempting to kill
	if not bActionTaken then
		if abilWolves:CanActivate() and nLastHarassUtility > botBrain.wolvesThreshold then
			bActionTaken = core.OrderAbility(botBrain, abilWolves)
		end
	end
	
	--wolves to finish off, not sure if this will ever happen..
	if not bActionTaken then
		if abilWolves:CanActivate() and unitTarget:GetHealthPercent() < .2 then
			bActionTaken = core.OrderAbility(botBrain, abilWolves)
		end
	end
	
	--if someone's stunned and still has lots of health try to drop a trap on them
	if not bActionTaken then	
		
		local nRange = abilTrap:GetRange() + core.GetExtraRange(unitSelf) + core.GetExtraRange(unitTarget)	
		
		local bTrapUsable = abilTrap:CanActivate() and nDistanceSq < ((nRange * nRange) - 50)
		
		if bTrapUsable and bCanSee then			
			if unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200 then
				if unitTarget:GetHealthPercent() > .6 then
					--drop a trap on them							
					bActionTaken = core.OrderAbilityPosition(botBrain, abilTrap, vecTargetPos)					
				end	
			end
		end	
	end
	
	--silence is our main harass tool, use it to initiate, if you have lots of mana, or to try and finish them off
	if not bActionTaken then		
		local nRange = abilSilence:GetRange() + core.GetExtraRange(unitSelf) + core.GetExtraRange(unitTarget)				
		local bSilenceUsable = abilSilence:CanActivate() and nDistanceSq < (nRange * nRange)
		
		local bShouldSilence = false 
				
		if bSilenceUsable then
			if bCanSee then
				-- will change this to be more accurate in the future
				-- hopefully using min damage will mitigate the hardcoded lvl 4 silence somewhat
				if unitTarget:GetHealth() < (unitSelf:GetAttackDamageMin() + 100) then
					--Try for a kill shot
					bShouldSilence = true
				end
				
				if bTargetRooted then
					--Silence that fool!
					bShouldSilence = true
				end
				
				if ((nLastHarassUtility > botBrain.silenceThreshold) and (nCurrentMana > (unitSelf:GetMaxMana() * .35))) then
					--if you have some mana harass them
					bShouldSilence = true
				end				
			end
		end
		
		if bShouldSilence then
			bActionTaken = core.OrderAbilityEntity(botBrain, abilSilence, unitTarget)
		end
	end
	
	
	
	if not bActionTaken then
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
		if core.itemLightning2 then
			return
		end

		local inventory = core.unitSelf:GetInventory(true)
		for slot = 1, 12, 1 do
			local curItem = inventory[slot]
			if curItem then
				if core.itemProtect == nil and curItem:GetName() == "Item_Protect" then
					core.itemProtect = core.WrapInTable(curItem)
					break
				elseif core.itemStrengthAgility == nil and curItem:GetName() == "Item_StrengthAgility" then
					core.itemStrengthAgility = core.WrapInTable(curItem)
					break
				elseif core.itemWeapon3 == nil and curItem:GetName() == "Item_Weapon3" then
					core.itemWeapon3 = core.WrapInTable(curItem)
					break
				elseif core.itemLightning2 == nil and curItem:GetName() == "Item_Lightning2" then
					core.itemLightning2 = core.WrapInTable(curItem)
					break
				end
			end
		end
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride

----------------------------------
--  RetreatFromThreat Override	(Courtesy of Spennerino's ScoutBot)
----------------------------------
object.nRetreatWolvesThreshold = 18 --not sure how well these thresholds will work, will probably be tweaking them
object.nRetreatTrapThreshold = 45
object.nRetreatSilenceThreshold = 3

--Unfortunately this utility is kind of volatile, so we basically have to deal with util spikes 
function funcRetreatFromThreatExecuteOverride(botBrain)
	local bDebugEchos = true
	
	local bActionTaken = false
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	
	local unitTarget = nil
	local tEnemies = core.localUnits["EnemyHeroes"]
	local nCount = 0

	--check to see if there are enemies around
	for id, unitEnemy in pairs(tEnemies) do
		if core.CanSeeUnit(botBrain, unitEnemy) then
			nCount = nCount + 1
			unitTarget = unitEnemy
		end
	end
		
	if not bActionTaken then
		local abilSilence = skills.silence
		
		if behaviorLib.lastRetreatUtil >= object.nRetreatSilenceThreshold and unitSelf:GetLevel() > 2 then
			if unitTarget ~= nil and abilSilence:CanActivate() then
				bActionTaken = core.OrderAbilityEntity(botBrain, abilSilence, unitTarget)
			end
		end
	end
	
	if unitSelf:GetHealthPercent() < .75 then
		if nCount > 0 then
			--If we're getting pressured and ready to run away, first attempt to use wolves to slow them
			if not bActionTaken then
				local abilWolves = skills.wolves
				--slow em down
				if behaviorLib.lastRetreatUtil >= object.nRetreatWolvesThreshold and abilWolves:CanActivate() then
					if bDebugEchos then BotEcho("These Wolves will slow them down!") end
					bActionTaken = core.OrderAbility(botBrain, abilWolves)
				end
			end	
		
			--If they continue to follow drop a trap
			if not bActionTaken then
				local abilTrap = skills.trap
				--Drop a trap on your current location and continue to run away
				if behaviorLib.lastRetreatUtil >= object.nRetreatTrapThreshold and abilTrap:CanActivate() then
					if bDebugEchos then BotEcho("Trap him!") end
					bActionTaken = core.OrderAbilityPosition(botBrain, abilTrap, vecMyPosition)
				end
			end
		end
	end
	
		
	
	if not bActionTaken then
		return object.RetreatFromThreatExecuteOld(botBrain)
	end
end
object.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatExecute
behaviorLib.RetreatFromThreatBehavior["Execute"] = funcRetreatFromThreatExecuteOverride

-- Function for finding the center of a group
-- Credits to Stol3n_Id's RA Bot!
local function groupCenter(tGroup, nMinCount)
    if nMinCount == nil then nMinCount = 1 end
     
    if tGroup ~= nil then
        local vGroupCenter = Vector3.Create()
        local nGroupCount = 0 
        for id, creep in pairs(tGroup) do
            vGroupCenter = vGroupCenter + creep:GetPosition()
            nGroupCount = nGroupCount + 1
        end
         
        if nGroupCount < nMinCount then
            return nil
        else
            return vGroupCenter/nGroupCount-- center vector
        end
    else
        return nil   
    end
end


----------------------------------
--  Push Override
----------------------------------
object.trapCreepsThreshold = 19

--if were in all oout push mode try to use traps to kill creep waves faster
local function funcPushBehaviorExecuteOverride(botBrain)
	local bDebugEchos = true
	
	local nLastPushUtil = behaviorLib:PushUtility()
	
	local bActionTaken = false
	local unitSelf = core.unitSelf
	
	if nLastPushUtil ~= nil then
	
	if not bActionTaken then
		
		local nMask = core.UNIT_MASK_GADGET + core.UNIT_MASK_UNIT + core.UNIT_MASK_ALIVE
				
		--find our trap to deny it
		tGadgets = HoN.GetUnitsInRadius(unitSelf:GetPosition(), 1500, nMask)
								
		for id, trap in pairs(tGadgets) do
			if trap:GetTypeName() == 'Gadget_EmeraldWarden_Ability3' or trap:GetTypeName() == 'Gadget_EmeraldWarden_Ability3b' then
				core.OrderAttackClamp(botBrain, unitSelf, trap)
				bActionTaken = true
			end				
		end	
	
		local abilTrap = skills.trap
		--Try to drop a trap on enemy creeps
		if nLastPushUtil >= object.trapCreepsThreshold and abilTrap:CanActivate() then
			
			local tEnemyCreeps = core.localUnits["EnemyCreeps"]
			local nAttackingCount = 0
				
			--check to see if there are 2 or more enemies around and not moving
			for id, creeps in pairs(tEnemyCreeps) do
				if creeps:IsAttackReady() ~= true then
					nAttackingCount = nAttackingCount + 1
				end
			end			
			
			if  nAttackingCount > 2 and abilTrap:GetLevel() > 2 then
				bActionTaken = core.OrderAbilityPosition(botBrain, abilTrap, groupCenter(tEnemyCreeps, 1))									
			end
		end	
	end
	if not bActionTaken then
		return object.PushBehaviorExecuteOld(botBrain)
	end
	
	end
	
end
object.PushBehaviorExecuteOld = behaviorLib.PushExecute
behaviorLib.PushBehavior["Execute"] = funcPushBehaviorExecuteOverride


----------------------------------
--	Warden items
----------------------------------

behaviorLib.StartingItems = {"Item_RunesOfTheBlight", "Item_HealthPotion", "Item_DuckBoots", "Item_DuckBoots", "Item_MinorTotem", "Item_MinorTotem"}
behaviorLib.LaneItems = {"Item_IronShield", "Item_EnhancedMarchers", "Item_MysticVestments"}
behaviorLib.MidItems = {"Item_Protect", "Item_StrengthAgility"}
behaviorLib.LateItems = {"Item_Weapon3", "Item_Lightning2", "Item_Lightbrand", 'Item_Damage9'}



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

BotEcho('finished loading warden_main')
