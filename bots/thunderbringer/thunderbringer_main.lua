-- Just Thunderbringer v 0.3  Kunas = Thunderbringer... durp
-- By Atornius, just a random HoN-player. If you have any questions about this bot feel free to ask if I am online
-- Special thanks to Naib and his Bot Tutorial: Pyro
-- Special thanks to Anakonda and his BombardierBot because I used his bot as template
-- Special thanks to kairus101 and his PebblesBot because I took some variables and ideas from his bot
-- Special thanks to St0l3n_ID and his lua guide
-- Special thanks to Wards and his Farming Style Last Hits (Kais + Fixes)

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

BotEcho('loading thunderbringer_main.lua...')

object.heroName = 'Hero_Kunas'

------------------------------
--     skills               --
------------------------------
function object:SkillBuild()
core.VerboseLog("skillbuild()")


local unitSelf = self.core.unitSelf
if  skills.abilQ == nil then
    skills.abilQ = unitSelf:GetAbility(0)
    skills.abilW = unitSelf:GetAbility(1)
    skills.abilE = unitSelf:GetAbility(2)
    skills.abilR = unitSelf:GetAbility(3)
    skills.abilAttributeBoost = unitSelf:GetAbility(4)
	skills.abilT = unitSelf:GetAbility(8) -- Taunte
end
if unitSelf:GetAbilityPointsAvailable() <= 0 then
    return
end
-- Skill build
tSkills ={
				0, 2, 1, 1, 1,
				3, 1, 2, 2, 2,
				3, 0, 0, 0, 4,
				3
			}
	local nLev = unitSelf:GetLevel()
    local nLevPts = unitSelf:GetAbilityPointsAvailable()
    --BotEcho(tostring(nLev + nLevPts))
    for i = nLev, nLev+nLevPts do
		local nSkill = tSkills[i]
		if nSkill == nil then nSkill = 4 end
		
        unitSelf:GetAbility(nSkill):LevelUp()
    end
end		

-- bonus agression points if a skill/item is available for use
object.abilQUp = 5
object.abilWUp = 10
object.abilRUp = 15
object.nSheepstickUp = 10

-- bonus agression points that are applied to the bot upon successfully using a skill/item
object.abilQUse = 0
object.abilWUse = 10
object.abilRUse = 0
object.nSheepstickUse = 0



object.abilQUseTime = 0
object.abilRUseTime = 0
object.abilWUseTime = 0
--Hero ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
    self:oncombateventOld(EventData)
	
	local bDebugEchos = false
    local addBonus = 0

    if EventData.Type == "Ability" then
		if bDebugEchos then BotEcho(" ABILITY EVENT! InflictorName: "..EventData.InflictorName) end
        if EventData.InflictorName == "Ability_Kunas1" then
            addBonus = addBonus + object.abilQUse
			object.abilQUseTime = EventData.TimeStamp
			--BotEcho(object.abilQUseTime)
        elseif EventData.InflictorName == "Ability_Kunas2" then
            addBonus = addBonus + object.abilWUse
			object.abilWUseTime = EventData.TimeStamp
			--BotEcho(object.abilWUseTime)
        elseif EventData.InflictorName == "Ability_Kunas4" then
            addBonus = addBonus + object.abilRUse
			object.abilRUseTime = EventData.TimeStamp
			--BotEcho(object.abilRUseTime)
        end
	elseif EventData.Type == "Item" then
		if core.itemSheepstick ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemSheepstick:GetName() then
			addBonus = addBonus + self.nSheepstickUse
		end
	end
    if addBonus > 0 then
        core.DecayBonus(self)
        core.nHarassBonus = core.nHarassBonus + addBonus
    end

end
object.oncombateventOld = object.oncombatevent
object.oncombatevent    = object.oncombateventOverride


--Util calc override
local function CustomHarassUtilityFnOverride(hero)
	local bDebugLines = false
	local self = core.unitSelf
	local selfMaxMana = self:GetMaxMana()
	local selfMana = self:GetMana()
	local selfManaPercentage = (selfMana * 100) / selfMaxMana
	local selfMaxHealth = self:GetMaxHealth()
	local selfHealth = self:GetHealth()
	local selfHealthPercentage = (selfHealth * 100) / selfMaxHealth
	
	local nUtility = 0
	
	if skills.abilQ:CanActivate() then
		nUtility = nUtility + object.abilQUp
	end
	
	if skills.abilW:CanActivate() then
		nUtility = nUtility + object.abilWUp
	end
	
	if skills.abilR:CanActivate() then
		nUtility = nUtility + object.abilRUp
	end
	
	if object.itemSheepstick and object.itemSheepstick:CanActivate() then
		nUtility = nUtility + object.nSheepstickUp
	end
	
	if selfHealthPercentage < 55 then
		nUtility = 0
	end
	
	--[[ Just so he have some mana to reg.
	if selfManaPercentage > 95 then
		nUtility = nUtility + 100
	end
	--]]
	
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride   

