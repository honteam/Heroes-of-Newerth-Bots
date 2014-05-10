--AmunRaBot v1.0

-- By community member St0l3n_ID


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

BotEcho(object:GetName()..' loading amunra_main...')

object.heroName = 'Hero_Ra'

function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)
	
	if core.unitSelf:IsAlive() then
		-- UltUp, used for different death & respawn chat
		-- also used of different tresholds and values
		local abilRebirth = skills.abilRebirth
		if abilRebirth then
			self:updateAbilityTables(abilRebirth:CanActivate())
		end
	end
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 2, ShortSolo = 4, LongSolo = 3, ShortSupport = 2, LongSupport = 2, ShortCarry = 5, LongCarry = 5}

--------------------------------
-- Skills
--------------------------------
function object:SkillBuild()
	local unitSelf = self.core.unitSelf
	if  skills.abilMeteor == nil then
		skills.abilMeteor = unitSelf:GetAbility(0)
		skills.abilIgnite = unitSelf:GetAbility(1)
		skills.abilAshes = unitSelf:GetAbility(2)
		skills.abilRebirth = unitSelf:GetAbility(3)
		skills.abilAttributeBoost = unitSelf:GetAbility(4)
	end
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	
	-- automatically levels stats in the end
	-- stats have to be leveld manually if needed inbetween
	tSkills ={
				0, 2, 1, 2, 0,
				3, 0, 0, 2, 2,
				3, 1, 1, 1, 4,
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

---------------------------------------------------
--             Weight-Overrides                  --
---------------------------------------------------
--behaviorLib.recentDamageMul = 0.65

behaviorLib.nCreepPushbackMul = 0.5 --1
behaviorLib.nTargetPositioningMul = 3 --0.6
behaviorLib.nTargetCriticalPositioningMul = 1 --2


----------------------------------
--	Amun-Ra special harass behavior
--
--  Abilities off cd increase harass util (especially in combination)
--  Ability use increases harass util pretty much, until impact/explode
--	(to make sure he tries to hit target)
--  Ashes adds a slight bonus to the util
----------------------------------
object.bUltWasUpLately = false
object.enemyLastHPPerc = 100

object.tAbilityValuesNoUlt = {
	-- 'Abilities are up and ready to go'-utils
	nRebirthUp = 0, -- not possible ;)
	nMeteorUp = 35,
	nIgniteUp = 20,

	-- 'Use' means that fuse time isnt finished yet (will explode soon)
	nMeteorUse = 70,
	nIgniteUse = 70,
	nAshesActive = 5,

	--when to activate my abilities/combo
	nMeteorThreshold = 35, --lower cause of heal
	nIgniteThreshold = 50,

	nMeteorHpThreshold = 50, --lower cause of heal
	nIgniteCCHpThreshold = 52
	--nIgniteHpThreshold = 60
	}
	
-- hahaha yeah, implemented this whole new table stuff
-- you didnt think i wouldn't use it yet huh? :D
-- will mostly change hp-tresholds anyway (how much hp needed to activate abilities)
object.tAbilityValuesUlt = { 
	nRebirthUp = 15,
	nMeteorHpThreshold = 40,
	nIgniteCCHpThreshold = 46
	}
object.tAbilityValues = object.tAbilityValuesNoUlt
object.tAbilityValuesCreeps = { --seperate tresholds for creeps
	nMeteorHpThreshold = 53, 
	nIgniteCCHpThreshold = 58
	}


--checking charges etc... we'll see, wont work i guess
object.nAshesExpireTime = 0
object.sAshesStateName = "State_Ra_Ability3"

object.nMeteorFuseTime = 0
object.nIgniteFuseTime = 0


