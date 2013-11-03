--SkillStealer Bot v0.2 60-58 10.5 mins in.
 
local _G = getfenv(0)
local object = _G.object
object.myName = object:GetName()
object.bRunLogic,object.bRunBehaviors,object.bUpdates,object.bUseShop,object.bRunCommands,object.bMoveCommands,object.bAttackCommands,object.bAbilityCommands,object.bOtherCommands=true
object.logger = {}
object.bReportBehavior,object.bDebugUtility,object.logger.bWriteLog,object.logger.bVerboseLog=false
object.core 		= {}
object.eventsLib 	= {}
object.metadata 	= {}
object.behaviorLib 	= {}
object.skills 		= {}
runfile "bots/core.lua"
runfile "bots/botbraincore.lua"
runfile "bots/eventslib.lua"
runfile "bots/metadata.lua"
runfile "bots/behaviorlib.lua"
local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills
local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random, sqrt	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random, _G.math.sqrt
local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp
 
BotEcho('loading SkillStealer_main...')
object.heroName = 'Hero_Soulstealer'

behaviorLib.nCreepPushbackMul = 1 --0.5
behaviorLib.nTargetPositioningMul = 5 --0.6
behaviorLib.nTargetCriticalPositioningMul = 5 --2
 
--------------------------------
-- Skills
--------------------------------
function object:SkillBuild()
    local unitSelf = self.core.unitSelf

    if skills.hand == nil then
        skills.hand     = unitSelf:GetAbility(0)
        skills.steal    = unitSelf:GetAbility(1)
        skills.dread        = unitSelf:GetAbility(2)
        skills.burst    = unitSelf:GetAbility(3)
        skills.attributeBoost = unitSelf:GetAbility(4)
        skills.hand1 = unitSelf:GetAbility(5)
        skills.hand2 = unitSelf:GetAbility(6)
        skills.hand3 = unitSelf:GetAbility(7)
    end
    if unitSelf:GetAbilityPointsAvailable() <= 0 then
        return
    end
    --speicific level 1 skill
    if skills.steal:GetLevel() < 1 then
        skills.steal:LevelUp()
    elseif skills.hand:CanLevelUp() then--max in this order {hand, steal, burst, dread, stats}
        skills.hand:LevelUp()
    elseif skills.steal:CanLevelUp() then
        skills.steal:LevelUp()
    elseif skills.burst:CanLevelUp() then
        skills.burst:LevelUp()
    elseif skills.dread:CanLevelUp() then
        skills.dread:LevelUp()
    else
        skills.attributeBoost:LevelUp()
    end
end

object.handUpBonus = 15
object.ultUpBonus = 10
object.handUseBonus = 15
local function AbilitiesUpUtilityFn()
    local val = 0
    if skills.hand1:CanActivate() then val = val + object.handUpBonus end
    if skills.hand2:CanActivate() then val = val + object.handUpBonus end
    if skills.hand3:CanActivate() then val = val + object.handUpBonus end
    if skills.burst:CanActivate() then val = val + object.ultUpBonus end
    return val
end
 
function object:oncombateventOverride(EventData)
    self:oncombateventOld(EventData)
    local addBonus = 0
    if EventData.Type == "Ability" then
        if EventData.InflictorName == "Ability_SoulStealer5" or EventData.InflictorName == "Ability_SoulStealer6" or EventData.InflictorName == "Ability_SoulStealer7" then
            addBonus = addBonus + object.handUseBonus
        end
    end
    if addBonus > 0 then
        core.DecayBonus(self)
        core.nHarassBonus = core.nHarassBonus + addBonus
    end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent    = object.oncombateventOverride
 
--These two tables hold all units and their effective HP, their attack state etc
local unitArray = {}
--This table holds all damage that we can expect to see in the future, and when. It is a projectile/time till melee hits table.
local damageArray={}