----------------------------------
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)
	local bUpdated = object.FindItemsOld(botBrain)

	if core.itemSheepstick ~= nil and not core.itemSheepstick:IsValid() then
		core.itemSheepstick = nil
	end

	if bUpdated then
		--only update if we need to
		if core.itemSheepstick then
			return
		end

		local inventory = core.unitSelf:GetInventory(true)
		for slot = 1, 12, 1 do
			local curItem = inventory[slot]
			if curItem then
				if core.itemSheepstick == nil and curItem:GetName() == "Item_Morph" then
					core.itemSheepstick = core.WrapInTable(curItem)
				end
			end
		end
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride


--------------------------------------------------------------
--                    Harass Behavior                       --
-- All code how to use abilities against enemies goes here  --
--------------------------------------------------------------
local timeToChat = 10000
local function HarassHeroExecuteOverride(botBrain)
	
	local target = behaviorLib.heroTarget
	if target == nil then
		return object.harassExecuteOld(botBrain) --Eh nothing here
	end
	
	--fetch some variables 
	local timeToChatW = 0
	local timeToChatR = 0
	
	local self = core.unitSelf
	local selfPosition = self:GetPosition()
	
	local cantDodge = target:IsStunned() or target:IsImmobilized() or target:IsPerplexed() or target:GetMoveSpeed() < 200 --Confirm: target:HasState("State_Channeling"), don't work
	local canSee = core.CanSeeUnit(botBrain, target)
	
	local targetPosition = target:GetPosition()
	local distance = Vector3.Distance2DSq(selfPosition, targetPosition)
	
	local aggroValue = behaviorLib.lastHarassUtil
	local actionTaken = false

	local targetMaxHealth = target:GetMaxHealth()
	local targetHealth = target:GetHealth()
	local targetHealthPercentage = targetHealth * 100 / targetMaxHealth 
	
	-- Just a few variables for tb's spells, durp
	local useQ = skills.abilQ:CanActivate()
	local useW = skills.abilW:CanActivate()
	local chain = skills.abilQ:GetRange()
	local blast = skills.abilW:GetRange()
	local LevelE = skills.abilE:GetLevel()
	local LevelW = skills.abilW:GetLevel()
	local LevelR = skills.abilE:GetLevel()
	
	
	local DamageW = 110
	if LevelW == 2 then
		DamageW = 190
	elseif LevelW == 3 then
		DamageW = 270
	elseif LevelW == 4 then
		DamageW =350
	end
	
	local DamageR = 225
	if LevelR == 2 then
		DamageR = 335
	elseif LevelR == 3 then
		DamageR = 460
	end	
	
	local DamageE = 0.04
	if LevelE == 2 then
		DamageE = 0.06
	elseif LevelE == 3 then
		DamageE = 0.08
	elseif LevelE == 4 then
		DamageE = 0.1
	end
	
	core.FindItems(botBrain)
	
	
	local extraDmg = targetHealth * DamageE
	local MagicResistance = target:GetMagicResistance()
	if MagicResistance == nil then
		MagicResistance = 0.719 -- Tb's magic resistance (6.5 magic armor)
	end
	local TrueDamageW = DamageW * (1 - MagicResistance)
	local TrueDamageR = DamageR * (1 - MagicResistance)
	
	if targetHealthPercentage < 75 then
		aggroValue = aggroValue + (1000 / targetHealthPercentage) 
	end
	
	--Want to make sure that the passive is up before starts spamming chain
	if not actionTaken and (LevelE ~= nil and LevelE ~= 0) and targetHealthPercentage > 80 then
		if useQ then
			if distance < (chain * chain) then
				actionTaken = core.OrderAbilityEntity(botBrain, skills.abilQ, target)
			end
		end
	end
	--
	
	-- Just a free attack on the target
	if cantDodge and canSee then
		if useW then 
			if distance < (blast * blast) then
				actionTaken = core.OrderAbilityEntity(botBrain, skills.abilW, target)
			end
		end
	end
	
	-- Ks if he is in range, hava mana and no cd on W
	-- Added taunte just for fun :3
	if not actionTaken and canSee and TrueDamageW > targetHealth then
		if skills.abilT:CanActivate() then
			if distance < (650 * 650) then
				-- 650 is just a safty range so he can use Blast right after
				actionTaken = core.OrderAbilityEntity(botBrain, skills.abilT, target)
				timeToChatW = HoN.GetMatchTime()
			end
		elseif useW then
			if distance < (blast * blast) then
				actionTaken = core.OrderAbilityEntity(botBrain, skills.abilW, target)
			end
		end
	end
	
	--Ults when "target" is low, so not when someone accross the map is low
	-- Ks if he have mana and no cd, durp dont hate 
	if not actionTaken and canSee and TrueDamageR > targetHealth then
		if skills.abilR:CanActivate() then
			actionTaken = core.OrderAbility(botBrain, skills.abilR)
			timeToChatR = HoN.GetMatchTime()
		end
	end

	
	
	--sheepstick: Use if the target can move and aggroValue > 55
	if not actionTaken and not cantDodge then
		if canSee then
			local itemSheepstick = core.itemSheepstick
			if itemSheepstick then
				local sRange = itemSheepstick:GetRange()
				if itemSheepstick:CanActivate() and aggroValue > 55 then
					if distance < (sRange * sRange) then
						actionTaken = core.OrderItemEntityClamp(botBrain, self, itemSheepstick, target)
					end
				end
			end
		end
	end
	
	-- Spam on when tb start to get aggresive
	if not actionTaken and canSee then
		if aggroValue > 50 then
			if distance < (blast * blast) and useW then
				actionTaken = core.OrderAbilityEntity(botBrain, skills.abilW, target)
			elseif distance < (chain * chain) and useQ then
				actionTaken = core.OrderAbilityEntity(botBrain, skills.abilQ, target)
			end
		end
	end
	
	-- Use blast if target is below 55% health
	if not actionTaken and canSee then
		if targetHealthPercentage < 55 then
			if useW then 
				if distance < (blast * blast) then
					actionTaken = core.OrderAbilityEntity(botBrain, skills.abilW, target)
				end
			end
		end
	end
	
	-- Use Chain if target is below 40% (might be overrated this one)
	if not actionTaken and canSee then
		if targetHealthPercentage < 40 then
			if useQ then
				if distance < (chain * chain) then
					actionTaken = core.OrderAbilityEntity(botBrain, skills.abilQ, target)
				end
			end
		end
	end
	
	-- Just to make sure that he harras once in a while, 15s cooldown
	if not actionTaken and canSee then
		if object.abilQUseTime + 15000 < HoN.GetGameTime() and (LevelE ~= nil and LevelE ~= 0) then
			if useQ then
				if distance < (chain * chain) then
					actionTaken = core.OrderAbilityEntity(botBrain, skills.abilQ, target)
				end
			end
		end
	end
	--
	if timeToChatW > timeToChat then
		-- When taunting someone           idk what to put down here to get player name or hero name, therefore it wont work :|
		core.AllChat("Let me introduce " + target:GetName() + " to lightning.")
		timeToChat = timeToChatW + 15000
	end
	
	if timeToChatR > timeToChat then
		-- When ulting
		core.AllChat("Let there be thunder!")
		timeToChat = timeToChatR + 15000 
	end
	
	if not actionTaken then
		return object.harassExecuteOld(botBrain)
	end

	
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