-- Three key factors:
-- Ult up?
-- Meteor up or fusing
-- Ignite up or fusing
--  
--	Goal:
--	Different behavior while ult is up/down (and mana for it is given in forseeable time)
--	If both Meteor and Ignite are up, or one of both fusing -> more aggressive
--	
--	Todo: Ultimate should maybe check for possible mana drains, that might not be done here
function object:oncombateventOverride(EventData)
	local bDebugEchos = false
	
	if bDebugEchos then BotEcho(format("Ra - source: %s  target: %s  self: %s", tostring(EventData.SourceUnit), tostring(EventData.TargetUnit), tostring(core.unitSelf.object))) end
	if EventData.Type == "Damage" and EventData.SourceUnit == core.unitSelf.object then 
		if bDebugEchos then BotEcho('	Ouch, hurt myself: '..EventData.DamageAttempted) end
		--ignore
	else
		self:oncombateventOld(EventData)
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent 	= object.oncombateventOverride


---------------------------------------------------
--            Util Calculation                   --
---------------------------------------------------
-- returns bool, depeding if treshhold (%) is reached or not
local function ShouldAttackHpBased(givenSelf, tresholdPerc)
	return givenSelf:GetHealthPercent() >= tresholdPerc*0.01  --.--/100
end

-- increase weight/util if abilties are up
local function AbilitiesUpUtilityFn(hero)
	local bDebugEchos = false
	local unitSelf = core.unitSelf
	local val = 0
	
	if ShouldAttackHpBased(unitSelf, 0.4*(object.tAbilityValues.nIgniteCCHpThreshold + object.tAbilityValues.nMeteorHpThreshold) ) then
		if skills.abilMeteor:CanActivate() then
			val = val + object.tAbilityValues.nMeteorUp
		end
		
		if skills.abilIgnite:CanActivate() then
			val = val + object.tAbilityValues.nIgniteUp
		end
	end
	
	if bDebugEchos then BotEcho(" HARASS - abilitiesUp: "..val) end
	
	return val
end

--Further increase weight/util if ignite or meteor are actiavted and didnt take effect yet
local function MeteorActiveUtility()
	local nUtility = 0
	if object.nMeteorFuseTime > HoN.GetGameTime() then
		nUtility = object.tAbilityValues.nMeteorUse
	end
	return nUtility
end
local function IgniteActiveUtility()
	local nUtility = 0
	if object.nIgniteFuseTime > HoN.GetGameTime() then
		nUtility = object.tAbilityValues.nIgniteUse
	end
	
	return nUtility
end

--Util calc override
local function CustomHarassUtilityFnOverride(hero)
	local util = 0
	
	--rebirth
	if skills.abilRebirth:CanActivate() then
		util = util + object.tAbilityValues.nRebirthUp
	end
	
	util = util + AbilitiesUpUtilityFn(hero) + MeteorActiveUtility() + IgniteActiveUtility()
	
	return util
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride   


--------------------------------------------------
--	Amun harass actions	 and special functions  --
--------------------------------------------------

-- This is for using diffrent tables, gonna see how this string key system will or will not fuck up the performance
local function createAbilityValues()
	for k, v in pairs(object.tAbilityValues)
	do
		if object.tAbilityValuesUlt[k] == nil
		then
			object.tAbilityValuesUlt[k] = v
		end
		if object.tAbilityValuesCreeps[k] == nil
		then
			object.tAbilityValuesCreeps[k] = v
		end
	end
end
createAbilityValues() -- the whole reason for this is to save lazy programmers (stolen id) the redudancy of typing same values again


--Instead of using sytem above, we now swap tables if the ultimates state changes, that should be healthier for both eyes and brain
object.bUltWasUpLately  = false -- also used for chat
function object:updateAbilityTables(bUltUp)
	if bUltUp ~= self.bUltWasUpLately then
		if bUltUp then 
			self.tAbilityValues = self.tAbilityValuesUlt
		else 
			self.tAbilityValues = self.tAbilityValuesNoUlt
		end
		self.bUltWasUpLately = bUltUp
		
		--BotEcho('Updated AbilityValues as bUltUp was: '..tostring(bUltUp))
	end
end


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
createRelativeMovementTable("RaMeteor") -- for harrass meteor
createRelativeMovementTable("CreepPush") -- for creep-groups while pushing (meteor)

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


---------------------------------
-- Activate Abilties Functions --
---------------------------------