--[[
    use:
    "set cg_botDebug true;set sv_botDebug true;\"
    To see current thinking process.
    Red arrows are attacks that are taking place
    Red crosses are units that currently have an attack coming towards them, that would hit before SS could hit them.
    Orange crosses are units that SS could hit, before the current attack hits them.
    Green crosses are units that SS may want to hit soon, but are too far away
    Lime crosses are units that SS wants to attack right now.
]]
 
 function object:onthinkOverride(tGameVariables) --This is run, even while dead. Every frame.
	self:onthinkOld(tGameVariables)--don't distrupt old think
	
	core.AssessLocalUnits(self) --this could be intensive. Revise.	
    local unitSelf = core.unitSelf
	local nProjectileSpeed=unitSelf:GetAttackProjectileSpeed()
    local nactionTime=unitSelf:GetAdjustedAttackActionTime()
    local position=unitSelf:GetPosition()	
    local oldGameTime = gameTime
    local gameTime = HoN.GetGameTime()
	
	if (core.localUnits)then
		localCreeps={}
		--Get all units nearby and put them into a single table, this is also the order of priority too!
		for k,v in pairs(core.localUnits['EnemyHeroes']) do localCreeps[k] = v end
		for k,v in pairs(core.localUnits['AllyHeroes']) do localCreeps[k] = v end
		for k,v in pairs(core.localUnits['EnemyTowers']) do localCreeps[k] = v end
		for k,v in pairs(core.localUnits['AllyTowers']) do localCreeps[k] = v end
		for k,v in pairs(core.localUnits['EnemyCreeps']) do localCreeps[k] = v end
		for k,v in pairs(core.localUnits['AllyCreeps']) do localCreeps[k] = v end
		 
		for key, unit in pairs(localCreeps) do
			if (unit~=nil and unit:IsAlive() and unit:GetCanAttack()) then
				id=key
				if not unitArray[id] then unitArray[id]={} end --init if need be (nil or old)
				if (unitArray[id]['attackState']~=nil and (core.GetAttackSequenceProgress(unit)=="followThrough" and unitArray[id]['attackState']=="windup")) then --JUST ATTACKED
					if unitArray[id]['target']~=nil and unitArray[unitArray[id]['target']:GetUniqueID()]~=nil then
						core.DrawDebugArrow(unit:GetPosition(),unitArray[id]['target']:GetPosition(), 'red')
						--save the expected damage, time it will happen(correcting for frame delay), reciever and if it is cancellable(melee via death)
						if unit:GetAttackType() ~= "melee" then
							table.insert(damageArray,{melee=false,attacker=unit,damage=unitArray[id]['averageAttackDamage']--[[*(1-unitArray[id]['target']:GetPhysicalResistance())]], 
							target=unitArray[id]['target'],time=HoN.GetGameTime() +(Vector3.Distance2D(unit:GetPosition(), unitArray[id]['target']:GetPosition()) / (unit:GetAttackProjectileSpeed()))*1000   })
						else
							table.insert(damageArray,{melee=true,attacker=unit,damage=unitArray[id]['averageAttackDamage']--[[*(1-unitArray[id]['target']:GetPhysicalResistance())]], 
							target=unitArray[id]['target'],time=HoN.GetGameTime() +unit:GetAdjustedAttackDuration()   })
						end
					end
				end
				 
				unitArray[id]['attackState']=core.GetAttackSequenceProgress(unit) --store old value.
				unitArray[id]['estimatedHp']=unit:GetHealth() --this will (possibly) be lowered soon
				unitArray[id]['target']=unit:GetAttackTarget() --to help with estimations.
				unitArray[id]['averageAttackDamage']=unit:GetFinalAttackDamageMin() --also to help with estimations. I tried average, but it was worse.
				-- STATIC VALUES
				unitArray[id]['unit']=unit --also to help with estimations.
			end
		end
		for key, attacker in pairs(unitArray) do
			if (attacker['unit']==nil or (not attacker['unit']:IsAlive()) ) then unitArray[key]=nil end --remove 60 second old entries
		end
		
		core.unitCreepTarget=nil
		for key, event in pairs(damageArray) do --apply expected future damage
			if (HoN.GetGameTime()>event['time'] or unitArray[event['target']:GetUniqueID()]==nil or not unitArray[event['target']:GetUniqueID()]['unit']:IsAlive() or (event['melee'] and not event['attacker']:IsAlive())) then
				table.remove(damageArray,key)
				--if (event['melee']==true) then
					core.DrawDebugArrow(event['attacker']:GetPosition(),event['target']:GetPosition(), 'white')
				--end
			elseif (event['target']:GetPosition() and unitSelf:GetAdjustedAttackActionTime()+(Vector3.Distance2D(unitSelf:GetPosition(), event['target']:GetPosition())/(unitSelf:GetAttackProjectileSpeed()))*1000+HoN.GetGameTime() > event['time']    ) then --if projectile will hit before hero can
				unitArray[event['target']:GetUniqueID()]['estimatedHp'] = unitArray[event['target']:GetUniqueID()]['estimatedHp'] - event['damage']
				core.DrawDebugArrow(event['attacker']:GetPosition(),event['target']:GetPosition(), 'red')
				--core.DrawXPosition(event['target']:GetPosition(), 'orange');
			else
				core.DrawDebugArrow(event['attacker']:GetPosition(),event['target']:GetPosition(), 'orange')
				--core.DrawXPosition(event['target']:GetPosition(), 'red');
			end
		end
	end
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride

function KaiGetCreepAttackTargetOverride(botBrain, unitEnemyCreep, unitAllyCreep)
    local bDebugEchos = false
    -- predictive last hitting, don't just wait and react when you can kill them (that would be stupid. T_T)
    local unitSelf = core.unitSelf
    local minimumDamage=unitSelf:GetFinalAttackDamageMax()
	
    --if (unitSelf:IsAttackReady()) then --give a change to run up to other units
	for key, target in pairs(unitArray) do --Check units to kill
		if (target~=nil and target['estimatedHp']~=nil and target['estimatedHp']>0 and target['unit']~=nil and target['unit']:GetPhysicalResistance() ~=nil and target['estimatedHp']<minimumDamage*(1-target['unit']:GetPhysicalResistance()) and not (core.teamBotBrain.nPushState==2 and target['unit']:GetTeam()==unitSelf:GetTeam())) then
			core.DrawXPosition(target['unit']:GetPosition(), 'lime');
			return target['unit']
		--else
			--BotEcho("Can't kill unit with "..target['unit']:GetHealth().."("..target['estimatedHp']..") because "..minimumDamage*(1-target['unit']:GetPhysicalResistance()).." is too low.")
		end
	end
    --end
	--get close to killable units.
	lowestLife=99999
	for key, target in pairs(unitArray) do --Check units, and get close to them if need be.
		if target~=nil and target['unit']~=nil and target['unit']:GetHealth()~=nil and target['unit']:GetHealth()<lowestLife then
			lowestLife=target['unit']:GetHealth()
			lowestCreep=target['unit']
		end
	end
	core.unitCreepTarget=lowestCreep
	
    --[[
    if (lowestLife>3*minimumDamage and not (oldBehaviour=="Push")) then
        for key, target in pairs(unitArray) do --pull back lane!
            if (target~=nil and target['estimatedHp']~=nil and target['unit']~=nil and target['estimatedHp']>0 and target['unit']:GetPhysicalResistance() ~=nil and target['unit']:GetHealthPercent()*100<50) then
                core.DrawXPosition(target['unit']:GetPosition(), 'silver')
                core.unitCreepTarget=target['unit']
                attacking=true
                return 20--core.OrderMoveToPosClamp(botBrain, unitSelf, target['unit']:GetPosition()) --unitToAttack=unit
            --else
                --return core.OrderHoldClamp(botBrain, unitSelf, false)
            end
        end
    end
    ]]
    return nil
end
object.GetCreepAttackTargetOld = behaviorLib.GetCreepAttackTarget
behaviorLib.GetCreepAttackTarget = KaiGetCreepAttackTargetOverride
  
function GetClosestEnemyHero(botBrain, team)
    local unitClosestHero = nil
    local nClosestHeroDistSq = 99999*99999
    for id, unitHero in pairs(HoN.GetHeroes(core.enemyTeam)) do --HoN.GetHeroes(core.enemyTeam)
        if unitHero ~= nil then
            if core.CanSeeUnit(botBrain, unitHero) and unitHero:GetTeam()~=team and unitHero:IsAlive() then
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

local function HarassHeroUtilityOverride(botBrain)
    return AbilitiesUpUtilityFn() --always important
end
object.harassUtilityOld = behaviorLib.HarassHeroBehavior["Utility"]