local function RetreatFromThreatExecuteOverride(botBrain)
	local actionTaken = false
	local self = core.unitSelf
	local target = behaviorLib.heroTarget
	if target == nil then
		return false
	end
	local targetPosition = target:GetPosition()
	local selfPosition = self:GetPosition()
	local distance = Vector3.Distance2DSq(selfPosition, targetPosition)
	local canSee = core.CanSeeUnit(botBrain, target)
	core.FindItems()
	
	
	if not actionTaken and canSee then
		-- Use sheepstick if he have one on the follower
		local itemSheepstick = core.itemSheepstick
		if itemSheepstick then
			local sRange = itemSheepstick:GetRange()
			if itemSheepstick:CanActivate() and distance < (sRange * sRange) then
				actionTaken = core.OrderItemEntityClamp(botBrain, self, itemSheepstick, target)
			end
		end
	elseif self:GetMoveSpeed() < target:GetMoveSpeed() then
		-- Spam da spells, I mean the target is still faster then tb anyway
		local Blast = skills.abilW:GetRange()
		if skills.abilW:CanActivate() and distance < (Blast * Blast) then
			actionTaken = core.OrderAbilityEntity(botBrain, skills.abilW, target)
		elseif skills.abilQ:CanActivate() and distance < (Blast * Blast) then
			-- Using Blast of Lightnings range here instead of Chain Lightnings range
			actionTaken = core.OrderAbilityEntity(botBrain, skills.abilQ, target)
		end
	end
	
	
	if not actionTaken then
		return object.RetreatFromThreatExecuteOld(botBrain)
	end

	local vecPos = behaviorLib.PositionSelfBackUp()
	core.OrderMoveToPosClamp(botBrain, core.unitSelf, vecPos, false)