-- Path of destruction aka Meteor
local function activateMeteor(botBrain, TargetPos, debugEcho)
	if debugEcho == nil then debugEcho = false end
	local unitSelf = core.unitSelf
	
	object.nMeteorFuseTime = HoN.GetGameTime() + 1500  -- meteor need 0.4 cast time + about 1.5 seconds to strike

	
	
	local succeeded = core.OrderAbilityPosition(botBrain, skills.abilMeteor, TargetPos)
	if succeeded then core.OrderAttackPosition(botBrain, unitSelf, TargetPos, false, true) end
	if debugEcho then BotEcho('Activated Meteor') end
	return succeeded
end

-- Ignite, (flint + stone = ignites)
local function activateIgnite(botBrain, q)
	core.OrderAbility(botBrain, skills.abilIgnite, false, q)
	object.nIgniteFuseTime = HoN.GetGameTime() + 2000  -- 0.4 cast + 1.5 fuse + a bit extra to autoattack
end


--------------------------------
--     Harass Behavior        --
--------------------------------
local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = false
	local bDebugMeteorPrediction = false
	local bDebugMeteorAngle = false
	local meteorcolor = "white"
	
	
	
	-- moved unitTarget definition here, as its better for cpu if he isnt nil
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
		return false --can not execute, move on to the next behavior
	end
	
	object.enemyLastHPPerc = unitTarget:GetHealthPercent()
	
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition() 
	local nAttackRange = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
	local nMyExtraRange = core.GetExtraRange(unitSelf)
	
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetExtraRange = core.GetExtraRange(unitTarget)
	local nTargetDistance = Vector3.Distance2D(vecMyPosition, vecTargetPosition)
	
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)	
	local bActionTaken = false
	
	if bDebugEchos then BotEcho("AmunRa HarassHero at "..nLastHarassUtility) end
	
	-- this needs to be called every cycle to ensure up to date values for relative movement
	local nPredictMeteor = 10
	local relativeMov = relativeMovement("RaMeteor", vecTargetPosition) * nPredictMeteor
	
	
	-- Explanation: 5 is about exactly how far heroes move while meteor
	-- however having ra aim at 4 gives a chance of hitting while enemy tries to dodge
	-- the  abilitiy radius  is big enough to accomplish both  :)
	-- Check Meteor
	if not bActionTaken and nLastHarassUtility > object.tAbilityValues.nMeteorThreshold and skills.abilMeteor:CanActivate() then
		if bDebugEchos then BotEcho("  No action yet, checking meteor") end

		if ShouldAttackHpBased(unitSelf, object.tAbilityValues.nMeteorHpThreshold) then
			if bDebugEchos then BotEcho("I'm able to activate") end
			
			local abilMeteor = skills.abilMeteor
			local nRange = abilMeteor:GetRange()
			local nVaryMeteor = abilMeteor:GetTargetRadius() - 70 --instead of 250, more costy, but safe for HoN updates
			
			if  core.CanSeeUnit(botBrain, unitTarget) then -- Do moving-to prediction defined above
				local newDistance = Vector3.Distance2D(vecMyPosition, (vecTargetPosition+relativeMov))
				
				-- this tells us if the object is moving torwards us (to prevent stuns if enemy approaches us)
				-- angles should be somewhat ~1.6 is sidewards, ~3.14 is away, 0 is directly approaching us (radian)
				local nAngle = core.AngleBetween(	vecMyPosition-vecTargetPosition,   
													relativeMov)
				if not (nAngle < 0.25 and  nTargetDistance < 900) then
					if nRange -nVaryMeteor < newDistance and newDistance < nRange + nVaryMeteor then
						if bDebugEchos then BotEcho("Checking predicted Range was valid") end
						bActionTaken = activateMeteor(botBrain, vecTargetPosition+relativeMov, bDebugEchos)
					end
				end
			elseif nRange - nVaryMeteor < nTargetDistance and nTargetDistance < nRange + nVaryMeteor then -- cant see, so we guess with build in prediction 'GetPosition()'
				if bDebugEchos then BotEcho("Checking standard Range was valid") end
				bActionTaken = activateMeteor(botBrain, vecTargetPosition, bDebugEchos)
			end
		end
		
		if bDebugMeteorPrediction then
			local abilMeteor = skills.abilMeteor
			local nRange = abilMeteor:GetRange()
			local nVaryMeteor = abilMeteor:GetTargetRadius() - 70 
			local newDistance = Vector3.Distance2D(vecMyPosition, (vecTargetPosition+relativeMov))
			
			if nRange -nVaryMeteor > nTargetDistance then 
				meteorcolor = "red"
			elseif nTargetDistance < nRange+nVaryMeteor then 
				meteorcolor = "orange"
			end
		end
	end
	
	
	
	--ignite melee
	if not bActionTaken and ShouldAttackHpBased(unitSelf, object.tAbilityValues.nIgniteCCHpThreshold) and nLastHarassUtility > object.tAbilityValues.nIgniteThreshold then
		if bDebugEchos then BotEcho("  No action yet, checking ignite cc") end
		local abilIgnite = skills.abilIgnite
		--activate when just out of melee range of target
		if abilIgnite:CanActivate() and nTargetDistance < nAttackRange * 1.25 then
			bActionTaken = activateIgnite(botBrain, false, bDebugEchoes)
		end
	end
	
	
	
	
	if bDebugMeteorAngle  then
		core.DrawDebugArrow(unitTarget:GetPosition(), unitSelf:GetPosition(), "red")
		core.DrawDebugArrow(unitTarget:GetPosition(), vecTargetPosition+relativeMov, "green")
	end
	
	if bDebugMeteorPrediction  then
		core.DrawDebugArrow( unitSelf:GetPosition(), unitTarget:GetPosition(), meteorcolor)
		core.DrawXPosition( (vecTargetPosition + relativeMov), "purple", 200)
	end
	
	
	if not bActionTaken then
		if bDebugEchos then BotEcho("  No action yet, proceeding with normal harass execute.") end
		return object.harassExecuteOld(botBrain)
	end 
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride



----------------------------------
--	Amun specific push - no changes yet
----------------------------------

 -- Raa ignores healing on well in certain cases
local function HealAtWellUtilityOverride(botBrain)
	--BotEcho('!!!!!!!!!!!!!!! Last Enemy health: '..tostring(object.enemyLastHPPerc))
	
	local unitSelf = core.unitSelf  -- below code should someday loose his percent affection
	local bRebirthUp = skills.abilRebirth:CanActivate()
	local bAmHarassing = (core.GetCurrentBehaviorName(botBrain) == behaviorLib.HarassHeroBehavior["Name"])
		
	if bRebirthUp and bAmHarassing then
		return 0
	else 
		return object.HealAtWellUtilityOld(botBrain)
	end
end
object.HealAtWellUtilityOld = behaviorLib.HealAtWellBehavior["Utility"]
behaviorLib.HealAtWellBehavior["Utility"] = HealAtWellUtilityOverride


local function PushingStrengthUtilOverride(myHero)
	local util = 0
	
	local nDPSUtility = DPSPushingUtilFn(myHero) * object.nDPSPushWeight
	
	local util = nDPSUtility 
	
	util = Clamp(util, 0, 100)

	return util
end
behaviorLib.PushingStrengthUtilFn = PushingStrengthUtilOverride