timeFacing=0
timeStartedFacing=0
function HarassHeroExecuteOverride(botBrain)
    local unitSelf = core.unitSelf
    local unitTarget = behaviorLib.heroTarget
    if unitTarget==nil then return false end
    --local unitTarget = GetClosestEnemyHero(botBrain, unitSelf:GetTeam())
    object.harassHeroExecuteOld(botBrain)
    local nLastHarassUtility = behaviorLib.lastHarassUtil
    local dist=99999
    dist=Vector3.Distance2DSq(unitSelf:GetPosition(), unitTarget:GetPosition())
    
    --attempt to use hands
    if dist<1000*1000 and unitTarget~=nil and core.CanSeeUnit(botBrain, unitTarget) and unitSelf:GetLevel()>2 and unitTarget:GetHealthPercent()*100<80 and (nLastHarassUtility>20 or unitSelf:GetManaPercent()*100>=50) then
        if timeFacing>300 and timeStartedFacing+timeFacing>HoN.GetGameTime()-300 then
            if (dist>=75*75 and dist<=325*325 and unitSelf:GetAbility(5):CanActivate()) then
                timeFacing=0
                timeStartedFacing=0
                core.OrderAbility(botBrain, unitSelf:GetAbility(5),false,false)
                return core.OrderAttackClamp(botBrain, unitSelf, unitTarget,true)
            elseif (dist>=325*325 and dist<=575*575 and unitSelf:GetAbility(6):CanActivate()) then
                timeFacing=0
                timeStartedFacing=0
                core.OrderAbility(botBrain, unitSelf:GetAbility(6),false,false)
                return core.OrderAttackClamp(botBrain, unitSelf, unitTarget,true)
            elseif (dist>=575*575 and dist<=825*825 and unitSelf:GetAbility(7):CanActivate()) then
                timeFacing=0
                timeStartedFacing=0
                core.OrderAbility(botBrain, unitSelf:GetAbility(7),false,false)
                return core.OrderAttackClamp(botBrain, unitSelf, unitTarget,true)
            end
        else
            if (timeStartedFacing+timeFacing<HoN.GetGameTime()-300) then
                timeStartedFacing=HoN.GetGameTime()
                timeFacing=0
            end
            timeFacing=HoN.GetGameTime()-timeStartedFacing
            return core.OrderAttackClamp(botBrain, unitSelf, unitTarget,true)
        end
    end
    if (unitTarget~=nil and Vector3.Distance2DSq(unitSelf:GetPosition(), unitTarget:GetPosition())<unitSelf:GetAttackRange()*unitSelf:GetAttackRange()) then
        return core.OrderAttackClamp(botBrain, unitSelf, unitTarget)
    end
    return false
end
object.harassHeroExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Utility"] = HarassHeroUtilityOverride
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

function HealAtWellUtilityOverride(botBrain)
    return object.HealAtWellUtilityOld(botBrain)*1.75+(botBrain:GetGold()*8/2000)+ 8-(core.unitSelf:GetManaPercent()*8)
end
object.HealAtWellUtilityOld = behaviorLib.HealAtWellBehavior["Utility"]
behaviorLib.HealAtWellBehavior["Utility"] = HealAtWellUtilityOverride

----------------------------------
--  RetreatFromThreat Override
----------------------------------
object.nRetreatStealthThreshold = 50

--Unfortunately this utility is kind of volatile, so we basically have to deal with util spikes
function funcRetreatFromThreatExecuteOverride(botBrain)
	local bDebugEchos = false
	local bActionTaken = false
	if bDebugEchos then BotEcho("Checkin Shroud") end
	if not bActionTaken then
		local itemStealth = core.itemStealth
		if itemStealth and itemStealth:CanActivate() then
			if bDebugEchos then BotEcho("CanActivate!  nRetreatUtil: "..behaviorLib.lastRetreatUtil.."  thresh: "..object.nRetreatStealthThreshold) end
			if behaviorLib.lastRetreatUtil >= object.nRetreatStealthThreshold then
				if bDebugEchos then BotEcho("UsinShroud") end
				bActionTaken = core.OrderItemClamp(botBrain, core.unitSelf, itemStealth)
			end
		end
	end

	if not bActionTaken then
		return object.RetreatFromThreatExecuteOld(botBrain)
	end
end
object.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatExecute
behaviorLib.RetreatFromThreatBehavior["Execute"] = funcRetreatFromThreatExecuteOverride

----------------------------------
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)
	local bUpdated = object.FindItemsOld(botBrain)
	if core.itemStealth ~= nil and not core.itemStealth:IsValid() then
		core.itemStealth = nil
	end
	if bUpdated then
		--only update if we need to
		if core.itemStealth then
			return
		end
		local inventory = core.unitSelf:GetInventory(true)
		for slot = 1, 12, 1 do
			local curItem = inventory[slot]
			if curItem then
				if core.itemStealth == nil and curItem:GetName() == "Item_Stealth" then
					core.itemStealth = core.WrapInTable(curItem)
					break
				end
			end
		end
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride



----------------------------------
--  SkillStealer items
----------------------------------
behaviorLib.StartingItems = {"2 Item_DuckBoots", "2 Item_MinorTotem", "Item_HealthPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = {"Item_Marchers", "Item_IronShield"}
behaviorLib.MidItems = {"Item_Steamboots", "Item_Stealth"} --Immunity is Shrunken Head
behaviorLib.LateItems = {"Item_Immunity", "Item_Evasion", "Item_BehemothsHeart", 'Item_Damage9'} --Item_Damage9 is Doombringer

BotEcho('finished loading skillstealer_main')