end

object.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatBehavior["Execute"]
behaviorLib.RetreatFromThreatBehavior["Execute"] = RetreatFromThreatExecuteOverride


function GetClosestEnemyHero(botBrain)
	local unitClosestHero = nil
	local nClosestHeroDistSq = 99999*99999
	for id, unitHero in pairs(HoN.GetHeroes(core.enemyTeam)) do
		if unitHero ~= nil then
			if core.CanSeeUnit(botBrain, unitHero) then
		
				local nDistanceSq = Vector3.Distance2DSq(unitHero:GetPosition(), core.unitSelf:GetPosition())
				if nDistanceSq < nClosestHeroDistSq then
					nClosestHeroDistSq = nDistanceSq
					unitClosestHero = unitHero
				end
			end
		end
	end
	
	return unitClosestHero
end

function IsTowerThreateningUnit(unit)
	vecPosition = unit:GetPosition()

	local nTowerRange = 821.6 --700 + (86 * sqrtTwo)
	nTowerRange = nTowerRange
	local tBuildings = HoN.GetUnitsInRadius(vecPosition, nTowerRange, core.UNIT_MASK_ALIVE + core.UNIT_MASK_BUILDING)
	for key, unitBuilding in pairs(tBuildings) do
		if unitBuilding:IsTower() and unitBuilding:GetCanAttack() and (unitBuilding:GetTeam()==unit:GetTeam())==false then
			return true
		end
	end
	
	return false
end

function behaviorLib.GetCreepAttackTarget(botBrain, unitEnemyCreep, unitAllyCreep) --called pretty much constantly
	unitSelf=core.unitSelf
	
	-- random stuff that should be called each frame!
	target = GetClosestEnemyHero(botBrain)
	if (target==nil) then
		core.nHarassBonus=0
	else
		if core.CanSeeUnit(botBrain, target) then
			if target:HasState("State_HealthPotion") or target:HasState("State_ManaPotion") or (IsTowerThreateningUnit(target) and target:GetHealth() < 500) then
				-- Want to cancel enemys pots and attack if the target got toweraggro + allready is kinda low 
				core.nHarassBonus=50
			else
				core.nHarassBonus=0
			end
		else
			core.nHarassBonus=0
		end
	end

	local bDebugEchos = false
	-- no predictive last hitting, just wait and react when they have 1 hit left
	-- prefers LH over deny

	local unitSelf = core.unitSelf
	local nDamageAverage = unitSelf:GetFinalAttackDamageMin() --make the hero go to the unit
	
	-- [Difficulty: Easy] Make bots worse at last hitting
	if core.nDifficulty == core.nEASY_DIFFICULTY then
		nDamageAverage = nDamageAverage + 120
	end

	if unitEnemyCreep and core.CanSeeUnit(botBrain, unitEnemyCreep) then
		local nTargetHealth = unitEnemyCreep:GetHealth()-40 ----------
		if nDamageAverage >= nTargetHealth then
			local bActuallyLH = true
			
			if bActuallyLH then
				if bDebugEchos then BotEcho("Returning an enemy") end
				return unitEnemyCreep
			end
		end
	end

	if unitAllyCreep then
		local nTargetHealth = unitAllyCreep:GetHealth()
		if nDamageAverage >= nTargetHealth then
			local bActuallyDeny = true
			
			--[Difficulty: Easy] Don't deny
			if core.nDifficulty == core.nEASY_DIFFICULTY then
				bActuallyDeny = false
			end			
			
			if bActuallyDeny then
				if bDebugEchos then BotEcho("Returning an ally") end
				return unitAllyCreep
			end
		end
	end

	return nil