-- This function allowes ra to use his ability while pushing
-- Has prediction, however it might need some repositioning so he is in correct range more often
local function abilityPush(botBrain, unitSelf)
	local debugAbilityPush = false
	local myPos = unitSelf:GetPosition()
	local nMinimumCreeps = 3
	local vecCreepCenter, nCreeps = core.GetGroupCenter(core.localUnits["EnemyCreeps"])
	
	--BotEcho(tostring(vecCreepCenter).."  #: "..nCreeps)
	
	if vecCreepCenter == nil or nCreeps < nMinimumCreeps then 
		return false
	end
	
	local vMovePrediction = vecCreepCenter + relativeMovement("CreepPush", vecCreepCenter)*10
			
	if debugAbilityPush  then -- to compare prediction vs normal center	
		core.DrawDebugArrow(myPos, vMovePrediction "purple")		
		core.DrawDebugArrow(myPos, vecCreepCenter, "white")
	end
	
	local abilMeteor = skills.abilMeteor
	local nDistanceSq = Vector3.Distance2DSq(myPos,vMovePrediction)
	
	if  abilMeteor:CanActivate() and ShouldAttackHpBased(unitSelf, object.tAbilityValuesCreeps.nMeteorHpThreshold) then 
		--using kinda same hp-tresholds as we do against heroes
		local nMaxRange = abilMeteor:GetRange() + 150
		local nMinRange = abilMeteor:GetRange() - 150
		
		if  nDistanceSq < (nMaxRange * nMaxRange) and nDistanceSq > (nMinRange * nMinRange) then --range check for meteor push
			return activateMeteor(botBrain, vecCreepCenter, debugAbilityPush)
		end
	end
	
	
	local abilIgnite = skills.abilIgnite
	local nAttackRange = unitSelf:GetAttackRange()+core.GetExtraRange(unitSelf)
	if abilIgnite:CanActivate() and nDistanceSq <= (nAttackRange * nAttackRange) and ShouldAttackHpBased(unitSelf, object.tAbilityValuesCreeps.nIgniteCCHpThreshold) then
		return activateIgnite(botBrain, true, debugAbilityPush)
	end
	
	return false
end

--this is a good function to override to help push
function behaviorLib.customPushExecute(botBrain)
	local debugPushLines = false
	if debugPushLines then BotEcho('^yGotta execute em *greedy*') end
	
	local bSuccess = false
		
	local unitSelf = core.unitSelf
	if unitSelf:IsChanneling() then 
		return
	end

	local unitTarget = core.unitEnemyCreepTarget
	if unitTarget then
		bSuccess = abilityPush(botBrain, unitSelf)
		if debugPushLines then 
			BotEcho('^p-----------------------------Got em')
			if bSuccess then BotEcho('Gotemhard') else BotEcho('at least i tried') end
		end
	end
	
	return bSuccess
end



---------------------------------------------------------------
--- Custom Chat override functions                           --
---------------------------------------------------------------

-- Death
local function ProcessDeathChatOverride(unitSource, sSourcePlayerName)
	-- excluding chat completly on ult
	if not object.bUltWasUpLately then 
		object.ProcessDeathChatOld(unitSource, sSourcePlayerName) 
	end
end
object.ProcessDeathChatOld = core.ProcessDeathChat
core.ProcessDeathChat = ProcessDeathChatOverride


-- Kills
object.killMessages = {}
object.killMessages.General = {
	"stolenid_ra_kill1",
	"stolenid_ra_kill2",
	"stolenid_ra_kill3",
	"stolenid_ra_kill4",
	"stolenid_ra_kill5",
	"stolenid_ra_kill6"	}
	
object.killMessages.Hero_Deadwood 		= { "stolenid_ra_deadwood1" }
object.killMessages.Hero_Frosty			= { "stolenid_ra_frosty1",
						    "stolenid_ra_frosty2" }
object.killMessages.Hero_Treant			= { "stolenid_ra_treant1",
						    "stolenid_ra_treant2" }
object.killMessages.Hero_Mumra			= { "stolenid_ra_mumra" }
object.killMessages.Hero_Rocky			= { "stolenid_ra_rocky" }
object.killMessages.Hero_Pyromancer		= { "stolenid_ra_pyromancer1",
						    "stolenid_ra_pyromancer2" }
object.killMessages.Hero_Zephyr			= { "stolenid_ra_zephyr1",
						    "stolenid_ra_zephyr2" }

local function GetKillKeysOverride(unitTarget)
	local tChatKeys = object.funcGetKillKeysOld(unitTarget)
	core.InsertToTable(tChatKeys, object.killMessages.General)
	return tChatKeys
end
object.funcGetKillKeysOld = core.GetKillKeys
core.GetKillKeys = GetKillKeysOverride

local function ProcessKillChatOverride(unitTarget, sTargetPlayerName)
	local nCurrentTime = HoN.GetGameTime()
	if nCurrentTime < core.nNextChatEventTime then
		return
	end	
	
	local nToSpamOrNotToSpam = random()
	--BotEcho(unitTarget:GetTypeName())
		
	if(nToSpamOrNotToSpam < core.nKillChatChance) then
		local nDelay = random(core.nChatDelayMin, core.nChatDelayMax) 
		local tHeroMessages = object.killMessages[unitTarget:GetTypeName()]
		
		local sMessage = nil
		-- about a third of the time we actually chat, we want to use hero specific ones (if there are any)
		if tHeroMessages ~= nil and random() <= 0.7 then 
			local nMessage = random(#tHeroMessages)
			sMessage = tHeroMessages[nMessage]
			
			local sTargetName = sTargetPlayerName or unitTarget:GetDisplayName()
			if sTargetName == nil or sTargetName == "" then
				sTargetName = unitTarget:GetTypeName()
			end
			
			core.AllChatLocalizedMessage(sMessage, {target=sTargetName}, nDelay)
		else
			object.funcProcessKillChatOld(unitTarget, sTargetPlayerName)
			return
		end		
	end
	
	core.nNextChatEventTime = nCurrentTime + core.nChatEventInterval
end
object.funcProcessKillChatOld = core.ProcessKillChat
core.ProcessKillChat = ProcessKillChatOverride

-- Respawn
object.respawnUltMessages = {
	"stolenid_ra_ult_respawn1",
	"stolenid_ra_ult_respawn2",
	"stolenid_ra_ult_respawn3",
	"stolenid_ra_ult_respawn4",
	"stolenid_ra_ult_respawn5",
	"stolenid_ra_ult_respawn6"	}
	
object.tCustomRespawnKeys = {
	"stolenid_ra_respawn1",
	"stolenid_ra_respawn2",
	"stolenid_ra_respawn3",
	"stolenid_ra_respawn4"	}

local function GetRespawnKeysOverride()
	local tChatKeys = object.funcGetRespawnKeysOld()
	core.InsertToTable(tChatKeys, object.tCustomRespawnKeys)
	return tChatKeys
end
object.funcGetRespawnKeysOld = core.GetRespawnKeys
core.GetRespawnKeys = GetRespawnKeysOverride
	
local function ProcessRespawnChatOverride()
	local nCurrentTime = HoN.GetGameTime()	
	if nCurrentTime < core.nNextChatEventTime then
		return
	end	
	
	if HoN.GetMatchTime() > 0 then
		local nDelay = random(core.nChatDelayMin, core.nChatDelayMax) 
		local sMessage = nil
		
		if object.bUltWasUpLately then
			local nMessage = random(#object.respawnUltMessages) 
			sMessage = object.respawnUltMessages[nMessage]
			nDelay = 200
			
			core.AllChatLocalizedMessage(sMessage, nil, nDelay)
		else
			object.funcProcessRespawnChatOld()
			return
		end
	else 
		core.AllChat("HF 'n GL")
	end
	
	core.nNextChatEventTime = nCurrentTime + core.nChatEventInterval
end
object.funcProcessRespawnChatOld = core.ProcessRespawnChat
core.ProcessRespawnChat = ProcessRespawnChatOverride


----------------------------------
--	Raaaa items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
behaviorLib.StartingItems = {"Item_IronBuckler", "Item_HealthPotion", "Item_RunesOfTheBlight"} -- following St0l3n_IDs Amun Ra aggressive guide 2 for now :P
behaviorLib.LaneItems = {"Item_MysticVestments", "Item_Marchers", "Item_TrinketOfRestoration", "Item_Lifetube"}
behaviorLib.MidItems = {"Item_Steamboots", "Item_Shield2", "Item_MagicArmor2"} --Item_Shield2 is helm of the black legion || hotbl; Item_MagicArmor2 is shamans headress
behaviorLib.LateItems = {"Item_BehemothsHeart", "Item_Damage10", "Item_Weapon3", "Item_DaemonicBreastplate", "Item_Damage9"} --Item_Damage9 is doombringer, ...10 is mock, weapon3 is savage mace


BotEcho(object:GetName()..' finished loading amunra_main')