end

function AttackCreepsExecuteOverride(botBrain)
	local unitSelf = core.unitSelf
	local currentTarget = core.unitCreepTarget

	if currentTarget and core.CanSeeUnit(botBrain, currentTarget) then		
		local vecTargetPos = currentTarget:GetPosition()
		local nDistSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecTargetPos)
		local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, currentTarget, true)
		local unitTarget = behaviorLib.heroTarget
		if unitTarget == nil then
			return false
		end
		local unitPos = unitTarget:GetPosition()
		local DistSq = Vector3.Distance2DSq(vecTargetPos, unitPos)
		local canSeeH = core.CanSeeUnit(botBrain, unitTarget)
		local canSeeC = core.CanSeeUnit(botBrain, currentTarget)
		
		local nDamageAverage = unitSelf:GetFinalAttackDamageMin()

		if currentTarget ~= nil then
			if canSeeH and canSeeC and ((unitSelf:GetMana() * 100) / unitSelf:GetMaxMana()) > 50  and skills.abilQ:CanActivate() and nDistSq < (skills.abilQ:GetRange() * skills.abilQ:GetRange())then
				if DistSq < (350 * 350) and 84 >= currentTarget:GetHealth() then
				-- Hit target with chain lightining if the creep and hero is within 350 range of eachother and Mana < 50%
				core.OrderAbilityEntity(botBrain, skills.abilQ, unitTarget)
				end
			elseif nDistSq < nAttackRangeSq and unitSelf:IsAttackReady() and nDamageAverage>=currentTarget:GetHealth() then
				-- Getting the CK
				core.OrderAttackClamp(botBrain, unitSelf, currentTarget)
			elseif nDistSq > nAttackRangeSq and unitSelf:IsAttackReady() and nDamageAverage>=currentTarget:GetHealth()-40 then
			    -- Get in range to score CK
                local vecDesiredPos = core.AdjustMovementForTowerLogic(vecTargetPos)
                core.OrderMoveToPosClamp(botBrain, unitSelf, vecDesiredPos, false) --Move.
			else 
				-- Hold if there is friendly creeps nearby
				core.OrderHoldClamp(botBrain, unitSelf, false)
			end
		end
	else
		return false
	end
end
object.AttackCreepsExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.AttackCreepsBehavior["Execute"] = AttackCreepsExecuteOverride


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


--   item buy order. internal names  
behaviorLib.StartingItems  = {"Item_RunesOfTheBlight", "Item_RunesOfTheBlight", "Item_PretendersCrown", "Item_MarkOfTheNovice", "Item_MinorTotem"}
behaviorLib.LaneItems  = {"Item_Marchers", "Item_GraveLocket", "Item_Striders", "Item_MysticVestments", "Item_Scarab"}
behaviorLib.MidItems  = {"Item_SpellShards 3", "Item_Freeze", "Item_Lightbrand"} 
-- Swapped out staff of the master to Frost wolf becouse of the slow and how bad the staff is + more survivability.   Item_Intelligence7
behaviorLib.LateItems  = {"Item_Morph", "Item_GrimoireOfPower", "Item_PostHaste", "Item_HomecomingStone"}  
-- Have homecoming stone last becouse he keeps on buying the last thing over and over again.. durp mode

BotEcho(object:GetName()..'finished loading thunderbringer_main.lua')













--[[ For some "Going to well" function
	local Reggen = 0
	 -- Going to well if health < 20% and mana < 75 (the Tp cost)
	if (((core.unitSelf:GetHealth() * 100) / core.unitSelf:GetMaxHealth()) < 20 or (core.unitSelf:GetMana() < 75 and core.unitSelf:GetLevel() >= 6)) or Reggen == 1 then
		--Going to well when low on health or have low mana + level >= 6 so he don't go back to early
		--BotEcho("Returning to well!")
		-- Added "Reggen" because when tb was on his way back to the well he could reg his mana over 75 / health over 20% and start go back to the lane
		Reggen = 1
		core.nHarassBonus = 0
		if core.unitSelf:GetHealth() >= core.unitSelf:GetMaxHealth() - 100 and core.unitSelf:GetMana() >= core.unitSelf:GetMaxMana() - 100  then
			Reggen = 0
		end
		local wellPos = core.allyWell and core.allyWell:GetPosition() or behaviorLib.PositionSelfBackUp()
		core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, wellPos, false)
	end
--]]