-- behaviorLib v1.0


local _G = getfenv(0)
local object = _G.object

object.behaviorLib = object.behaviorLib or {}
local core, eventsLib, behaviorLib, metadata = object.core, object.eventsLib, object.behaviorLib, object.metadata

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local nSqrtTwo = math.sqrt(2)

behaviorLib.tBehaviors = {}
behaviorLib.nNextBehaviorTime = HoN.GetGameTime()
behaviorLib.nBehaviorAssessInterval = 250

local BotEcho, VerboseLog, Clamp = core.BotEcho, core.VerboseLog, core.Clamp



---------------------------------------------------
--             Common Complex Logic              --
---------------------------------------------------

----------------------------------
--	PositionSelfLogic
----------------------------------
behaviorLib.nHeroInfluencePercent = 0.75
behaviorLib.nPositionHeroInfluenceMul = 4.0
behaviorLib.nCreepPushbackMul = 1
behaviorLib.nTargetPositioningMul = 1
behaviorLib.nTargetCriticalPositioningMul = 2

behaviorLib.nLastPositionTime = 0
behaviorLib.vecLastDesiredPosition = Vector3.Create()
behaviorLib.nPositionSelfAllySeparation = 250
behaviorLib.nAllyInfluenceMul = 1.5
function behaviorLib.PositionSelfCreepWave(botBrain, unitCurrentTarget)
	local bDebugLines = false
	local bDebugEchos = false
	local nLineLen = 150

	--if botBrain.myName == "ShamanBot" then bDebugLines = true bDebugEchos = true end

	if bDebugEchos then BotEcho("PositionCreepWave") end

	--Vector-based relative position logic
	local unitSelf = core.unitSelf
	
	--Don't run our calculations if we're basically in the same spot
	if unitSelf.bIsMemoryUnit and unitSelf.storedTime == behaviorLib.nLastPositionTime then
		--BotEcho("early exit")
		return behaviorLib.vecLastDesiredPosition
	end
	
	local vecMyPos = unitSelf:GetPosition()
	local tLocalUnits = core.localUnits
	
	--Local references for improved performance
	local nHeroInfluencePercent = behaviorLib.nHeroInfluencePercent
	local nPositionHeroInfluenceMul = behaviorLib.nPositionHeroInfluenceMul
	local nCreepPushbackMul = behaviorLib.nCreepPushbackMul
	local vecLaneForward = object.vecLaneForward
	local vecLaneForwardOrtho = object.vecLaneForwardOrtho
	local funcGetThreat  = behaviorLib.GetThreat
	local funcGetDefense = behaviorLib.GetDefense
	local funcLethalityUtility = behaviorLib.LethalityDifferenceUtility
	local funcDistanceThreatUtility = behaviorLib.DistanceThreatUtility
	local funcGetAbsoluteAttackRangeToUnit = core.GetAbsoluteAttackRangeToUnit
	local funcV3Normalize = Vector3.Normalize
	local funcV3Dot = Vector3.Dot
	local funcAngleBetween = core.AngleBetween
	local funcRotateVec2DRad = core.RotateVec2DRad	
	
	local nMyThreat =  funcGetThreat(unitSelf)
	local nMyDefense = funcGetDefense(unitSelf)
	local vecBackUp = behaviorLib.PositionSelfBackUp()
	
	
	local nExtraThreat = 0.0
	if unitSelf:HasState("State_HealthPotion") then
		if unitSelf:GetHealthPercent() < 0.95 then
			nExtraThreat = 10.0
		end
	end
	
	--Stand appart from enemies
	local vecTotalEnemyInfluence = Vector3.Create()
	local tEnemyUnits = core.CopyTable(tLocalUnits.EnemyUnits)
	core.teamBotBrain:AddMemoryUnitsToTable(tEnemyUnits, core.enemyTeam, vecMyPos)
	
	StartProfile('Loop')
	for nUID, unitEnemy in pairs(tEnemyUnits) do
		StartProfile('Setup')
		local bIsHero = unitEnemy:IsHero()
		local vecEnemyPos = unitEnemy:GetPosition()
		local vecTheirRange = funcGetAbsoluteAttackRangeToUnit(unitEnemy, unitSelf)
		local vecTowardsMe, nEnemyDist = funcV3Normalize(vecMyPos - vecEnemyPos)
		
		local nDistanceMul = funcDistanceThreatUtility(nEnemyDist, vecTheirRange, unitEnemy:GetMoveSpeed(), false) / 100
		
		local vecEnemyInfluence = Vector3.Create()
		StopProfile()

		if not bIsHero then
			StartProfile('Creep')
			
			--stand away from creeps
			if bDebugEchos then BotEcho('  creep unit: ' .. unitEnemy:GetTypeName()) end
			vecEnemyInfluence = vecTowardsMe * (nDistanceMul + nExtraThreat)

			StopProfile()
		else
			StartProfile('Hero')
			
			--stand away from enemy heroes
			if bDebugEchos then BotEcho('  hero unit: ' .. unitEnemy:GetTypeName()) end
			local vecHeroDir = vecTowardsMe

			local vecBackwards = funcV3Normalize(vecBackUp - vecMyPos)
			vecHeroDir = vecHeroDir * nHeroInfluencePercent + vecBackwards * (1 - nHeroInfluencePercent)

			--Calculate their lethality utility
			local nThreat = funcGetThreat(unitEnemy)
			local nDefense = funcGetDefense(unitEnemy)
			local nLethalityDifference = (nThreat - nMyDefense) - (nMyThreat - nDefense) 
			local nBaseMul = 1 + (Clamp(funcLethalityUtility(nLethalityDifference), 0, 100) / 50)
			local nLength = nBaseMul * nDistanceMul
			
			vecEnemyInfluence = vecHeroDir * nLength * nPositionHeroInfluenceMul			
			StopProfile()
		end
		
		StartProfile('Common')
		
		--enemies should not push you forward, flip it across the orthogonal line
		if vecLaneForward and funcV3Dot(vecEnemyInfluence, vecLaneForward) > 0 then
			local vecX = Vector3.Create(1,0)
			local nLaneOrthoAngle = funcAngleBetween(vecLaneForwardOrtho, vecX)

			local nInfluenceOrthoAngle = funcAngleBetween(vecEnemyInfluence, vecLaneForwardOrtho)

			local vecRelativeInfluence = funcRotateVec2DRad(vecEnemyInfluence, -nLaneOrthoAngle)
			if vecRelativeInfluence.y < 0 then
				nInfluenceOrthoAngle = -nInfluenceOrthoAngle
			end

			vecEnemyInfluence = funcRotateVec2DRad(vecEnemyInfluence, -nInfluenceOrthoAngle*2)
			--core.DrawDebugArrow(creepPos, creepPos + vecFlip * nLineLen, 'blue')
		end
		
		if not bIsHero then
			vecEnemyInfluence = vecEnemyInfluence * nCreepPushbackMul
		end

		--vecTotalEnemyInfluence.AddAssign(vecEnemyInfluence)
		vecTotalEnemyInfluence = vecTotalEnemyInfluence + vecEnemyInfluence

		if bDebugLines then core.DrawDebugArrow(vecEnemyPos, vecEnemyPos + vecEnemyInfluence * nLineLen, 'teal') end
		if bDebugEchos and unitEnemy then BotEcho(unitEnemy:GetTypeName()..': '..tostring(vecEnemyInfluence)) end
		
		StopProfile()
	end

	--stand appart from allies a bit
	local vecTotalAllyInfluence = Vector3.Create()
	local bEnemyTeamHasHuman = false
	local tEnemyHeroes = core.teamBotBrain.tEnemyHeroes
	for _, unitHero in pairs(tEnemyHeroes) do
		if not unitHero:IsBotControlled() then
			bEnemyTeamHasHuman = true
			break
		end
	end
	if core.nDifficulty ~= core.nEASY_DIFFICULTY or not bEnemyTeamHasHuman then
		StartProfile('Allies')
		local tAllyHeroes = tLocalUnits.AllyHeroes
		local nAllyInfluenceMul = behaviorLib.nAllyInfluenceMul
		local nPositionSelfAllySeparation = behaviorLib.nPositionSelfAllySeparation
		for nUID, unitAlly in pairs(tAllyHeroes) do
			local vecAllyPos = unitAlly:GetPosition()
			local vecCurrentAllyInfluence, nDistance = funcV3Normalize(vecMyPos - vecAllyPos)
			if nDistance < nPositionSelfAllySeparation then
				vecCurrentAllyInfluence = vecCurrentAllyInfluence * (1 - nDistance/nPositionSelfAllySeparation) * nAllyInfluenceMul
				
				--vecTotalAllyInfluence.AddAssign(vecCurrentAllyInfluence)
				vecTotalAllyInfluence = vecTotalAllyInfluence + vecCurrentAllyInfluence
				
				if bDebugLines then core.DrawDebugArrow(vecMyPos, vecMyPos + vecCurrentAllyInfluence * nLineLen, 'white') end
			end
		end
		StopProfile()
	end

	--stand near your target
	StartProfile('Target')
	local vecTargetInfluence = Vector3.Create()
	local nTargetMul = behaviorLib.nTargetPositioningMul
	if unitCurrentTarget ~= nil and botBrain:CanSeeUnit(unitCurrentTarget) then
		local nMyRange = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitCurrentTarget)
		local vecTargetPosition = unitCurrentTarget:GetPosition()
		local vecToTarget, nTargetDist = funcV3Normalize(vecTargetPosition - vecMyPos)
		local nLength = 1
		if not unitCurrentTarget:IsHero() then
			nLength = nTargetDist / nMyRange
			if bDebugEchos then BotEcho('  nLength calc - nTargetDist: '..nTargetDist..'  nMyRange: '..nMyRange) end
		end

		nLength = Clamp(nLength, 0, 25)

		--Hack: get closer if they are critical health and we are out of nRange
		if unitCurrentTarget:GetHealth() < (core.GetFinalAttackDamageAverage(unitSelf) * 3) then --and nTargetDist > nMyRange then
			nTargetMul = behaviorLib.nTargetCriticalPositioningMul
		end
		
		vecTargetInfluence = vecToTarget * nLength * nTargetMul
		if bDebugEchos then BotEcho('  target '..unitCurrentTarget:GetTypeName()..': '..tostring(vecTargetInfluence)..'  nLength: '..nLength) end
	else 
		if bDebugEchos then BotEcho("PositionSelfCreepWave - target is nil") end
	end
	StopProfile()

	--sum my influences
	local vecDesiredPos = vecMyPos
	local vecDesired = vecTotalEnemyInfluence + vecTargetInfluence + vecTotalAllyInfluence
	local vecMove = vecDesired * core.moveVecMultiplier

	if bDebugEchos then BotEcho('vecDesiredPos: '..tostring(vecDesiredPos)..'  vCreepInfluence: '..tostring(vecTotalEnemyInfluence)..'  vecTargetInfluence: '..tostring(vecTargetInfluence)) end

	--minimum move distance threshold
	if Vector3.LengthSq(vecMove) >= core.distSqTolerance then
		vecDesiredPos = vecDesiredPos + vecMove
	end
	
	behaviorLib.nLastPositionTime = unitSelf.storedTime
	behaviorLib.vecLastDesiredPosition = vecDesiredPos

	--debug
	if bDebugLines then
		if vecLaneForward then
			local offset = vecLaneForwardOrtho * (nLineLen * 3)
			core.DrawDebugArrow(vecMyPos + offset, vecMyPos + offset + vecLaneForward * nLineLen, 'white')
			core.DrawDebugArrow(vecMyPos - offset, vecMyPos - offset + vecLaneForward * nLineLen, 'white')
		end

		core.DrawDebugArrow(vecMyPos, vecMyPos + vecTotalEnemyInfluence * nLineLen, 'cyan')

		if unitCurrentTarget ~= nil and botBrain:CanSeeUnit(unitCurrentTarget) then
			local color = 'cyan'
			if nTargetMul ~= behaviorLib.nTargetPositioningMul then
				color = 'orange'
			end
			core.DrawDebugArrow(vecMyPos, vecMyPos + vecTargetInfluence * nLineLen, color)
		end

		core.DrawXPosition(vecDesiredPos, 'blue')

		core.DrawDebugArrow(vecMyPos, vecMyPos + vecDesired * nLineLen, 'blue')
		--core.DrawDebugArrow(vecMyPos, vecMyPos + vProjection * nLineLen)
	end

	return vecDesiredPos
end

function behaviorLib.PositionSelfTraverseLane(botBrain)
	local bDebugLines = false
	local bDebugEchos = false

	--if botBrain.myName == 'ShamanBot' then bDebugEchos = true bDebugLines = true end

	local myPos = core.unitSelf:GetPosition()
	local desiredPos = nil
	if bDebugEchos then BotEcho("In PositionSelfTraverseLane") end
	local tLane = core.tMyLane
	if tLane then
		local vecFurthest = core.GetFurthestCreepWavePos(tLane, core.bTraverseForward)
		if vecFurthest then
			desiredPos = vecFurthest
		else
			if bDebugEchos then BotEcho("PositionSelfTraverseLane - can't fine furthest creep wave pos in lane " .. tLane.sLaneName) end
			desiredPos = core.enemyMainBaseStructure:GetPosition()
		end
	else
		BotEcho('PositionSelfTraverseLane - unable to get my lane!')
	end

	if bDebugLines then
		core.DrawDebugArrow(myPos, desiredPos, 'white')
	end

	return desiredPos
end

function behaviorLib.ChooseBuildingTarget(tBuildings, vecPosition)
	local tSortedBuildings = core.SortBuildings(tBuildings)
	local unitTarget = nil
	
	--throne
	if tSortedBuildings.enemyMainBaseStructure and not tSortedBuildings.enemyMainBaseStructure:IsInvulnerable() then
		unitTarget = tSortedBuildings.enemyMainBaseStructure
	end

	--rax
	if unitTarget == nil then
		local tRax = tSortedBuildings.enemyRax
		if core.NumberElements(tRax) > 0 then
			local unitTargetRax = nil
			for id, rax in pairs(tRax) do
				if not rax:IsInvulnerable() then
					if unitTargetRax == nil or not unitTargetRax:IsUnitType("MeleeRax") then --prefer melee rax
						unitTargetRax = rax
					end
				end
			end

			unitTarget = unitTargetRax
		end
	end

	--towers		
	if unitTarget == nil then
		local tTowers = tSortedBuildings.enemyTowers
		if core.NumberElements(tTowers) > 0 then
			local nClosestSq = 999999999
			for id, tower in pairs(tTowers) do
				if not tower:IsInvulnerable() then
					local nDistanceSq = Vector3.Distance2DSq(vecPosition, tower:GetPosition())
					if nDistanceSq < nClosestSq then
						unitTarget = tower
						nClosestSq = nDistanceSq
					end
				end
			end
		end
	end

	--attack buildings
	if unitTarget == nil then
		local tOthers = tSortedBuildings.enemyOtherBuildings
		if core.NumberElements(tOthers) > 0 then
			local nClosestSq = 999999999
			for id, building in pairs(tOthers) do
				if not building:IsInvulnerable() then
					local nDistanceSq = Vector3.Distance2DSq(vecPosition, building:GetPosition())
					if nDistanceSq < nClosestSq then
						unitTarget = building
						nClosestSq = nDistanceSq
					end
				end
			end
		end
	end
		
	return unitTarget
end

function behaviorLib.PositionSelfBuilding(building)
	local bDebugLines = false
	
	if building == nil then
		return nil
	end

	local vecMyPos = core.unitSelf:GetPosition()
	local vecTargetPosition = building:GetPosition()
	local vecTowardsTarget = Vector3.Normalize(vecTargetPosition - vecMyPos)

	local nRange = core.GetAbsoluteAttackRangeToUnit(core.unitSelf, building)
	local nDistance = nRange - 50

	local vecDesiredPos = vecTargetPosition + (-vecTowardsTarget) * nDistance
	
	if bDebugLines then
		local lineLen = 150
		local vecTargetPosition = building:GetPosition()
	
		local vecOrtho = Vector3.Create(-vecTowardsTarget.y, vecTowardsTarget.x) --quick 90 rotate z
		core.DrawDebugArrow(vecMyPos, vecMyPos + vecTowardsTarget * nRange, 'orange')
		core.DrawDebugLine( (vecMyPos + vecTowardsTarget * nRange) - (vecOrtho * 0.5 * lineLen),
								(vecMyPos + vecTowardsTarget * nRange) + (vecOrtho * 0.5 * lineLen), 'orange')
								
		--core.DrawDebugLine( (vecTowerPosition + vecTowards * (nTowerRange + core.towerBuffer)) - (vecOrtho * 0.25 * lineLen),
		--						(vecTowerPosition + vecTowards * (nTowerRange + core.towerBuffer)) + (vecOrtho * 0.25 * lineLen), 'blue')
								

								
		core.DrawXPosition(vecDesiredPos, 'blue')	
		core.DrawXPosition(vecTargetPosition, 'red')
	end
	
	return vecDesiredPos
end

function behaviorLib.PositionSelfLogic(botBrain)
	StartProfile("PositionSelfLogic")

	local bDebugEchos = false
	
	--if botBrain.myName == 'ShamanBot' then bDebugEchos = true end

	local unitSelf = core.unitSelf
	local vecMyPos = unitSelf:GetPosition()

	local vecDesiredPos = nil
	local unitTarget = nil

	local tLocalUnits = core.localUnits

	local vecLanePosition = behaviorLib.PositionSelfTraverseLane(botBrain)
	local nLaneDistanceSq =  Vector3.Distance2DSq(vecLanePosition, vecMyPos)
	
	--if we are massivly out of position, ignore the other positioning logic and just go
	if nLaneDistanceSq < core.nOutOfPositionRangeSq then
		if not vecDesiredPos and core.NumberElements(tLocalUnits["EnemyUnits"]) > 0 then
			if bDebugEchos then BotEcho("PositionSelfCreepWave") end
			StartProfile("PositionSelfCreepWave")
				unitTarget = core.unitCreepTarget
				vecDesiredPos = behaviorLib.PositionSelfCreepWave(botBrain, unitTarget, tLocalUnits)
			StopProfile()
		end	
		
		if not vecDesiredPos and core.HasBuildingTargets(tLocalUnits["EnemyBuildings"]) and core.NumberElements(tLocalUnits["AllyCreeps"]) > 0 then
			--This ignores misc. buildings
			if bDebugEchos then BotEcho("PositionSelfBuilding") end
			
			StartProfile("Get building unitTarget")
				unitTarget = behaviorLib.ChooseBuildingTarget(tLocalUnits["EnemyBuildings"], vecMyPos)
			StopProfile()
			StartProfile("PositionSelfBuilding")
				vecDesiredPos = behaviorLib.PositionSelfBuilding(unitTarget)
			StopProfile()
		end
	end
	
	if not vecDesiredPos then
		if bDebugEchos then BotEcho("PositionSelfTraverseLane") end
		StartProfile("PositionSelfTraverseLane")
			vecDesiredPos = vecLanePosition
		StopProfile()
	end
		
	if vecDesiredPos then
		if bDebugEchos then BotEcho("Adjusting PositionSelf for Towers") end
		
		local bCanEnterTowerRange = true
		if core.NumberElements(tLocalUnits["EnemyHeroes"]) > 0 then
			bCanEnterTowerRange = false
		end		
					
		StartProfile("AdjustMovementForTowerLogic")
			vecDesiredPos = core.AdjustMovementForTowerLogic(vecDesiredPos, bCanEnterTowerRange)
		StopProfile()
	end
	
	StopProfile()
	return vecDesiredPos, unitTarget
end

----------------------------------
--	MoveExecute
----------------------------------	
---------------------------------
--          PortLogic          --
---------------------------------
--
-- Execute:
-- Checks if porting will be faster then walking to get to the desired location
-- Will use Homecoming Stone or Post Haste
--

-------- Global Constants & Variables --------
behaviorLib.nPortThresholdMS = 9000
behaviorLib.bCheckPorting = true
behaviorLib.bLastPortResult = false

-------- Helper Functions --------
function core.GetClosestTeleportUnit(vecDesiredPosition)
	local unitBuilding = core.GetClosestTeleportBuilding(vecDesiredPosition)
	local vecBuildingPosition = unitBuilding:GetPosition()
	local nDistance = Vector3.Distance2D(vecBuildingPosition, vecDesiredPosition)
	local nDistancePositionToTowerSq = nDistance * nDistance

	local unitTarget = nil
	local nBestDistanceSq = nDistancePositionToTowerSq
	local tPortTargets = HoN.GetUnitsInRadius(vecDesiredPosition, nDistance, core.UNIT_MASK_ALIVE + core.UNIT_MASK_UNIT)
	for _, unitCreep in pairs(tPortTargets) do
		if unitCreep:GetTeam() == core.myTeam and core.IsLaneCreep(unitCreep) and unitCreep:GetHealth() > (unitCreep:GetMaxHealth() * .8) then
			local vecCreepPosition = unitCreep:GetPosition()
			if Vector3.Distance2DSq(vecCreepPosition, vecBuildingPosition) < nDistancePositionToTowerSq then
				-- Only consider creeps between the closest building and the desired position
				local nDistanceCreepToPositionSq = Vector3.Distance2DSq(vecCreepPosition, vecDesiredPosition)
				if nDistanceCreepToPositionSq < nBestDistanceSq then
					nBestDistanceSq = nDistanceCreepToPositionSq
					unitTarget = unitCreep
				end
			end
		end
	end

	return unitTarget or unitBuilding
end

function behaviorLib.ShouldPort(botBrain, vecDesiredPosition)
	local bDebugEchos = false
	local bDebugLines = false
	
	if not vecDesiredPosition then
		BotEcho("ShouldPort recieved a nil position")
		return nil
	end

	local bShouldPort = false
	local unitTarget = nil
	local itemPort = nil

	local unitSelf = core.unitSelf
	local nChannelTime = 3000
	local tInventory = unitSelf:GetInventory()
	local itemGhostMarchers = core.itemGhostMarchers
	
	local nMoveSpeed = unitSelf:GetMoveSpeed()
	local vecMyPos = unitSelf:GetPosition()
	local nNormalWalkingTimeMS = core.TimeToPosition(vecDesiredPosition, vecMyPos, nMoveSpeed, itemGhostMarchers)
	
	local idefPostHaste = HoN.GetItemDefinition("Item_PostHaste")
	if idefPostHaste then
		local tPostHaste = core.InventoryContains(tInventory, idefPostHaste:GetName(), true)
		if #tPostHaste > 0 then
			itemPort = tPostHaste[1]
			unitTarget = core.GetClosestTeleportUnit(vecDesiredPosition)

			if bDebugEchos then
				BotEcho("  unitTarget: "..(unitTarget and unitTarget:GetTypeName() or "nil")) 
			end

			if unitTarget then
				local vecTargetPosition = unitTarget:GetPosition()
				local nCooldownTime = core.GetRemainingCooldownTime(unitSelf, idefPostHaste)
				local nPortWalkTime = core.TimeToPosition(vecDesiredPosition, vecTargetPosition, nMoveSpeed, itemGhostMarchers)
				local nPortingTimeMS = nCooldownTime + nPortWalkTime + nChannelTime
				local nPortDifference = nNormalWalkingTimeMS - nPortingTimeMS

				if nPortDifference > behaviorLib.nPortThresholdMS then
					bShouldPort = true
				end
				
				if bDebugEchos then 
					BotEcho(format("  walkingTime: %d  -  portTime: %d (cd: %d, walk: %d)  =  diff: %d  v  threshold: %d", 
						nNormalWalkingTimeMS, nPortingTimeMS, nCooldownTime, nPortWalkTime, nPortDifference, behaviorLib.nPortThresholdMS)) 
					BotEcho("Traversing forward... port: "..tostring(bShouldPort)) 
				end

				if bDebugLines then
					core.DrawXPosition(vecTargetPosition, 'teal')
					core.DrawDebugLine(vecMyPos, vecTargetPosition)
					core.DrawXPosition(vecDesiredPosition, 'red')
				end
			end
		end
	end
		
	if not itemPort then
		local idefHomecomingStone = HoN.GetItemDefinition("Item_HomecomingStone")
		if idefHomecomingStone then
			local tHomecomingStones = core.InventoryContains(tInventory, idefHomecomingStone:GetName(), true)
			if #tHomecomingStones > 0 then
				itemPort = tHomecomingStones[1]
				unitTarget = core.GetClosestTeleportBuilding(vecDesiredPosition)
	
				if bDebugEchos then
					BotEcho("  unitTarget: "..(unitTarget and unitTarget:GetTypeName() or "nil")) 
				end
	
				if unitTarget then
					local vecTargetPosition = unitTarget:GetPosition()
					local nCooldownTime = core.GetRemainingCooldownTime(unitSelf, idefHomecomingStone)
					local nPortWalkTime = core.TimeToPosition(vecDesiredPosition, vecTargetPosition, nMoveSpeed, itemGhostMarchers)
					local nPortingTimeMS = nCooldownTime + nPortWalkTime + nChannelTime
					local nPortDifference = nNormalWalkingTimeMS - nPortingTimeMS
	
					if nPortDifference > behaviorLib.nPortThresholdMS then
						bShouldPort = true
					end
					
					if bDebugEchos then 
						BotEcho(format("  walkingTime: %d  -  portTime: %d (cd: %d, walk: %d)  =  diff: %d  v  threshold: %d", 
							nNormalWalkingTimeMS, nPortingTimeMS, nCooldownTime, nPortWalkTime, nPortDifference, behaviorLib.nPortThresholdMS)) 
						BotEcho("Traversing forward... port: "..tostring(bShouldPort)) 
					end
	
					if bDebugLines then
						core.DrawXPosition(unitTarget:GetPosition(), 'teal')
						core.DrawDebugLine(vecMyPos, unitTarget:GetPosition())
						core.DrawXPosition(vecDesiredPosition, 'red')
					end
				end
			end
		end
	end

	return bShouldPort, unitTarget, itemPort
end

-------- Logic Functions --------
function behaviorLib.PortLogic(botBrain, vecDesiredPosition)
	local bDebugEchos = false

	local unitSelf = core.unitSelf
	if behaviorLib.bLastPortResult and not unitSelf:IsChanneling() then
		-- Port didn't go off, try again
		behaviorLib.bCheckPorting = true
	end
		
	if behaviorLib.bCheckPorting then
		behaviorLib.bCheckPorting = false
		local nDesiredDistanceSq = Vector3.Distance2DSq(vecDesiredPosition, unitSelf:GetPosition())
		local bSuccess = false
		if nDesiredDistanceSq > (2000 * 2000) then
			local bShouldPort, unitTarget, itemPort = behaviorLib.ShouldPort(botBrain, vecDesiredPosition)
			if bShouldPort and unitTarget and itemPort then
				if itemPort:GetTypeName() == "Item_HomecomingStone" then
					-- Add noise to the position to prevent clustering on mass ports
					local nX = core.RandomReal(-1, 1)
					local nY = core.RandomReal(-1, 1)
					local vecDirection = Vector3.Normalize(Vector3.Create(nX, nY))
					local nDistance = random(100, 400)
					local vecTarget = unitTarget:GetPosition() + vecDirection * nDistance
					
					bSuccess = core.OrderItemPosition(botBrain, unitSelf, itemPort, vecTarget)
				elseif itemPort:GetTypeName() == "Item_PostHaste" then
					bSuccess = core.OrderItemEntityClamp(botBrain, unitSelf, itemPort, unitTarget)
				end
				
				if bSuccess then
					core.nextOrderTime = HoN.GetGameTime() + core.timeBetweenOrders --seed some extra time in there
				end
			end
		end
		
		if bDebugEchos then 
			BotEcho("PortLogic, ran logic. Ported: "..tostring(bSuccess)) 
		end
		
		behaviorLib.bLastPortResult = bSuccess
	end
	
	return behaviorLib.bLastPortResult
end

	
behaviorLib.nPathEnemyTerritoryMul = 1.5
behaviorLib.nPathBaseMul = 1.75
behaviorLib.nPathTowerMul = 3.0

behaviorLib.tPath = nil
behaviorLib.nPathNode = 1
behaviorLib.vecGoal = Vector3.Create()
behaviorLib.nGoalToleranceSq = 750*750
behaviorLib.nPathDistanceToleranceSq = 300*300
function behaviorLib.PathLogic(botBrain, vecDesiredPosition)
	local bDebugLines = false
	local bDebugEchos = false
	local bMarkProperties = false
	
	--if object.myName == "ShamanBot" then bDebugLines = true bDebugEchos = true end
	
	local bRepath = false
	if Vector3.Distance2DSq(vecDesiredPosition, behaviorLib.vecGoal) > behaviorLib.nGoalToleranceSq then
		bRepath = true
	end
	
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	
	if bRepath then
		if bDebugEchos then BotEcho("Repathing!") end
		
		local sEnemyZone = "hellbourne"
		if core.myTeam == HoN.GetHellbourneTeam() then
			sEnemyZone = "legion"
		end
		
		if bDebugEchos then BotEcho("enemy zone: "..sEnemyZone) end
		
		local nEnemyTerritoryMul = behaviorLib.nPathEnemyTerritoryMul
		local nTowerMul          = behaviorLib.nPathTowerMul
		local nBaseMul           = behaviorLib.nPathBaseMul
		
		local function funcNodeCost(nodeParent, nodeCurrent, link, nOriginalCost)
			--TODO: local nDistance = link:GetLength()
			local nDistance = Vector3.Distance(nodeParent:GetPosition(), nodeCurrent:GetPosition())
			local nCostToParent = nOriginalCost - nDistance
			
			--BotEcho(format("nOriginalCost: %s  nDistance: %s  nSq: %s", nOriginalCost, nDistance, nDistance*nDistance))
		
			local sZoneProperty  = nodeCurrent:GetProperty("zone")
			local bTowerProperty = nodeCurrent:GetProperty("tower")
			local bBaseProperty  = nodeCurrent:GetProperty("base")
			
			local nMultiplier = 1.0
			local bEnemyZone = false
			if sZoneProperty and sZoneProperty == sEnemyZone then
				bEnemyZone = true
			end
			
			if bEnemyZone then
				nMultiplier = nMultiplier + nEnemyTerritoryMul
				if bBaseProperty then
					nMultiplier = nMultiplier + nBaseMul
				end
				
				if bTowerProperty then
					--check if the tower is there
					local tBuildings = HoN.GetUnitsInRadius(nodeCurrent:GetPosition(), 800, core.UNIT_MASK_ALIVE + core.UNIT_MASK_BUILDING)
					
					for _, unitBuilding in pairs(tBuildings) do
						if unitBuilding:IsTower() then
							nMultiplier = nMultiplier + nTowerMul
							break
						end
					end
				end				
			end
			
			return nCostToParent + nDistance * nMultiplier
		end
	
		behaviorLib.tPath = BotMetaData.FindPath(vecMyPosition, vecDesiredPosition, funcNodeCost)
		behaviorLib.vecGoal = vecDesiredPosition
		behaviorLib.nPathNode = 1
		
		--double check the first node since we have a really sparse graph
		local tPath = behaviorLib.tPath
		if #tPath > 1 then
			local vecMeToFirst = tPath[1]:GetPosition() - vecMyPosition
			local vecFirstToSecond = tPath[2]:GetPosition() - tPath[1]:GetPosition()
			if Vector3.Dot(vecMeToFirst, vecFirstToSecond) < 0 then
				--don't go backwards, skip the first
				behaviorLib.nPathNode = 2
			end
		end
	end
	
	--Follow path logic
	local vecReturn = nil
	
	local tPath = behaviorLib.tPath
	local nPathNode = behaviorLib.nPathNode
	if tPath then
		local vecCurrentNode = tPath[nPathNode]
		if vecCurrentNode then
			if Vector3.Distance2DSq(vecCurrentNode:GetPosition(), vecMyPosition) < behaviorLib.nPathDistanceToleranceSq then
				nPathNode = nPathNode + 1
				behaviorLib.nPathNode = nPathNode				
			end
			
			local nodeWaypoint = tPath[behaviorLib.nPathNode]
			if nodeWaypoint then
				vecReturn = nodeWaypoint:GetPosition()
			end
		end
	end
	
	if bDebugLines then
		if tPath ~= nil then
			local nLineLen = 300
			local vecLastNodePosition = nil
			for i, node in ipairs(tPath) do
				local vecNodePosition = node:GetPosition()
				
				if bMarkProperties then
					local sZoneProperty  = node:GetProperty("zone")
					local bTowerProperty = node:GetProperty("tower")
					local bBaseProperty  = node:GetProperty("base")
					
					local bEnemyZone = false
					local sEnemyZone = "hellbourne"
					if core.myTeam == HoN.GetHellbourneTeam() then
						sEnemyZone = "legion"
					end
					if sZoneProperty and sZoneProperty == sEnemyZone then
						bEnemyZone = true
					end				
					if bEnemyZone then
						core.DrawDebugLine(vecNodePosition, vecNodePosition + Vector3.Create(0, 1) * nLineLen, "red")

						if bBaseProperty then
							core.DrawDebugLine(vecNodePosition, vecNodePosition + Vector3.Create(1, 0) * nLineLen, "orange")
						end
						if bTowerProperty then
							--check if the tower is there
							local tBuildings = HoN.GetUnitsInRadius(node:GetPosition(), 800, core.UNIT_MASK_ALIVE + core.UNIT_MASK_BUILDING)
							
							for _, unitBuilding in pairs(tBuildings) do
								if unitBuilding:IsTower() then
									core.DrawDebugLine(vecNodePosition, vecNodePosition + Vector3.Create(-1, 0) * nLineLen, "yellow")
									break
								end
							end
						end
					end
				end
			
				if vecLastNodePosition then
					--node to node
					if bDebugLines then
						core.DrawDebugArrow(vecLastNodePosition, vecNodePosition, 'blue')
					end
				end
				vecLastNodePosition = vecNodePosition
			end
			core.DrawXPosition(vecReturn, 'yellow')
			core.DrawXPosition(behaviorLib.vecGoal, "orange")
			core.DrawXPosition(vecDesiredPosition, "teal")
		end
	end	
	
	return vecReturn				
end

function behaviorLib.MoveExecute(botBrain, vecDesiredPosition)
	if bDebugEchos then BotEcho("Movin'") end
	local bActionTaken = false
	
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	local vecMovePosition = vecDesiredPosition
	
	local nDesiredDistanceSq = Vector3.Distance2DSq(vecDesiredPosition, vecMyPosition)			
	if nDesiredDistanceSq > core.nOutOfPositionRangeSq then
		--check porting
		if bActionTaken == false then
			StartProfile("PortLogic")
				local bPorted = behaviorLib.PortLogic(botBrain, vecDesiredPosition)
			StopProfile()
			
			if bPorted then
				if bDebugEchos then BotEcho("Portin'") end
				bActionTaken = true
			end
		end
		
		if bActionTaken == false then
			--we'll need to path there
			if bDebugEchos then BotEcho("Pathin'") end
			StartProfile("PathLogic")
				local vecWaypoint = behaviorLib.PathLogic(botBrain, vecDesiredPosition)
			StopProfile()
			if vecWaypoint then
				vecMovePosition = vecWaypoint
			end
		end
	end
	
	--move out
	if bActionTaken == false then
		if bDebugEchos then BotEcho("Move 'n' hold order") end
		bActionTaken = core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, vecMovePosition)
	end
	
	return bActionTaken
end



---------------------------------------------------
--                   Behaviors                   --
---------------------------------------------------
--[[
General Overview:

HarassHero -		0-100 based on
						- Distance
						- RelativeHP%
						- Range
						- AttackAdvantage
						- ProxToEnemyTower
						- InRangeIdling
						- Momentum

RetreatFromThreat -	0-100 based on 
						- +damageUtil = Damage over last 1.5s (val from average of 1s and 2s damage) * 0.35
						- +25 if aggro'd creeps
						- +max(25 or #towerProjectiles * 33) if tower aggro'd

HealAtWell -		0-100 based on HP% and proximity to the well
						- HP%Fn = (30%, 20) (20%, 35) (10%, 60) exponentially increases the closer to 0% health 
						- ProximityFn = 35 if < 600 away, otherwise a slow decay (601, 15) (2900, 10)
						
DontBreakChannel -	100	if channeling
Shop -				99	if just got into shop and not done buying
PreGame -			98	if GetMatchTime() <= 0
HitBulding -		36, 40 if {rax,throne} is not invulnerable, in range
TeamGroup -			35	if teambrain tells us
(HitBulding) -		23, 25 if {other,tower} is not invulnerable, in range, and wont aggro if tower
AttackCreeps -		24	if lh. Only if they are within 1 hit (no prediction)
TeamDefend -		23	if the teambrain tells us
PushBehavior -		22	max, 
(AttackCreeps) -	21	if deny. Only if they are within 1 hit (no prediction)

UseHealthRegen -	20-30 when we want to use a rune
						- Fn which crosses 20 at x=138HP down and 30 at x=600, graph is convex down
					20-40 when we want to use a health pot
						- Fn which crosses 20 at x=400HP down and 40 at x=650, graph is convex down

PositionSelf -		20 (always)
						- if enemyCreeps, PositionSelfCreepWave
						- elseif enemyBuildings, PositionSelfBuilding
						- else	PositionSelfTraverseLane
						- ports if it saves > 9000ms
						- activates ghost marchers if able
--]]

------------------- Shared Behavior Functions --------------------
function behaviorLib.RelativeHealthUtility(relativePercentHP)
	local nUtility = 0
	local vOrigin = Vector3.Create(0, 0)
	local vMax = Vector3.Create(0.8, 100)
	local vMin = Vector3.Create(-0.45, -100)

	nUtility = core.UnbalancedSRootFn(relativePercentHP, vMax, vMin, vOrigin, 1.5)

	nUtility = Clamp(nUtility, -100, 100)

	return nUtility
end

function behaviorLib.DistanceThreatUtility(nDist, nRange, nMoveSpeed, bAttackReady)
	local nUtility = 0

	if nDist < nRange and bAttackReady then
		nUtility = 100
	else
		local nXShift = nRange
		local nX = max(nDist - nXShift, 0)

		--local m = -100 / nMoveSpeed
		--nUtility = m * (nDist - nXShift) + 100

		nUtility = core.ExpDecay(nX, 100, nMoveSpeed, 0.5)
	end

	nUtility = Clamp(nUtility, 0, 100)

	return nUtility
end

function behaviorLib.RelativeRangeUtility(relativeRange)
	local nUtility = 0

	local m = 100/(625-128)

	nUtility = m * relativeRange

	nUtility = Clamp(nUtility, -100, 100)

	return nUtility
end


----------------------------------
--	PreGame behavior
--
--	Utility: 98 if MatchTime is <= 0
--	Execute: Hold in the fountain
----------------------------------

function behaviorLib.PreGameUtility(botBrain)
	local utility = 0

	if HoN:GetMatchTime() <= 0 then
		utility = 98
	end

	if botBrain.bDebugUtility == true and utility ~= 0 then
		BotEcho(format("  PreGameUtility: %g", utility))
	end

	return utility
end

function behaviorLib.PreGameExecute(botBrain)
	if HoN.GetRemainingPreMatchTime() > core.teamBotBrain.nInitialBotMove then        
		core.OrderHoldClamp(botBrain, core.unitSelf)
	else
		local vecTargetPos = behaviorLib.PositionSelfTraverseLane(botBrain)
		core.OrderMoveToPosClamp(botBrain, core.unitSelf, vecTargetPos, false)
	end
end

behaviorLib.PreGameBehavior = {}
behaviorLib.PreGameBehavior["Utility"] = behaviorLib.PreGameUtility
behaviorLib.PreGameBehavior["Execute"] = behaviorLib.PreGameExecute
behaviorLib.PreGameBehavior["Name"] = "PreGame"
tinsert(behaviorLib.tBehaviors, behaviorLib.PreGameBehavior)


------------------------------------
--          AttackCreeps          --
------------------------------------
--
--	Utility: 21 if deny, 24 if ck, only if it predicts it can kill in one hit
--	Execute: Attacks target
--  Last hitting developed by Paradox
--  with assistance from Kairus101
----------------------------------
function behaviorLib.GetAttackDamageOnCreep(botBrain, unitCreepTarget)
	local bDebugEchos = false

	if not unitCreepTarget or not core.CanSeeUnit(botBrain, unitCreepTarget) then
		return nil
	end

	local unitSelf = core.unitSelf

	--Get positioning information
	local vecSelfPos = unitSelf:GetPosition()
	local vecTargetPos = unitCreepTarget:GetPosition() 

	local nTravelTime = nil
	if (unitSelf:GetAttackType() ~= "melee") then--We are ranged, use projectile time.
		local nProjectileSpeed = unitSelf:GetAttackProjectileSpeed()
		local nAdjustedAttackActionTime = unitSelf:GetAdjustedAttackActionTime() / 1000
		nTravelTime = Vector3.Distance2D(vecSelfPos, vecTargetPos) / nProjectileSpeed
		nTravelTime = nTravelTime + nAdjustedAttackActionTime
		if bDebugEchos then BotEcho ("Projectile travel time: " .. nTravelTime ) end 
	else --We are melee, therefore we don't use projectile time, we use walking time.
		local nMovementSpeed = unitSelf:GetMoveSpeed()
		local nMeleeRange = 128 --We don't have to be ontop of the enemy to hit them.
		local nAdjustedAttackActionTime = unitSelf:GetAdjustedAttackActionTime() / 1000
		nTravelTime = (Vector3.Distance2D(vecSelfPos, vecTargetPos) - nMeleeRange) / nMovementSpeed
		nTravelTime = nTravelTime * 1.2 + nAdjustedAttackActionTime
		if bDebugEchos then BotEcho ("Melee travel time: " .. nTravelTime ) end 
	end
	
	
	local nExpectedCreepDamage = 0
	local nExpectedTowerDamage = 0
	local tNearbyAttackingCreeps = nil
	local tNearbyAttackingTowers = nil

	--Get the creeps and towers on the opposite team
	-- of our target
	if unitCreepTarget:GetTeam() == unitSelf:GetTeam() then
		tNearbyAttackingCreeps = core.localUnits['EnemyCreeps']
		tNearbyAttackingTowers = core.localUnits['EnemyTowers']
	else
		tNearbyAttackingCreeps = core.localUnits['AllyCreeps']
		tNearbyAttackingTowers = core.localUnits['AllyTowers']
	end

	--Determine the damage expected on the creep by other creeps
	for i, unitCreep in pairs(tNearbyAttackingCreeps) do
		if unitCreep:GetAttackTarget() == unitCreepTarget then
			local nCreepAttacks = ceil(unitCreep:GetAttackSpeed() * nTravelTime)
			nExpectedCreepDamage = nExpectedCreepDamage + unitCreep:GetFinalAttackDamageMin() * nCreepAttacks
		end
	end

	--Determine the damage expected on the creep by other towers
	for i, unitTower in pairs(tNearbyAttackingTowers) do
		if unitTower:GetAttackTarget() == unitCreepTarget then
			local nTowerAttacks = ceil(unitTower:GetAttackSpeed() * nTravelTime)
			nExpectedTowerDamage = nExpectedTowerDamage + unitTower:GetFinalAttackDamageMin() * nTowerAttacks
		end
	end

	return nExpectedCreepDamage + nExpectedTowerDamage
end

function behaviorLib.GetCreepAttackTarget(botBrain, unitEnemyCreep, unitAllyCreep) --called pretty much constantly
	local bDebugEchos = false

	--Get info about self
	local unitSelf = core.unitSelf
	local nDamageMin = unitSelf:GetFinalAttackDamageMin()
	
	if core.itemHatchet then
		nDamageMin = nDamageMin * core.itemHatchet.creepDamageMul
	end	
	
	-- [Difficulty: Easy] Make bots worse at last hitting
	-- TODO: use actual time variance instead of damage flubbing
	if core.nDifficulty == core.nEASY_DIFFICULTY then
		nDamageMin = nDamageMin + 120
	end

	if unitEnemyCreep and core.CanSeeUnit(botBrain, unitEnemyCreep) then
		local nTargetHealth = unitEnemyCreep:GetHealth()
		--Only attack if, by the time our attack reaches the target
		-- the damage done by other sources brings the target's health
		-- below our minimum damage
		if nDamageMin * (1 - unitEnemyCreep:GetPhysicalResistance()) >= (nTargetHealth - behaviorLib.GetAttackDamageOnCreep(botBrain, unitEnemyCreep)) then
			local bActuallyLH = true
			
			-- [Tutorial] Make DS not mess with your last hitting before shit gets real
			if core.bIsTutorial and core.bTutorialBehaviorReset == false and core.unitSelf:GetTypeName() == "Hero_Shaman" then
				bActuallyLH = false
			end
			
			if bActuallyLH then
				if bDebugEchos then BotEcho("Returning an enemy") end
				return unitEnemyCreep
			end
		end
	end

	if unitAllyCreep then
		local nTargetHealth = unitAllyCreep:GetHealth()
		--Only attack if, by the time our attack reaches the target
		-- the damage done by other sources brings the target's health
		-- below our minimum damage
		if nDamageMin * (1 - unitAllyCreep:GetPhysicalResistance()) >= (nTargetHealth - behaviorLib.GetAttackDamageOnCreep(botBrain, unitAllyCreep)) then
			local bActuallyDeny = true
			
			--[Difficulty: Easy] Don't deny
			if core.nDifficulty == core.nEASY_DIFFICULTY then
				bActuallyDeny = false
			end			
			
			-- [Tutorial] Hellbourne *will* deny creeps after shit gets real
			if core.bIsTutorial and core.bTutorialBehaviorReset == true and core.myTeam == HoN.GetHellbourneTeam() then
				bActuallyDeny = true
			end
			
			if bActuallyDeny then
				if bDebugEchos then BotEcho("Returning an ally") end
				return unitAllyCreep
			end
		end
	end

	return nil
end

-------- Behavior Functions --------
function behaviorLib.AttackCreepsUtility(botBrain)	
	local nDenyVal = 21
	local nLastHitVal = 24
	local nUtility = 0

	-- Don't deny while pushing
	local unitDenyTarget = core.unitAllyCreepTarget
	if core.GetCurrentBehaviorName(botBrain) == "Push" then
		unitDenyTarget = nil
	end
	
	local unitTarget = behaviorLib.GetCreepAttackTarget(botBrain, core.unitEnemyCreepTarget, unitDenyTarget)
	
	if unitTarget then --[[and core.unitSelf:IsAttackReady() then]]
		if unitTarget:GetTeam() == core.myTeam then
			nUtility = nDenyVal
		else
			nUtility = nLastHitVal
		end
		
		core.unitCreepTarget = unitTarget
	end

	if botBrain.bDebugUtility == true and nUtility ~= 0 then
		BotEcho(format("  AttackCreepsUtility: %g", nUtility))
	end

	return nUtility
end

behaviorLib.nLastMoveToCreepID = nil
function behaviorLib.AttackCreepsExecute(botBrain)
	local bActionTaken = false
	local unitSelf = core.unitSelf
	local sCurrentBehavior = core.GetCurrentBehaviorName(botBrain)

	local unitCreepTarget = nil
	if sCurrentBehavior == "AttackEnemyMinions" then
		unitCreepTarget = core.unitMinionTarget
	else
		unitCreepTarget = core.unitCreepTarget
	end

	if unitCreepTarget and core.CanSeeUnit(botBrain, unitCreepTarget) then      
		--Get info about the target we are about to attack
		local vecSelfPos = unitSelf:GetPosition()
		local vecTargetPos = unitCreepTarget:GetPosition()
		local nDistSq = Vector3.Distance2DSq(vecSelfPos, vecTargetPos)
		local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitCreepTarget, true)

		--Only attack if, by the time our attack reaches the target
		-- the damage done by other sources brings the target's health
		-- below our minimum damage, and we are in range and can attack right now-		
		if nDistSq <= nAttackRangeSq and unitSelf:IsAttackReady() then
			if unitSelf:GetAttackType() == "melee" then
				local nDamageMin = unitSelf:GetFinalAttackDamageMin()
				
				if core.itemHatchet then
					nDamageMin = nDamageMin * core.itemHatchet.creepDamageMul
				end	

				if unitCreepTarget:GetHealth() <= nDamageMin then
					if core.GetAttackSequenceProgress(unitSelf) ~= "windup" then
						bActionTaken = core.OrderAttack(botBrain, unitSelf, unitCreepTarget)
					else
						bActionTaken = true		
					end
				else
					bActionTaken = core.OrderHoldClamp(botBrain, unitSelf, false)
				end
			else
				bActionTaken = core.OrderAttackClamp(botBrain, unitSelf, unitCreepTarget)
			end
		else
			if unitSelf:GetAttackType() == "melee" then
				if core.GetLastBehaviorName(botBrain) ~= behaviorLib.AttackCreepsBehavior.Name and unitCreepTarget:GetUniqueID() ~= behaviorLib.nLastMoveToCreepID then
					behaviorLib.nLastMoveToCreepID = unitCreepTarget:GetUniqueID()
					--If melee, move closer.
					local vecDesiredPos = core.AdjustMovementForTowerLogic(vecTargetPos)
					bActionTaken = core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, vecDesiredPos, false)
				end
			else
				--If ranged, get within 70% of attack range if not already
				-- This will decrease travel time for the projectile
				if (nDistSq > nAttackRangeSq * 0.5) then 
					local vecDesiredPos = core.AdjustMovementForTowerLogic(vecTargetPos)
					bActionTaken = core.OrderMoveToPosClamp(botBrain, unitSelf, vecDesiredPos, false)
				--If within a good range, just hold tight
				else
					bActionTaken = core.OrderHoldClamp(botBrain, unitSelf, false)
				end
			end
		end
		-- Use Loggers Hatchet
		if not bActionTaken then
			local itemHatchet = core.itemHatchet
			--nested if for clarity and to reduce optimization which is negligible.
			if itemHatchet and itemHatchet:CanActivate() then --valid hatchet
				if unitCreepTarget:GetTeam() ~= unitSelf:GetTeam() and core.IsLaneCreep(unitCreepTarget) then --valid creep
					if core.GetAttackSequenceProgress(unitSelf) ~= "windup" and nDistSq < (600 * 600) then --valid positioning
						if unitSelf:GetBaseDamage() * (1 - core.unitCreepTarget:GetPhysicalResistance()) > core.unitCreepTarget:GetHealth() then --valid HP
							bActionTaken = botBrain:OrderItemEntity(itemHatchet.object or itemHatchet, unitCreepTarget.object or unitCreepTarget, false)
						end
					end
				end
			end
		end
	end
	return bActionTaken
end

behaviorLib.AttackCreepsBehavior = {}
behaviorLib.AttackCreepsBehavior["Utility"] = behaviorLib.AttackCreepsUtility
behaviorLib.AttackCreepsBehavior["Execute"] = behaviorLib.AttackCreepsExecute
behaviorLib.AttackCreepsBehavior["Name"] = "AttackCreeps"
tinsert(behaviorLib.tBehaviors, behaviorLib.AttackCreepsBehavior)


----------------------------------
--      AttackEnemyMinions
--     
--      Utility: 20.5 or 25 based on Minion-Health
--      Execute: Attacks chosen minion like a creep
----------------------------------
core.unitMinionTarget = nil
function behaviorLib.attackEnemyMinionsUtility(botBrain)
	local tEnemies = core.localUnits["Enemies"]
	local unitWeakestMinion = nil
	local nMinionHP = 99999999
	
	local nUtility = 0
	for _, unit in pairs(tEnemies) do
		if not unit:IsInvulnerable() and not unit:IsHero() and unit:GetOwnerPlayer() ~= nil then
			local nTempHP = unit:GetHealth()
			if nTempHP < nMinionHP then
				unitWeakestMinion = unit
				nMinionHP = nTempHP
			end
		end
	end
	
	if unitWeakestMinion ~= nil then
		core.unitMinionTarget = unitWeakestMinion
		--minion lh > creep lh
		local unitSelf = core.unitSelf
		local nDistSq = Vector3.Distance2DSq(unitSelf:GetPosition(), unitWeakestMinion:GetPosition())
		local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, currentTarget, true)
		
		if nDistSq < nAttackRangeSq + 100 * 100 and unitSelf:IsAttackReady() then
			if nMinionHP <= core.unitSelf:GetAttackDamageMin() * (1 - unitWeakestMinion:GetPhysicalResistance()) then
				-- LastHit Minion
				nUtility = 25
			else
				-- Harass Minion
				-- PositionSelf 20 and AttackCreeps 21
				-- positonSelf < minionHarass < creep lh || deny
				nUtility = 20.5
			end
		end
	end
	return nUtility
end
 
behaviorLib.attackEnemyMinionsBehavior = {}
behaviorLib.attackEnemyMinionsBehavior["Utility"] = behaviorLib.attackEnemyMinionsUtility
behaviorLib.attackEnemyMinionsBehavior["Execute"] = behaviorLib.AttackCreepsExecute
behaviorLib.attackEnemyMinionsBehavior["Name"] = "AttackEnemyMinions"
tinsert(behaviorLib.tBehaviors, behaviorLib.attackEnemyMinionsBehavior)



----------------------------------
--	HarassHero behavior
--
--	Utility: 0-100 based on relative lethalities, calculated per team
--	Execute: Moves to and attacks target when in nRange

--  Note: Many hero-specific bots override this behavior to add execute options and additional utility considerations

--	Tutorial: Hellbourne bots harass much less frequently
----------------------------------

behaviorLib.tThreatMultipliers = {}
behaviorLib.nThreatAdjustment = 0.075

function behaviorLib.GetThreat(unit)
	local nThreat = core.teamBotBrain:GetThreat(unit)
	--apply out threat multiplier
	return nThreat * (behaviorLib.tThreatMultipliers[unit:GetUniqueID()] or 1)
end

function behaviorLib.GetDefense(unit)
	return core.teamBotBrain:GetDefense(unit)
end


function behaviorLib.CustomHarassUtility(unit)
	--TODO: Based on level?
	--  this is a great function to override with ability Threat in the hero_main file
	
	return 0
end

function behaviorLib.LethalityDifferenceUtility(nLethalityDifference)
	return Clamp(nLethalityDifference * 0.035, -100, 100)
end

function behaviorLib.ProxToEnemyTowerUtility(unit, unitClosestEnemyTower)
	local bDebugEchos = false
	
	local nUtility = 0

	if unitClosestEnemyTower then
		local nDist = Vector3.Distance2D(unitClosestEnemyTower:GetPosition(), unit:GetPosition())
		local nTowerRange = core.GetAbsoluteAttackRangeToUnit(unitClosestEnemyTower, unit)
		local nBuffers = unit:GetBoundsRadius() + unitClosestEnemyTower:GetBoundsRadius()

		nUtility = -1 * core.ExpDecay((nDist - nBuffers), 100, nTowerRange, 2)
		
		nUtility = nUtility * 0.32
		
		if bDebugEchos then BotEcho(format("util: %d  nDistance: %d  nTowerRange: %d", nUtility, (nDist - nBuffers), nTowerRange)) end
	end
	
	nUtility = Clamp(nUtility, -100, 0)

	return nUtility
end

function behaviorLib.AttackAdvantageUtility(unitSelf, unitTarget)
	local nUtility = 0

	local bAttackingMe = false
	local unitAttackTarget = unitTarget:GetAttackTarget()
	if unitAttackTarget and unitAttackTarget:GetUniqueID() == unitSelf:GetUniqueID() then
		bAttackingMe = true
	end
	
	if not unitTarget:IsAttackReady() and not bAttackingMe then
		nUtility = 5
	end

	return nUtility
end

function behaviorLib.InRangeUtility(unitSelf, unitTarget)
	local nUtility = 0

	if unitSelf:IsAttackReady() then
		local nDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), unitTarget:GetPosition())
		local nRange = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
		
		if core.unitSelf:GetAttackType() == "melee" then
			--override melee to give the bonus if they are "close enough"
			nRange = 250  --AbsoluteMeleeRangeToUnit is ~195
		end
		
		if nDistanceSq <= nRange * nRange then
			nUtility = 15
		end
	end

	return nUtility
end


function behaviorLib.ProcessKill(unit)
	local bDebugEchos = false
	
	local nID = unit:GetUniqueID()
	local tThreatMultipliers = behaviorLib.tThreatMultipliers
	
	if tThreatMultipliers[nID] == nil then
		BotEcho("I got a kill on some unknown hero!? "..unit:GetTypeName().." on team "..unit:GetTeam())
		return
	end
	
	--[Difficulty: Easy] Bots don't become more bold
	if core.nDifficulty == core.nEASY_DIFFICULTY and tThreatMultipliers[nID] <= 1 then
		return
	end
	
	if bDebugEchos then BotEcho(format("I got a kill! Changing %s's threat multiplier from %g to %g", unit:GetTypeName(),
		tThreatMultipliers[nID], tThreatMultipliers[nID] - behaviorLib.nThreatAdjustment)) end
	
	tThreatMultipliers[nID] = tThreatMultipliers[nID] - behaviorLib.nThreatAdjustment
end

function behaviorLib.ProcessDeath(unit)
	local bDebugEchos = false
	
	if unit then
		local nID = unit:GetUniqueID()	
		local tThreatMultipliers = behaviorLib.tThreatMultipliers
		
		if tThreatMultipliers[nID] == nil then
			--TODO: figure out how to get the hero who got credit for my death (if any)
			return
		end
		
		if bDebugEchos then BotEcho(format("I died! Changing %s's threat multiplier from %g to %g", unit:GetTypeName(),
			tThreatMultipliers[nID], tThreatMultipliers[nID] + behaviorLib.nThreatAdjustment)) end
		
		tThreatMultipliers[nID] = tThreatMultipliers[nID] + behaviorLib.nThreatAdjustment
	end
end

----------------------------------
behaviorLib.diveThreshold = 75
behaviorLib.lastHarassUtil = 0
behaviorLib.heroTarget = nil

behaviorLib.rangedHarassBuffer = 300

behaviorLib.harassUtilityWeight = 1.0

function behaviorLib.HarassHeroUtility(botBrain)
	local bDebugEchos = false
	
	--if core.unitSelf:GetTypeName() == "Hero_Predator" then bDebugEchos = true end
		
	local nUtility = 0
	local unitTarget = nil
	
	local unitSelf = core.unitSelf
	local nMyID = unitSelf:GetUniqueID()
	local vecMyPosition = unitSelf:GetPosition()
	
	local tLocalEnemies = core.CopyTable(core.localUnits["EnemyHeroes"])
	local function fnIsHero(unit)
		return unit:IsHero()
	end
	
	core.teamBotBrain:AddMemoryUnitsToTable(tLocalEnemies, core.enemyTeam, vecMyPosition, nil, fnIsHero)
	
	--if bDebugEchos then BotEcho(tostring(not core.IsTableEmpty(tLocalEnemies)).." "..core.NumberElements(tLocalEnemies)) end
	
	if not core.IsTableEmpty(tLocalEnemies) then
		local unitClosestEnemyTower = core.GetClosestEnemyTower(vecMyPosition)
		local nAllyThreatRange = 1200
		local nHalfAllyThreatRange = nAllyThreatRange * 0.5
				
		local tLocalAllies = core.CopyTable(core.localUnits["AllyHeroes"])
		tLocalAllies[unitSelf:GetUniqueID()] = unitSelf --include myself in the threat calculations
		local nTotalAllyThreat = 0
		local nMyThreat = 0
		local nMyDefense = 0
				
		local nTotalEnemyThreat = 0
		local nLowestEnemyDefense = 999999
		local unitWeakestEnemy = nil
		local nHighestEnemyThreat = 0

		--local references to loop functions, to increase performance
		local nHarassBonus = core.nHarassBonus
		local funcGetThreat = behaviorLib.GetThreat
		local funcGetDefense = behaviorLib.GetDefense
		local nHarassUtilityWeight = behaviorLib.harassUtilityWeight
		local funcProxToEnemyTowerUtility    =  behaviorLib.ProxToEnemyTowerUtility
		local funcLethalityDifferenceUtility = behaviorLib.LethalityDifferenceUtility
		local funcCustomHarassUtility        = behaviorLib.CustomHarassUtility
		local funcAttackAdvantageUtility     = behaviorLib.AttackAdvantageUtility
		local funcInRangeUtility             = behaviorLib.InRangeUtility		
		
		local nMyProxToEnemyTowerUtility = funcProxToEnemyTowerUtility(unitSelf, unitClosestEnemyTower)
		
		if bDebugEchos then BotEcho("HarassHeroNew") end
		
		--Enemies
		for nID, unitEnemy in pairs(tLocalEnemies) do
			local nThreat = funcGetThreat(unitEnemy)
			nTotalEnemyThreat = nTotalEnemyThreat + nThreat
			if nThreat > nHighestEnemyThreat then
				nHighestEnemyThreat = nThreat
			end
			
			local nDefense = funcGetDefense(unitEnemy)
			if nDefense < nLowestEnemyDefense then
				nLowestEnemyDefense = nDefense
				unitWeakestEnemy = unitEnemy
			end
			
			if bDebugEchos then BotEcho(nID..": "..unitEnemy:GetTypeName().."  threat: "..Round(nThreat).."  defense: "..Round(nDefense)) end
		end
		
		--Aquire a target
		--TODO: based on mix of priority target (high threat) v weak (low defense)
		unitTarget = unitWeakestEnemy
		
		--Allies
		local vecTowardsTarget = (unitTarget:GetPosition() - vecMyPosition)
				
		for nID, unitAlly in pairs(tLocalAllies) do
			local vecTowardsAlly, nDistance = Vector3.Normalize(unitAlly:GetPosition() - vecMyPosition)
			
			if nDistance <= nAllyThreatRange then
				local nThreat = funcGetThreat(unitAlly)
				
				if unitAlly:GetUniqueID() ~= nMyID then
					local nThreatMul = 1
					if nDistance > nHalfAllyThreatRange and Vector3.Dot(vecTowardsAlly, vecTowardsTarget) < 0 then
						--attenuate threat if they are far behind
						nThreatMul = 1 - (nDistance - nHalfAllyThreatRange) / nHalfAllyThreatRange						
					end
					
					if bDebugEchos then BotEcho(format("%s  dot: %g  nThreatMul: %g  nDistance: %d  nRange: %d",
						unitAlly:GetTypeName(), Vector3.Dot(vecTowardsAlly, vecTowardsTarget), nThreatMul, nDistance, nAllyThreatRange))
					end
					
					nThreat = nThreat * nThreatMul				
				else
					nMyThreat = nThreat
				end
				
				nTotalAllyThreat = nTotalAllyThreat + nThreat
				if bDebugEchos then BotEcho(nID..": "..unitAlly:GetTypeName().."  threat: "..Round(nThreat)) end
			end			
		end
		--if bDebugEchos then BotEcho("totalAllyThreat: "..Round(nTotalAllyThreat)) end

		nMyDefense = funcGetDefense(unitSelf)
		if bDebugEchos then BotEcho("myDefense: "..Round(nMyDefense)) end
		
		local nAllyLethality = 0
		local nEnemyLethality = 0
		local nLethalityDifference = 0
		if unitTarget ~= nil then
			nAllyLethality = nTotalAllyThreat - nLowestEnemyDefense
			nEnemyLethality = nTotalEnemyThreat - nMyDefense
			
			--nAllyLethality = nMyThreat - nLowestEnemyDefense
			--nEnemyLethality = nHighestEnemyThreat - nMyDefense
			
			nLethalityDifference = nAllyLethality - nEnemyLethality
		end
		
		if bDebugEchos then BotEcho("AllyLethality: "..nAllyLethality.."  EnemyLethality "..nEnemyLethality) end
				
		local nLethalityUtility = funcLethalityDifferenceUtility(nLethalityDifference)
		
		--Apply aggression conditional bonuses
		local nCustomUtility = funcCustomHarassUtility(unitTarget)
		local nMomentumUtility = nHarassBonus
		local nProxToEnemyTowerUtility = funcProxToEnemyTowerUtility(unitTarget, unitClosestEnemyTower)
		local nAttackAdvantageUtility = funcAttackAdvantageUtility(unitSelf, unitTarget)
		local nInRangeUtility = funcInRangeUtility(unitSelf, unitTarget)
		
		nUtility = nLethalityUtility + nProxToEnemyTowerUtility + nMyProxToEnemyTowerUtility + nInRangeUtility + nCustomUtility + nMomentumUtility
		
		nUtility = nUtility * nHarassUtilityWeight
		
		--[Difficulty: Easy] Randomly, bots are more aggressive for an interval
		if core.bEasyRandomAggression then
			nUtility = nUtility + core.nEasyAggroHarassBonus
		end
		
		if bDebugEchos then 
			BotEcho(format("util: %d  lethality: %d  custom: %d  momentum: %d  prox: %d  attkAdv: %d  inRange: %d  %%harass: %g",
				nUtility, nLethalityUtility, nCustomUtility, nMomentumUtility, nProxToEnemyTowerUtility, 
				nAttackAdvantageUtility, nInRangeUtility, nHarassUtilityWeight)
			)
		end
	end
	
	behaviorLib.lastHarassUtil = nUtility
	behaviorLib.heroTarget = unitTarget
	
	if bDebugEchos or (botBrain.bDebugUtility and nUtility ~= 0) then
		if core.nDifficulty == core.nEASY_DIFFICULTY then 
			BotEcho("RandomAggression: "..tostring(core.bEasyRandomAggression)) 
		end
		BotEcho(format("  HarassHeroNewUtility: %g", nUtility))
	end

	return nUtility
end

function behaviorLib.HarassHeroExecute(botBrain)
	local bDebugEchos = false
	--[[
	if object.myName == "Bot1" then
		bDebugEchos = true
	end
	--]]

	local unitSelf = core.unitSelf
	local unitTarget = behaviorLib.heroTarget
	local vecTargetPos = (unitTarget and unitTarget:GetPosition()) or nil

	if bDebugEchos then BotEcho("Harassing "..((unitTarget~=nil and unitTarget:GetTypeName()) or "nil")) end
	if unitTarget and vecTargetPos then
		local nDistSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecTargetPos)
		local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget, true)

		local itemGhostMarchers = core.itemGhostMarchers

		--BotEcho('canSee: '..tostring(core.CanSeeUnit(botBrain, unitTarget)))
		--BotEcho(format("nDistSq: %d  nAttackRangeSq: %d   attackReady: %s  canSee: %s", nDistSq, nAttackRangeSq, tostring(unitSelf:IsAttackReady()), tostring(core.CanSeeUnit(botBrain, unitTarget))))
		
		--only attack when in nRange, so not to aggro towers/creeps until necessary, and move forward when attack is on cd
		if nDistSq < nAttackRangeSq and unitSelf:IsAttackReady() and core.CanSeeUnit(botBrain, unitTarget) then
			local bInTowerRange = core.NumberElements(core.GetTowersThreateningUnit(unitSelf)) > 0
			local bShouldDive = behaviorLib.lastHarassUtil >= behaviorLib.diveThreshold
			
			if bDebugEchos then BotEcho(format("inTowerRange: %s  bShouldDive: %s", tostring(bInTowerRange), tostring(bShouldDive))) end
			
			if not bInTowerRange or bShouldDive then
				if bDebugEchos then BotEcho("ATTAKIN NOOBS! divin: "..tostring(bShouldDive)) end
				core.OrderAttackClamp(botBrain, unitSelf, unitTarget)
			end
		else
			if bDebugEchos then BotEcho("MOVIN OUT") end
			local vecDesiredPos = vecTargetPos
			local bUseTargetPosition = true

			--leave some space if we are ranged
			if unitSelf:GetAttackRange() > 200 then
				vecDesiredPos = vecTargetPos + Vector3.Normalize(unitSelf:GetPosition() - vecTargetPos) * behaviorLib.rangedHarassBuffer
				bUseTargetPosition = false
			end

			if itemGhostMarchers and itemGhostMarchers:CanActivate() then
				core.OrderItemClamp(botBrain, unitSelf, itemGhostMarchers)
				return
			else
				local bChanged = false
				local bWellDiving = false
				vecDesiredPos, bChanged, bWellDiving = core.AdjustMovementForTowerLogic(vecDesiredPos)
				
				if bDebugEchos then BotEcho("Move - bChanged: "..tostring(bChanged).."  bWellDiving: "..tostring(bWellDiving)) end
				
				if not bWellDiving then
					if behaviorLib.lastHarassUtil < behaviorLib.diveThreshold then
						if bDebugEchos then BotEcho("DON'T DIVE!") end
										
						if bUseTargetPosition and not bChanged then
							core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget, false)
						else
							core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, vecDesiredPos, false)
						end
					else
						if bDebugEchos then BotEcho("DIVIN Tower! util: "..behaviorLib.lastHarassUtil.." > "..behaviorLib.diveThreshold) end
						core.OrderMoveToPosClamp(botBrain, unitSelf, vecDesiredPos, false)
					end
				else
					return false
				end
			end

			--core.DrawXPosition(vecDesiredPos, 'blue')
		end
	else
		return false
	end
end

behaviorLib.HarassHeroBehavior = {}
behaviorLib.HarassHeroBehavior["Utility"] = behaviorLib.HarassHeroUtility
behaviorLib.HarassHeroBehavior["Execute"] = behaviorLib.HarassHeroExecute
behaviorLib.HarassHeroBehavior["Name"] = "HarassHero"
tinsert(behaviorLib.tBehaviors, behaviorLib.HarassHeroBehavior)


----------------------------------
--	HitBuilding behavior
--
--	Utility: {23,25,36,40} if a {repeater,tower,rax,mainBase} is in range, not invulnerable, and wont aggro the tower
--	Execute: Attacks the building
----------------------------------

behaviorLib.hitBuildingTarget = nil

-------- Behavior Fns --------
function behaviorLib.HitBuildingUtility(botBrain)

	local bDebugLines = false
	local bDebugEchos = false
	local lineLen = 150

	local throneUtil = 40
	local raxUtil = 36
	local towerUtil = 25
	local otherBuildingUtil = 23

	local utility = 0
	local unitSelf = core.unitSelf
	
	local nRange = core.GetAbsoluteAttackRange(unitSelf)
	if core.unitSelf:GetAttackType() == "melee" then
		--override melee so they don't stand *just* out of range
		nRange = 250
	end

	local tBuildings = core.localUnits["EnemyBuildings"]
	if unitSelf:IsAttackReady() then
		local target = nil

		local sortedBuildings = {}
		core.SortBuildings(tBuildings, sortedBuildings)

		--main base
		local unitBase = sortedBuildings.enemyMainBaseStructure
		if unitBase and not unitBase:IsInvulnerable() then
			local nExtraRange = core.GetExtraRange(unitBase)
			if core.IsUnitInRange(unitSelf, unitBase, nRange + nExtraRange) and core.CanSeeUnit(botBrain, unitBase) then
				target = unitBase
				utility = throneUtil
			end
		end
		
		--rax
		if target == nil and core.NumberElements(sortedBuildings.enemyRax) > 0 then
			local targetRax = nil
			local tRax = sortedBuildings.enemyRax
			for id, rax in pairs(tRax) do
				local nExtraRange = core.GetExtraRange(rax)
				if not rax:IsInvulnerable() and core.IsUnitInRange(unitSelf, rax, nRange + nExtraRange) and core.CanSeeUnit(botBrain, rax) then
					if targetRax == nil or not targetRax:IsUnitType("MeleeRax") then --prefer melee rax
						targetRax = rax
					end
				end
			end
			
			if targetRax ~= nil then
				--BotEcho(targetRax:GetTypeName())
				target = targetRax
				utility = raxUtil
			end
		end
		
		--tower
		if target == nil and core.NumberElements(sortedBuildings.enemyTowers) > 0 then
			if core.NumberElements(core.localUnits["EnemyUnits"]) <= 0 then
				local tTowers = sortedBuildings.enemyTowers
				for id, tower in pairs(tTowers) do
					local nExtraRange = core.GetExtraRange(tower)
				
					--BotEcho("Checking tower "..tower:GetTypeName().."  inRange: "..tostring(core.IsUnitInRange(unitSelf, tower)).."  isSafe: "..tostring(core.IsTowerSafe(tower, unitSelf, core.localUnits)))
					if not tower:IsInvulnerable() and core.IsUnitInRange(unitSelf, tower, nRange + nExtraRange) and core.CanSeeUnit(botBrain, tower) then
						if core.IsTowerSafe(tower, unitSelf) then
							target = tower
							utility = towerUtil
							break
						end
					end
				end
			end
		end
				
		--attack buildings
		if target == nil and core.NumberElements(sortedBuildings.enemyOtherBuildings) > 0 then
			local tOtherBuildings = sortedBuildings.enemyOtherBuildings
			for id, building in pairs(tOtherBuildings) do
				local nExtraRange = core.GetExtraRange(building)
				if not building:IsInvulnerable() and core.IsUnitInRange(unitSelf, building, nRange + nExtraRange) and core.CanSeeUnit(botBrain, building) then
					target = building
					utility = otherBuildingUtil
					break
				end
			end
		end
		
		behaviorLib.hitBuildingTarget = target
	end

	if bDebugLines then
		local myPos = unitSelf:GetPosition()
		local myRange = unitSelf:GetAttackRange()
		local myExtraRange = core.GetExtraRange(unitSelf)

		for id, building in pairs(tBuildings) do
			if building:GetTeam() ~= core.myTeam then
				local buildingPos = building:GetPosition()
				local nBuildingExtraRange = core.GetExtraRange(building)
				local vTowards = Vector3.Normalize(buildingPos - myPos)
				local vOrtho = Vector3.Create(-vTowards.y, vTowards.x) --quick 90 rotate z
				core.DrawDebugLine( myPos, myPos + vTowards * (myRange + myExtraRange), 'orange')
				core.DrawDebugLine( (myPos + vTowards * myRange) - (vOrtho * 0.5 * lineLen/2),
										(myPos + vTowards * myRange) + (vOrtho * 0.5 * lineLen/2), 'orange')

				core.DrawDebugLine( (myPos + vTowards * (myRange + myExtraRange)) - (vOrtho * 0.5 * lineLen),
										(myPos + vTowards * (myRange + myExtraRange)) + (vOrtho * 0.5 * lineLen), 'orange')
										
				
				core.DrawDebugLine( (buildingPos - vTowards * nBuildingExtraRange) - (vOrtho * 0.5 * lineLen),
										(buildingPos - vTowards * nBuildingExtraRange) + (vOrtho * 0.5 * lineLen), 'yellow')
			end
		end
	end
	
	if bDebugEchos then
		core.printGetTypeNameTable(tBuildings)
	end

	if botBrain.bDebugUtility == true and utility ~= 0 then
		BotEcho(format("  HitBuildingUtility: %g", utility))
	end

	return utility
end

function behaviorLib.HitBuildingExecute(botBrain)
	local unitSelf = core.unitSelf
	local target = behaviorLib.hitBuildingTarget

	if target ~= nil then
		core.OrderAttackClamp(botBrain, unitSelf, target)
	end
end

behaviorLib.HitBuildingBehavior = {}
behaviorLib.HitBuildingBehavior["Utility"] = behaviorLib.HitBuildingUtility
behaviorLib.HitBuildingBehavior["Execute"] = behaviorLib.HitBuildingExecute
behaviorLib.HitBuildingBehavior["Name"] = "HitBuilding"
tinsert(behaviorLib.tBehaviors, behaviorLib.HitBuildingBehavior)


----------------------------------
--	Push behavior
--
--	Utility: 0 to 30 based on whether or not the enemy heroes are dead and how strong your pushing power is
--	Execute: Moves to and attacks creeps when in range, falling back to HitBuilding when there are no creeps
----------------------------------

behaviorLib.enemiesDeadUtilMul = 0.5
behaviorLib.pushingStrUtilMul = 0.3
behaviorLib.nTeamPushUtilityMul = 0.3
behaviorLib.nDPSPushWeight = 0.8
behaviorLib.pushingCap = 22

function behaviorLib.EnemiesDeadPushUtility(enemyTeam)
	local enemyHeroes = HoN.GetHeroes(enemyTeam)
	local bHeroesAlive = false
	for id, hero in pairs(enemyHeroes) do
		--BotEcho(hero:GetTypeName()..": "..tostring(hero:IsAlive()))
		if hero:IsAlive() then
			bHeroesAlive = true
			break
		end
	end

	local util = 0

	if not bHeroesAlive and core.NumberElements(enemyHeroes) > 0 then
		util = 100
	end

	--BotEcho("enemiesDead: "..heroesDead.."  totalEnemies: "..core.NumberElements(enemyHeroes))

	return util
end

function behaviorLib.DPSPushingUtility(myHero)
	local myDamage = core.GetFinalAttackDamageAverage(myHero)
	local myAttackDuration = myHero:GetAdjustedAttackDuration()
	local myDPS = myDamage * 1000 / (myAttackDuration) --ms to s
	
	local vTop = Vector3.Create(300, 100)
	local vBot = Vector3.Create(100, 0)
	local m = ((vTop.y - vBot.y)/(vTop.x - vBot.x))
	local b = vBot.y - m * vBot.x 
	
	local util = m * myDPS + b
	util = Clamp(util, 0, 100)
	
	--BotEcho(format("MyDPS: %g  util: %g  myMin: %g  myMax: %g  myAttackAverageL %g", 
	--	myDPS, util, myHero:GetFinalAttackDamageMin(), myHero:GetFinalAttackDamageMax(), myDamage))
	
	return util
end

function behaviorLib.PushingStrengthUtility(myHero)
	local nUtility = 0
	
	nUtility = behaviorLib.DPSPushingUtility(myHero) * behaviorLib.nDPSPushWeight
	
	nUtility = Clamp(nUtility, 0, 100)
	
	return nUtility
end

function behaviorLib.TeamPushUtility()
	local nUtility = core.teamBotBrain:PushUtility()
	return nUtility
end


-------- Behavior Fns --------
function behaviorLib.PushUtility(botBrain)
--TODO: factor in:
	--how strong are we here? (allies close, pushing ability, hp/mana)
	--what defenses can they mount (potential enemies close, threat, anti-push, time until response)
	--how effective/how much can we hope to acomplish (time cost, weakness of target)

	--For now: push when they have dudes down and as I grow stronger

	local utility = 0
	local enemiesDeadUtil = behaviorLib.EnemiesDeadPushUtility(core.enemyTeam)
	local pushingStrUtil = behaviorLib.PushingStrengthUtility(core.unitSelf)
	local nTeamPushUtility = behaviorLib.TeamPushUtility()

	enemiesDeadUtil = enemiesDeadUtil * behaviorLib.enemiesDeadUtilMul
	pushingStrUtil = pushingStrUtil * behaviorLib.pushingStrUtilMul
	nTeamPushUtility = nTeamPushUtility * behaviorLib.nTeamPushUtilityMul

	utility = enemiesDeadUtil + pushingStrUtil + nTeamPushUtility
	utility = Clamp(utility, 0, behaviorLib.pushingCap)

	--BotEcho(format("PushUtil: %g  enemyDeadUtil: %g  pushingStrUtil: %g", utility, enemiesDeadUtil, pushingStrUtil))

	if botBrain.bDebugUtility == true and utility ~= 0 then
		BotEcho(format("  PushUtility: %g", utility))
	end

	return utility
end

function behaviorLib.PushExecute(botBrain)

	local bDebugLines = false
	
	--if botBrain.myName == 'ShamanBot' then bDebugLines = true end
	
	if core.unitSelf:IsChanneling() then 
		return
	end

	local unitSelf = core.unitSelf
	local bActionTaken = false

	--Turn on Ring of the Teacher if we have it
	if bActionTaken == false then
		local itemRoT = core.itemRoT
		
		if itemRoT then
			itemRoT:Update()
			
			if itemRoT.bHeroesOnly then			
				if bDebugEchos then BotEcho("Turning on RoTeacher") end
				bActionTaken = core.OrderItemClamp(botBrain, unitSelf, core.itemRoT)
			end
		end
	end
	
	--Attack creeps if we're in range
	if bActionTaken == false then
		local unitTarget = core.unitEnemyCreepTarget
		if unitTarget then
			if bDebugEchos then BotEcho("Attacking creeps") end
			local nRange = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
			if unitSelf:GetAttackType() == "melee" then
				--override melee so they don't stand *just* out of range
				nRange = 250
			end
			
			if unitSelf:IsAttackReady() and core.IsUnitInRange(unitSelf, unitTarget, nRange) then
				bActionTaken = core.OrderAttackClamp(botBrain, unitSelf, unitTarget)
			end
			
			if bDebugLines then core.DrawXPosition(unitTarget:GetPosition(), 'red', 125) end
		end
	end
	
	if bActionTaken == false then
		local vecDesiredPos = behaviorLib.PositionSelfLogic(botBrain)
		if vecDesiredPos then
			if bDebugEchos then BotEcho("Moving out") end
			bActionTaken = behaviorLib.MoveExecute(botBrain, vecDesiredPos)
			
			if bDebugLines then core.DrawXPosition(vecDesiredPos, 'blue') end
		end
	end
	
	if bActionTaken == false then
		return false
	end
end

behaviorLib.PushBehavior = {}
behaviorLib.PushBehavior["Utility"] = behaviorLib.PushUtility
behaviorLib.PushBehavior["Execute"] = behaviorLib.PushExecute
behaviorLib.PushBehavior["Name"] = "Push"
tinsert(behaviorLib.tBehaviors, behaviorLib.PushBehavior)


----------------------------------
--	TeamGroup behavior
--
--	Utility: 35 if the teambrain wants us to group up, 0 otherwise
--	Execute: Go to the rally point
----------------------------------
behaviorLib.nTeamGroupUtilityMul = 0.35
function behaviorLib.TeamGroupUtility(botBrain)
	local nUtility = 0

	if core.teamBotBrain then
		nUtility = core.teamBotBrain:GroupUtility()
	end

	nUtility = nUtility * behaviorLib.nTeamGroupUtilityMul

	if botBrain.bDebugUtility == true and nUtility ~= 0 then
		BotEcho(format("  TeamGroupUtility: %g", nUtility))
	end

	return nUtility
end

behaviorLib.nNextGroupMessage = 0
function behaviorLib.TeamGroupExecute(botBrain)
	local unitSelf = core.unitSelf
	local teamBotBrain = core.teamBotBrain
	local nCurrentTimeMS = HoN.GetGameTime()
	
	local vecRallyPoint = teamBotBrain:GetGroupRallyPoint()
	if vecRallyPoint then
		local nCurrentTime = HoN.GetGameTime()
		--Chat about it
		if behaviorLib.nNextGroupMessage < nCurrentTime then
			if behaviorLib.nNextGroupMessage == 0 then
				behaviorLib.nNextGroupMessage = nCurrentTime
			end

			local nDelay = random(core.nChatDelayMin, core.nChatDelayMax)
			local tLane = teamBotBrain:GetDesiredLane(unitSelf)
			local sLane = (tLane and tLane.sLaneName) or "nil"
			core.TeamChatLocalizedMessage("group_up", {lane=sLane}, nDelay)
			behaviorLib.nNextGroupMessage = nCurrentTime + core.MinToMS(1)
		end
		
		--Do it
		local nDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecRallyPoint)
		local nCloseEnoughSq = teamBotBrain.nGroupUpRadius - 100
		nCloseEnoughSq = nCloseEnoughSq * nCloseEnoughSq
		if nDistanceSq < nCloseEnoughSq then
			core.OrderAttackPositionClamp(botBrain, unitSelf, vecRallyPoint, false)
		else
			behaviorLib.MoveExecute(botBrain, vecRallyPoint)
		end
	else
		BotEcho("nil rally point!")
	end

	return
end

behaviorLib.TeamGroupBehavior = {}
behaviorLib.TeamGroupBehavior["Utility"] = behaviorLib.TeamGroupUtility
behaviorLib.TeamGroupBehavior["Execute"] = behaviorLib.TeamGroupExecute
behaviorLib.TeamGroupBehavior["Name"] = "TeamGroup"
tinsert(behaviorLib.tBehaviors, behaviorLib.TeamGroupBehavior)


----------------------------------
--	TeamDefend behavior
--
--	Utility: 23 if the teambrain wants us to defend a building, 0 otherwise
--	Execute: Go to the building and attack creeps when you get there
----------------------------------
behaviorLib.nTeamDefendUtilityVal = 23
behaviorLib.unitDefendTarget = nil
function behaviorLib.TeamDefendUtility(botBrain)
	local nUtility = 0

	if core.teamBotBrain then
		behaviorLib.unitDefendTarget = core.teamBotBrain:GetDefenseTarget(core.unitSelf)
		
		if behaviorLib.unitDefendTarget then
			nUtility = behaviorLib.nTeamDefendUtilityVal
		end
	end

	if (botBrain.bDebugUtility == true) and nUtility ~= 0 then
		BotEcho(format("  TeamDefendUtility: %g", nUtility))
	end

	return nUtility
end

function behaviorLib.TeamDefendExecute(botBrain)
	local unitSelf = core.unitSelf
	local teamBotBrain = core.teamBotBrain
	
	local unitDefendTarget = behaviorLib.unitDefendTarget
	if unitDefendTarget then
		local vecTargetPosition = unitDefendTarget:GetPosition()
	
		local nCurrentTime = HoN.GetGameTime()
		--Chat about it
		if behaviorLib.nNextGroupMessage < nCurrentTime then
			if behaviorLib.nNextGroupMessage == 0 then
				behaviorLib.nNextGroupMessage = nCurrentTime
			end

			local nDelay = random(core.nChatDelayMin, core.nChatDelayMax)
			local tLane = teamBotBrain:GetDesiredLane(unitSelf)
			local sLane = (tLane and tLane.sLaneName) or "nil"
			core.TeamChatLocalizedMessage("defend", {lane=sLane}, nDelay)
			behaviorLib.nNextGroupMessage = nCurrentTime + core.MinToMS(1)
		end
		
		--Do it
		local nDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecTargetPosition)
		local nCloseEnough = core.teamBotBrain.nDefenseInRangeRadius
		if nDistanceSq < nCloseEnough * nCloseEnough then
			core.OrderAttackPositionClamp(botBrain, unitSelf, vecTargetPosition, false)
		else
			behaviorLib.MoveExecute(botBrain, vecTargetPosition)
		end
	else
		BotEcho("nil defense target!")
		return false
	end

	return
end

behaviorLib.TeamDefendBehavior = {}
behaviorLib.TeamDefendBehavior["Utility"] = behaviorLib.TeamDefendUtility
behaviorLib.TeamDefendBehavior["Execute"] = behaviorLib.TeamDefendExecute
behaviorLib.TeamDefendBehavior["Name"] = "TeamDefend"
tinsert(behaviorLib.tBehaviors, behaviorLib.TeamDefendBehavior)


----------------------------------
--	DontBreakChannel behavior
--
--	Utility: 100 if you are channeling, 0 otherwise
--	Execute: Do nothing
----------------------------------
function behaviorLib.DontBreakChannelUtility(botBrain)
	local utility = 0

	if core.unitSelf:IsChanneling() then
		utility = 100
	end

	if botBrain.bDebugUtility == true and utility ~= 0 then
		BotEcho(format("  DontBreakChannelUtility: %g", utility))
	end

	return utility
end

function behaviorLib.DontBreakChannelExecute(botBrain)
	--do nothing

	return
end

behaviorLib.DontBreakChannelBehavior = {}
behaviorLib.DontBreakChannelBehavior["Utility"] = behaviorLib.DontBreakChannelUtility
behaviorLib.DontBreakChannelBehavior["Execute"] = behaviorLib.DontBreakChannelExecute
behaviorLib.DontBreakChannelBehavior["Name"] = "DontBreakChannel"
tinsert(behaviorLib.tBehaviors, behaviorLib.DontBreakChannelBehavior)


--------------------------------------
--          UseHealthRegen          --
--------------------------------------
--
-- Utility: 0 to 40
-- Based on missing health
--
-- Execute: 
-- Use a Rune of the Blight, Health Pot, or Bottle to heal
-- Will only use Health Pot or Bottle if it is safe
--

-------- Global Constants & Variables --------
behaviorLib.bUseBatterySupplyForHealth = true
behaviorLib.bUseBatterySupplyForMana = true
behaviorLib.bUseBottleForHealth = true
behaviorLib.bUseBottleForMana = true

behaviorLib.safeTreeAngle = 120

-------- Helper Functions --------
function behaviorLib.GetSafeDrinkDirection()
	-- Returns vector to a safe direciton to retreat to drink if the bot is threatened
	-- Returns nil if safe
	local vecSafeDirection = nil
	local unitSelf = core.unitSelf
	local vecSelfPos = unitSelf:GetPosition()
	local nMyID = unitSelf:GetUniqueID()
	local tThreateningUnits = {}
	local tUnitThreatenedRadius = {}
	
	for _, unitEnemy in pairs(core.localUnits["EnemyUnits"]) do
		-- Ignore creeps that are already attacking something
		local unitEnemyTarget = unitEnemy:GetAttackTarget()
		if not (core.IsLaneCreep(unitEnemy) and unitEnemyTarget and unitEnemyTarget:GetUniqueID() ~= nMyID) then
			local nAbsRange = core.GetAbsoluteAttackRangeToUnit(unitEnemy, unitSelf) + 325
			local nAbsRangeSq = nAbsRange * nAbsRange
			local nDistSq = Vector3.Distance2DSq(vecSelfPos, unitEnemy:GetPosition())
			if nDistSq < nAbsRangeSq then
				tinsert(tThreateningUnits, unitEnemy)
				tinsert(tUnitThreatenedRadius, nAbsRange)
			end
		end
	end

	local curTimeMS = HoN.GetGameTime()
	local nThreateningUnits = core.NumberElements(tThreateningUnits)
	if nThreateningUnits > 0 or eventsLib.recentDotTime > curTimeMS or #eventsLib.incomingProjectiles["all"] > 0 then
		-- Determine best "away from threat" vector
		local vecAway = Vector3.Create()
		for nIndex, unitEnemy in pairs(tThreateningUnits) do
			local vecAwayFromTarget = Vector3.Normalize(vecSelfPos - unitEnemy:GetPosition())
			vecAway = vecAway + vecAwayFromTarget * tUnitThreatenedRadius[nIndex]
		end
		
		-- Average vecAway with "retreat" vector
		local vecRetreat = Vector3.Normalize(behaviorLib.PositionSelfBackUp() - vecSelfPos)
		local vecSafeDirection = Vector3.Normalize(vecAway + vecRetreat)
	end

	return vecSafeDirection
end

------------------------------------
--   Mana Battery/PowerSupply     --
------------------------------------

function behaviorLib.GetBatterySupplyFromInventory()
	-- Returns Mana Battery or Power Supply if they are in the bot's inventory
	-- else returns nil
	
	local unitSelf = core.unitSelf
	local tInventory = unitSelf:GetInventory()
	local tManaBattery = core.InventoryContains(tInventory, "Item_ManaBattery")
	local tPowerSupply = core.InventoryContains(tInventory, "Item_PowerSupply")
	
	if not core.IsTableEmpty(tManaBattery) then
		return tManaBattery[1]
	elseif not core.IsTableEmpty(tPowerSupply) then
		return tPowerSupply[1]
	end
	
	return nil
end

function behaviorLib.BatterySupplyHealthUtilFn(nHealthMissing, nCharges)
	-- With 1 Charge:
	-- Roughly 20+ when we are missing 30 health
	-- Function which crosses 20 at x=30 and 30 at x=140, convex down
	-- With 15 Charges:
	-- Roughly 20+ when we are missing 170 health
	-- Function which crosses 20 at x=170 and 30 at x=330, convex down
	if (not behaviorLib.bUseBatterySupplyForHealth) then
		return 0
	end
	
	local nHealAmount = 10 * nCharges
	local nHealBuffer = 20
	local nUtilityThreshold = 20
	
	local vecPoint = Vector3.Create(nHealAmount + nHealBuffer, nUtilityThreshold)
	local vecOrigin = Vector3.Create(-250, -30)
	
	return core.ATanFn(nHealthMissing, vecPoint, vecOrigin, 100)
end

function behaviorLib.BatterySupplyManaUtilFn(nManaMissing, nCharges)
	-- With 1 Charge:
	-- Roughly 20+ when we are missing 40 mana
	-- Function which crosses 20 at x=40 and 30 at x=100, convex down
	-- With 15 Charges:
	-- Roughly 20+ when we are missing 280 mana
	-- Function which crosses 20 at x=280 and 30 at x=470, convex down
	if (not behaviorLib.bUseBatterySupplyForMana) then
		return 0
	end
	
	local nManaRegenAmount = 15 * nCharges
	local nManaBuffer = 25
	local nUtilityThreshold = 20
	
	local vecPoint = Vector3.Create(nManaRegenAmount + nManaBuffer, nUtilityThreshold)
	local vecOrigin = Vector3.Create(-60, -50)
	
	return core.ATanFn(nManaMissing, vecPoint, vecOrigin, 100)
end

function behaviorLib.UseBatterySupplyUtility(botBrain)
	local unitSelf = core.unitSelf
	local nHealthMissing = unitSelf:GetMaxHealth() - unitSelf:GetHealth()
	local nManaMissing = unitSelf:GetMaxMana() - unitSelf:GetMana()
	local itemBatterySupply = behaviorLib.GetBatterySupplyFromInventory()
	
	if itemBatterySupply ~= nil and itemBatterySupply:CanActivate() then
		local nCharges = itemBatterySupply:GetCharges()
		local nBatterySupplyHealthUtility = behaviorLib.BatterySupplyHealthUtilFn(nHealthMissing, nCharges)
		local nBatterySupplyManaUtility = behaviorLib.BatterySupplyManaUtilFn(nManaMissing, nCharges)
		
		return max(
			nBatterySupplyHealthUtility * .8 + nBatterySupplyManaUtility * .2, --health
			nBatterySupplyManaUtility * .8 + nBatterySupplyHealthUtility * .2  --mana
			)
	end
	
	return 0
end

function behaviorLib.UseBatterySupplyExecute(botBrain)
	local unitSelf = core.unitSelf
	local tInventory = unitSelf:GetInventory()
	local bActionTaken = false
	
	-- Use Mana Battery/Power Supply to heal
	local itemBatterySupply = behaviorLib.GetBatterySupplyFromInventory(tInventory)
	if itemBatterySupply ~= nil and itemBatterySupply:GetCharges() > 0 then
		bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemBatterySupply)
	end
	
	return bActionTaken
end
behaviorLib.UseBatterySupplyBehavior = {}
behaviorLib.UseBatterySupplyBehavior["Utility"] = behaviorLib.UseBatterySupplyUtility
behaviorLib.UseBatterySupplyBehavior["Execute"] = behaviorLib.UseBatterySupplyExecute
behaviorLib.UseBatterySupplyBehavior["Name"] = "UseBatterySupply"
tinsert(behaviorLib.tBehaviors, behaviorLib.UseBatterySupplyBehavior)

------------------------------------
--       Runes OfThe Blight       --
------------------------------------
function behaviorLib.UseRunesOfTheBlightUtility(botBrain)
	-- Roughly 20+ when we are missing 115 hp
	-- Function which crosses 20 at x=115 and is 30 at roughly x=600, convex down

	local unitSelf = core.unitSelf
	local tInventory = unitSelf:GetInventory()
	local tBlights = core.InventoryContains(tInventory, "Item_RunesOfTheBlight")
	
	if not core.IsTableEmpty(tBlights) and not unitSelf:HasState("State_RunesOfTheBlight") then
		local unitSelf = core.unitSelf
		local nHealthMissing = unitSelf:GetMaxHealth() - unitSelf:GetHealth()
		local nHealthRegen = unitSelf:GetHealthRegen()
		local nHealAmount = 115
		local nHealBuffer = nHealthRegen * 16
		local nUtilityThreshold = 20
			
		local vecPoint = Vector3.Create(nHealAmount + nHealBuffer, nUtilityThreshold)
		local vecOrigin = Vector3.Create(-1000, -20)
		
		return core.ATanFn(nHealthMissing, vecPoint, vecOrigin, 100)
	end
	
	return 0
end

function behaviorLib.UseRunesOfTheBlightExecute(botBrain)
	local unitSelf = core.unitSelf
	local vecSelfPos = unitSelf:GetPosition()
	local tInventory = unitSelf:GetInventory()
	local tBlights = core.InventoryContains(tInventory, "Item_RunesOfTheBlight")
	local bActionTaken = false
	local unitClosestTree = nil
	local nClosestTreeDistSq = 9999 * 9999
	local vecLaneForward = object.vecLaneForward
	local vecLaneForwardNeg = -vecLaneForward
	local funcRadToDeg = core.RadToDeg
	local funcAngleBetween = core.AngleBetween
	local nHalfSafeTreeAngle = behaviorLib.safeTreeAngle / 2

	if not core.IsTableEmpty(tBlights) then
		core.UpdateLocalTrees()
		local tTrees = core.localTrees
		for _, unitTree in pairs(tTrees) do
			vecTreePosition = unitTree:GetPosition()
			-- "Safe" trees are backwards
			if not vecLaneForward or abs(funcRadToDeg(funcAngleBetween(vecTreePosition - vecSelfPos, vecLaneForwardNeg)) ) < nHalfSafeTreeAngle then
				local nDistSq = Vector3.Distance2DSq(vecTreePosition, vecSelfPos)
				if nDistSq < nClosestTreeDistSq then
					unitClosestTree = unitTree
					nClosestTreeDistSq = nDistSq
					if bDebugLines then
						core.DrawXPosition(vecTreePosition, 'yellow')
					end
				end
			end
		end
		if unitClosestTree ~= nil then
			bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, tBlights[1], unitClosestTree)
		end
	end
		
	return bActionTaken
end
behaviorLib.UseRunesOfTheBlightBehavior = {}
behaviorLib.UseRunesOfTheBlightBehavior["Utility"] = behaviorLib.UseRunesOfTheBlightUtility
behaviorLib.UseRunesOfTheBlightBehavior["Execute"] = behaviorLib.UseRunesOfTheBlightExecute
behaviorLib.UseRunesOfTheBlightBehavior["Name"] = "UseRunesOfTheBlight"
tinsert(behaviorLib.tBehaviors, behaviorLib.UseRunesOfTheBlightBehavior)

------------------------------------
--          Health Potion         --
------------------------------------
function behaviorLib.UseHealthPotUtility(botBrain)
	-- Roughly 20+ when we are missing 400 hp
	-- Function which crosses 20 at x=400 and 40 at x=650, convex down

	local unitSelf = core.unitSelf
	local tInventory = unitSelf:GetInventory()
	local tHealthPots = core.InventoryContains(tInventory, "Item_HealthPotion")
	
	if not core.IsTableEmpty(tHealthPots) and not unitSelf:HasState("State_HealthPotion") then	
		local nHealthMissing = unitSelf:GetMaxHealth() - unitSelf:GetHealth()
		local nHealthRegen = unitSelf:GetHealthRegen()
		local nHealAmount = 400
		local nHealBuffer = nHealthRegen * 10
		local nUtilityThreshold = 20
		
		local vecPoint = Vector3.Create(nHealAmount, nUtilityThreshold)
		local vecOrigin = Vector3.Create(200, -40)
		return core.ATanFn(nHealthMissing, vecPoint, vecOrigin, 100)
	end
	
	return 0
end

function behaviorLib.UseHealthPotExecute(botBrain)
	local bActionTaken = false
	local unitSelf = core.unitSelf
	local vecSelfPos = unitSelf:GetPosition()
	local tInventory = unitSelf:GetInventory()
	local tHealthPots = core.InventoryContains(tInventory, "Item_HealthPotion")
	
	if not core.IsTableEmpty(tHealthPots) then
		local vecRetreatDirection = behaviorLib.GetSafeDrinkDirection()
		-- Check if it is safe to drink
		if vecRetreatDirection then
			bActionTaken = core.OrderMoveToPosClamp(botBrain, unitSelf, vecSelfPos + vecRetreatDirection * core.moveVecMultiplier, false)
		else
			bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, tHealthPots[1], unitSelf)
		end
	end
	
	return bActionTaken
end

behaviorLib.UseHealthPotBehavior = {}
behaviorLib.UseHealthPotBehavior["Utility"] = behaviorLib.UseHealthPotUtility
behaviorLib.UseHealthPotBehavior["Execute"] = behaviorLib.UseHealthPotExecute
behaviorLib.UseHealthPotBehavior["Name"] = "UseHealthPot"
tinsert(behaviorLib.tBehaviors, behaviorLib.UseHealthPotBehavior)

------------------------------------
--             Bottle             --
------------------------------------
function behaviorLib.BottleHealthUtilFn(nHealthMissing, nHealthRegen)
	-- Roughly 20+ when we are missing 135 hp
	-- Function which crosses 20 at x=135 and 30 at x=220, convex down
	if (not behaviorLib.bUseBottleForHealth) then
		return 0
	end
	
	local nHealAmount = 135
	local nHealBuffer = nHealthRegen * 3
	local nUtilityThreshold = 20

	local vecPoint = Vector3.Create(nHealAmount + nHealBuffer, nUtilityThreshold)
	local vecOrigin = Vector3.Create(-100, -30)
	
	return core.ATanFn(nHealthMissing, vecPoint, vecOrigin, 100)
end

function behaviorLib.BottleManaUtilFn(nManaMissing, nManaRegen)
	-- Roughly 20+ when we are missing 70 mana
	-- Function which crosses 20 at x=70 and 30 at x=140, convex down
	if (not behaviorLib.bUseBottleForMana) then
		return 0
	end
	
	local nManaRegenAmount = 70
	local nManaBuffer = nManaRegen * 3
	local nUtilityThreshold = 20
	
	local vecPoint = Vector3.Create(nManaRegenAmount + nManaBuffer, nUtilityThreshold)
	local vecOrigin = Vector3.Create(-125, -30)
	
	return core.ATanFn(nManaMissing, vecPoint, vecOrigin, 100)
end

function behaviorLib.UseBottleUtility(botBrain)
	local unitSelf = core.unitSelf
	local nHealthMissing = unitSelf:GetMaxHealth() - unitSelf:GetHealth()
	local nManaMissing = unitSelf:GetMaxMana() - unitSelf:GetMana()
	local nHealthRegen = unitSelf:GetHealthRegen()
	local nManaRegen = unitSelf:GetManaRegen()
	local tInventory = unitSelf:GetInventory()
	local tItemBottle = core.InventoryContains(tInventory, "Item_Bottle")
	
	if not core.IsTableEmpty(tItemBottle) and not unitSelf:HasState("State_Bottle") and tItemBottle[1]:GetActiveModifierKey() ~= "bottle_empty" then
		local nBottleHealthFn=behaviorLib.BottleHealthUtilFn(nHealthMissing, nHealthRegen)
		local nBottleManaFn=behaviorLib.BottleManaUtilFn(nManaMissing, nManaRegen)
		
		return max(
			nBottleHealthFn * .8 + nBottleManaFn * .2, --health
			nBottleManaFn * .8 + nBottleHealthFn * .2  --mana
			)
	end
	
	return 0
end

function behaviorLib.UseBottleExecute(botBrain)
	local bActionTaken = false
	local unitSelf = core.unitSelf
	local tInventory = unitSelf:GetInventory()
	local tItemBottle = core.InventoryContains(tInventory, "Item_Bottle")

	if not core.IsTableEmpty(tItemBottle) then
		local vecRetreatDirection = behaviorLib.GetSafeDrinkDirection()
		-- Check if it is safe to drink
		if vecRetreatDirection then
			bActionTaken = core.OrderMoveToPosClamp(botBrain, unitSelf, vecSelfPos + vecRetreatDirection * core.moveVecMultiplier, false)
		else
			bActionTaken = core.OrderItemClamp(botBrain, unitSelf, tItemBottle[1])
		end
	end
	
	return bActionTaken
end

behaviorLib.UseBottleBehavior = {}
behaviorLib.UseBottleBehavior["Utility"] = behaviorLib.UseBottleUtility
behaviorLib.UseBottleBehavior["Execute"] = behaviorLib.UseBottleExecute
behaviorLib.UseBottleBehavior["Name"] = "UseBottle"
tinsert(behaviorLib.tBehaviors, behaviorLib.UseBottleBehavior)

------------------------------------
--          Mana Potion           --
------------------------------------
function behaviorLib.UseManaPotUtility(botBrain)
	-- Roughly 20+ when we are missing 100 mana
	-- Function which crosses 20 at x=100 and 30 at x=200, convex down
	
	local unitSelf = core.unitSelf
	local tInventory = unitSelf:GetInventory()
	local tManaPots = core.InventoryContains(tInventory, "Item_ManaPotion")
	
	if not core.IsTableEmpty(tManaPots) and not unitSelf:HasState("State_ManaPotion") then	
		local nManaMissing = unitSelf:GetMaxMana() - unitSelf:GetMana()
		local nManaRegen = unitSelf:GetManaRegen()
		local nManaRegenAmount = 100
		local nManaBuffer = nManaRegen * 20
		local nUtilityThreshold = 20
		
		local vecPoint = Vector3.Create(nManaRegenAmount, nUtilityThreshold)
		local vecOrigin = Vector3.Create(-100, -45)
		
		return core.ATanFn(nManaMissing, vecPoint, vecOrigin, 100)
	end
	
	return 0
end

function behaviorLib.UseManaPotExecute(botBrain)
	local bActionTaken = false
	local unitSelf = core.unitSelf
	local vecSelfPos = unitSelf:GetPosition()
	local tInventory = unitSelf:GetInventory()
	local tManaPots = core.InventoryContains(tInventory, "Item_ManaPotion")
	
	if not core.IsTableEmpty(tManaPots) then
		local vecRetreatDirection = behaviorLib.GetSafeDrinkDirection()
		-- Check if it is safe to drink
		if vecRetreatDirection then
			bActionTaken = core.OrderMoveToPosClamp(botBrain, unitSelf, vecSelfPos + vecRetreatDirection * core.moveVecMultiplier, false)
		else
			bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, tManaPots[1], unitSelf)
		end
	end
		
	return bActionTaken
end

behaviorLib.UseManaPotBehavior = {}
behaviorLib.UseManaPotBehavior["Utility"] = behaviorLib.UseManaPotUtility
behaviorLib.UseManaPotBehavior["Execute"] = behaviorLib.UseManaPotExecute
behaviorLib.UseManaPotBehavior["Name"] = "UseManaPot"
tinsert(behaviorLib.tBehaviors, behaviorLib.UseManaPotBehavior)

----------------------------------
--	PositionSelf
--
--	Utility: 20 always.  This is effectively an "idle" behavior
--
--	Move forward in lane if no creeps are near
--	stay out of towers if they aren't aggro'd to another unit
--	Stand near target
--	Stand slightly appart from allyHeroes
--	Stand away from enemyHeroes and enemyCreeps
----------------------------------

-------- Behavior Fns --------
function behaviorLib.PositionSelfUtility(botBrain)
	local utility = 20

	if botBrain.bDebugUtility == true and utility ~= 0 then
		BotEcho(format("  PositionSelfUtility: %g", utility))
	end

	return utility
end

function behaviorLib.PositionSelfExecute(botBrain)
	local bDebugLines = false
	local bDebugEchos = false
	--[[
	if object.myName == "Bot1" then
		bDebugLines = true
		bDebugEchos = true
	end --]]
	
	local nCurrentTimeMS = HoN.GetGameTime()
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	
	if core.unitSelf:IsChanneling() then 
		return
	end
	
	--Turn off Ring of the Teacher if we have it
	local itemRoT = core.itemRoT
	if itemRoT then
		itemRoT:Update()
		
		if not itemRoT.bHeroesOnly then			
			core.OrderItemClamp(botBrain, unitSelf, core.itemRoT)
			return
		end
	end
	
	local vecDesiredPos = vecMyPosition
	local unitTarget = nil
	vecDesiredPos, unitTarget = behaviorLib.PositionSelfLogic(botBrain)

	if vecDesiredPos then
		behaviorLib.MoveExecute(botBrain, vecDesiredPos)
	else
		BotEcho("PositionSelfExecute - nil desired position")
		return false
	end

	if bDebugLines then
		if unitTarget ~= nil then
			core.DrawXPosition(unitTarget:GetPosition(), 'orange', 125)
		end

		if vecDesiredPos then
			core.DrawXPosition(vecDesiredPos, 'blue')
		end
	end
end

behaviorLib.PositionSelfBehavior = {}
behaviorLib.PositionSelfBehavior["Utility"] = behaviorLib.PositionSelfUtility
behaviorLib.PositionSelfBehavior["Execute"] = behaviorLib.PositionSelfExecute
behaviorLib.PositionSelfBehavior["Name"] = "PositionSelf"
tinsert(behaviorLib.tBehaviors, behaviorLib.PositionSelfBehavior)


----------------------------------
--	RetreatFromThreat
--
--	Utility: 0 to 100 based on recentDamage, creep aggro, and tower aggro
----------------------------------
--TODO: work in a "stand away from threatening heroes" behavior?

behaviorLib.nCreepAggroUtility = 25
behaviorLib.nRecentDamageMul = 0.35
behaviorLib.nTowerProjectileUtility = 33
behaviorLib.nTowerAggroUtility = 25

behaviorLib.retreatGhostMarchersThreshold = 30

behaviorLib.lastRetreatUtil = 0

function behaviorLib.PositionSelfBackUp()
	StartProfile('PositionSelfBackUp')
	
	local vecMyPos = core.unitSelf:GetPosition()
	local tLaneSet = core.tMyLane
	local nLaneSetSize = nil
	local vecDesiredPos = nil
	local nodePrev = nil
	local nPrevNode = nil

	if tLaneSet then
		nLaneSetSize = #tLaneSet
		nodePrev,nPrevNode = core.GetPrevWaypoint(tLaneSet, vecMyPos, core.bTraverseForward)
		if nodePrev then
			vecDesiredPos = nodePrev:GetPosition()
		end
	else
		BotEcho('PositionSelfBackUp - invalid lane set')
	end

	if nodePrev then
		local nodePrevPrev = nil
		if core.bTraverseForward and nPrevNode > 1 then
			nodePrevPrev = tLaneSet[nPrevNode - 1]
		elseif not core.bTraverseForward and nPrevNode < nLaneSetSize then
			nodePrevPrev = tLaneSet[nPrevNode + 1]
		end

		if nodePrevPrev ~= nil then
			local vecNodePrevPos = nodePrev:GetPosition()
			local vecNodePrevPrevPos = nodePrevPrev:GetPosition()
			local vecForward = Vector3.Normalize(vecNodePrevPos - vecNodePrevPrevPos)
			if core.RadToDeg(core.AngleBetween(vecNodePrevPos - vecMyPos, vecForward)) < 135 then
				vecDesiredPos = vecNodePrevPrevPos
			end
		end
	else
		--BotEcho('PositionSelfBackUp - unable to find previous node!')
	end
	
	if not vecDesiredPos then
		vecDesiredPos = core.allyWell:GetPosition()
	end

	StopProfile()
	return vecDesiredPos
end

-------- Behavior Fns --------
function behaviorLib.RetreatFromThreatUtility(botBrain)
	local bDebugEchos = false

	local unitSelf = core.unitSelf
	local tEnemyCreeps = core.localUnits["EnemyCreeps"]
	local tEnemyTowers = core.localUnits["EnemyTowers"]

	--Creep aggro
	local nCreepAggroUtility = 0
	for id, enemyCreep in pairs(tEnemyCreeps) do
		local unitAggroTarget = enemyCreep:GetAttackTarget()
		if unitAggroTarget and unitAggroTarget:GetUniqueID() == unitSelf:GetUniqueID() then
			nCreepAggroUtility = behaviorLib.nCreepAggroUtility
			break
		end
	end

	--RecentDamage	
	local nRecentDamage = (eventsLib.recentDamageTwoSec + eventsLib.recentDamageSec) / 2.0
	local nRecentDamageUtility = nRecentDamage * behaviorLib.nRecentDamageMul

	--Tower Aggro
	local nTowerAggroUtility = 0
	for id, tower in pairs(tEnemyTowers) do
		local unitAggroTarget = tower:GetAttackTarget()
		if bDebugEchos then BotEcho(tower:GetTypeName().." target: "..(unitAggroTarget and unitAggroTarget:GetTypeName() or 'nil')) end
		if unitAggroTarget ~= nil and unitAggroTarget == core.unitSelf then
			nTowerAggroUtility = behaivorLib.nTowerAggroUtility
			break
		end
	end
	
	local numTowerProj = #eventsLib.incomingProjectiles["towers"]
	local nTowerProjectilesUtility = numTowerProj * behaviorLib.nTowerProjectileUtility
	
	local nTowerUtility = max(nTowerProjectilesUtility, nTowerAggroUtility)
	
	--Total
	local nUtility = nCreepAggroUtility + nRecentDamageUtility + nTowerUtility
	
	
	if bDebugEchos then
		BotEcho(format("nRecentDmgUtil: %d  nRecentDamage: %g", nRecentDamageUtility, nRecentDamage))
		BotEcho(format("nTowerUtil: %d  max( nTowerProjectilesUtil: %d, nTowerAggroUtil: %d )", 
			nTowerUtility, nTowerProjectilesUtility, nTowerAggroUtility))
		BotEcho(format("util: %d  recentDmg: %d  tower: %d  creeps: %d", 
			nUtility, nRecentDamageUtility, nTowerUtility, nCreepAggroUtility))		
	end

	
	
	nUtility = Clamp(nUtility, 0, 100)
	behaviorLib.lastRetreatUtil = nUtility

	if botBrain.bDebugUtility == true and nUtility ~= 0 then
		BotEcho(format("  RetreatFromThreatUtility: %g", nUtility))
	end

	return nUtility
end

function behaviorLib.RetreatFromThreatExecute(botBrain)
	--Activate ghost marchers if we can
	local itemGhostMarchers = core.itemGhostMarchers
	if behaviorLib.lastRetreatUtil >= behaviorLib.retreatGhostMarchersThreshold and itemGhostMarchers and itemGhostMarchers:CanActivate() then
		core.OrderItemClamp(botBrain, core.unitSelf, itemGhostMarchers)
		return
	end

	local vecPos = behaviorLib.PositionSelfBackUp()
	core.OrderMoveToPosClamp(botBrain, core.unitSelf, vecPos, false)
end

behaviorLib.RetreatFromThreatBehavior = {}
behaviorLib.RetreatFromThreatBehavior["Utility"] = behaviorLib.RetreatFromThreatUtility
behaviorLib.RetreatFromThreatBehavior["Execute"] = behaviorLib.RetreatFromThreatExecute
behaviorLib.RetreatFromThreatBehavior["Name"] = "RetreatFromThreat"
tinsert(behaviorLib.tBehaviors, behaviorLib.RetreatFromThreatBehavior)


----------------------------------
--	HealAtWell
--
--	Utility: 0 to 100 based on proximity and current health/mana
----------------------------------

function behaviorLib.WellProximityUtility(nDist)
	local maxVal = 15
	local farX = 5000

	local util = 0
	util = util + core.ParabolicDecayFn(nDist, maxVal, farX)

	if nDist <= 600 then
		util = util + 20
	end

	util = Clamp(util, 0, 100)

	--BotEcho("WellProxUtil: "..util.."  nDist: "..nDist)
	return util
end

function behaviorLib.WellHealthUtility(healthPercent)
	local height = 100
	local vCriticalPoint = Vector3.Create(0.25, 20)

	local util = height / ( (height/vCriticalPoint.y) ^ (healthPercent/vCriticalPoint.x) )
	--BotEcho("WellHealthUtil: "..util.."  percent: "..healthPercent)
	return util
end

-------- Behavior Fns --------
function behaviorLib.HealAtWellUtility(botBrain)
	local utility = 0
	local hpPercent = core.unitSelf:GetHealthPercent()

	if hpPercent < 0.95 then
		local wellPos = (core.allyWell and core.allyWell:GetPosition()) or Vector3.Create()
		local nDist = Vector3.Distance2D(wellPos, core.unitSelf:GetPosition())

		utility = behaviorLib.WellHealthUtility(hpPercent) + behaviorLib.WellProximityUtility(nDist)
	end

	if botBrain.bDebugUtility == true and utility ~= 0 then
		BotEcho(format("  HealAtWellUtility: %g", utility))
	end

	return utility
end

function behaviorLib.HealAtWellExecute(botBrain)
	--BotEcho("Returning to well!")
	local wellPos = (core.allyWell and core.allyWell:GetPosition()) or behaviorLib.PositionSelfBackUp()
	core.OrderMoveToPosAndHoldClamp(botBrain, core.unitSelf, wellPos, false)
end

behaviorLib.HealAtWellBehavior = {}
behaviorLib.HealAtWellBehavior["Utility"] = behaviorLib.HealAtWellUtility
behaviorLib.HealAtWellBehavior["Execute"] = behaviorLib.HealAtWellExecute
behaviorLib.HealAtWellBehavior["Name"] = "HealAtWell"
tinsert(behaviorLib.tBehaviors, behaviorLib.HealAtWellBehavior)


----------------------------------
-- Shop
--
-- Utility: 99 if just entered well and not finished buying, 0 otherwise
----------------------------------

--TODO: separate "sort inventory and stash" into a second behavior so we can do so after using a TP in the well
--TODO: dynamic item builds
--TODO: dynamic regen purchases
--TODO: Courier use
--TODO: Use "CanAccessWellShop" instead of CanAccessStash

behaviorLib.nextBuyTime = HoN.GetGameTime()
behaviorLib.buyInterval = 1000
behaviorLib.finishedBuying = false
behaviorLib.canAccessShopLast = false

behaviorLib.printShopDebug = false

behaviorLib.BuyStateUnknown = 0
behaviorLib.BuyStateStartingItems = 1
behaviorLib.BuyStateLaneItems = 2
behaviorLib.BuyStateMidItems = 3
behaviorLib.BuyStateLateItems = 4
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
behaviorLib.StartingItems = {"2 Item_DuckBoots", "2 Item_MinorTotem", "Item_HealthPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = {"Item_Marchers", "2 Item_Soulscream", "Item_EnhancedMarchers"}
behaviorLib.MidItems = {"Item_Pierce 1", "Item_Immunity", "Item_Pierce 3"} --Pierce is Shieldbreaker, Immunity is Shrunken Head
behaviorLib.LateItems = {"Item_Weapon3", "Item_Sicarius", "Item_ManaBurn2", "Item_BehemothsHeart", "Item_Damage9" } --Weapon3 is Savage Mace. Item_Sicarius is Firebrand. ManaBurn2 is Geomenter's Bane. Item_Damage9 is Doombringer

behaviorLib.buyState = behaviorLib.BuyStateUnknown
behaviorLib.curItemList = {}
function behaviorLib.ProcessItemCode(itemCode)
	local num = 1
	local level = 1
	local item = itemCode
	local pos = strfind(itemCode, " ")
	if pos then
		local numTemp = strsub(itemCode, 1, pos - 1)
		if tonumber(numTemp) ~= nil then
			num = tonumber(numTemp)
			item = strsub(itemCode, pos + 1)
		end
	end

	pos = strfind(item, " ")
	if pos then
		local levelTemp = strsub(item, pos + 1)
		if tonumber(levelTemp) ~= nil then
			level = tonumber(levelTemp)
			item = strsub(item, 1, pos - 1)
		end
	end

	return item, num, level
end

function behaviorLib.DetermineBuyState(botBrain)
	--This is for determining where in our buy pattern we are.  We need this for when we dynamically reload the script.
	local inventory = core.unitSelf:GetInventory(true)
	local lists = {behaviorLib.LateItems, behaviorLib.MidItems, behaviorLib.LaneItems, behaviorLib.StartingItems}

	--BotEcho('Checkin buy state')
	for i, listItemStringTable in ipairs(lists) do
		for j = #listItemStringTable, 1, -1 do
			local listItemName = listItemStringTable[j]

			local name, num, level = behaviorLib.ProcessItemCode(listItemName)
			local tableItems = core.InventoryContains(inventory, name, true, true)
			local numValid = #tableItems

			if behaviorLib.printShopDebug then BotEcho("DetermineBuyState - Checking for "..num.."x "..name.." lvl "..level.." in Inventory") end

			if tableItems then
				for arrayPos, curItem in ipairs(tableItems) do
					--BotEcho("DetermineBuyState - level of "..name.."... lvl "..curItem:GetLevel())
					if curItem:GetLevel() < level or curItem:IsRecipe() then
						tremove(tableItems, arrayPos)
						numValid = numValid - 1
					end
				end
			end

			--if we have this, set the currentItem list to everything "past" this
			if numValid >= num then
				if j ~= #listItemStringTable then
					if i == 1 then
						behaviorLib.curItemList = core.CopyTable(behaviorLib.LateItems)
						behaviorLib.buyState = behaviorLib.BuyStateLateItems
					elseif i == 2 then
						behaviorLib.curItemList = core.CopyTable(behaviorLib.MidItems)
						behaviorLib.buyState = behaviorLib.BuyStateMidItems
					elseif i == 3 then
						behaviorLib.curItemList = core.CopyTable(behaviorLib.LaneItems)
						behaviorLib.buyState = behaviorLib.BuyStateLaneItems
					else
						behaviorLib.curItemList = core.CopyTable(behaviorLib.StartingItems)
						behaviorLib.buyState = behaviorLib.BuyStateStartingItems
					end

					--remove the items we already have

					numToRemove = j - 1
					for k = 0, numToRemove, 1 do
						tremove(behaviorLib.curItemList, 1)
					end
				else
					-- special case for last item in list
					if i == 1 or i == 2 then
						behaviorLib.curItemList = core.CopyTable(behaviorLib.LateItems)
						behaviorLib.buyState = behaviorLib.BuyStateLateItems
					elseif i == 3 then
						behaviorLib.curItemList = core.CopyTable(behaviorLib.MidItems)
						behaviorLib.buyState = behaviorLib.BuyStateMidItems
					elseif i == 4 then
						behaviorLib.curItemList = core.CopyTable(behaviorLib.LaneItems)
						behaviorLib.buyState = behaviorLib.BuyStateLaneItems
					end
				end

                --an item was found, we are all done here
				if behaviorLib.printShopDebug then
					BotEcho("   DetermineBuyState - Found Item!")
				end

                return
			end
		end
	end

	--we have found no items, start at the beginning
	behaviorLib.curItemList = core.CopyTable(behaviorLib.StartingItems)
	behaviorLib.buyState = behaviorLib.BuyStateStartingItems

	if behaviorLib.printShopDebug then
		BotEcho("   DetermineBuyState - No item found! Starting at the beginning of the buy list")
	end
end

function behaviorLib.ShuffleCombine(botBrain, nextItemDef, unit)
	local inventory = unit:GetInventory(true)

	if behaviorLib.printShopDebug then
		BotEcho("ShuffleCombine for "..nextItemDef:GetName())
	end

	--locate all my components
	local componentDefs = nextItemDef:GetComponents()
	local numComponents = #componentDefs
	--printGetNameTable(componentDefs)
	local slotsToMove = {}
	if componentDefs and #componentDefs > 1 then
		for slot = 1, 12, 1 do
			local curItem = inventory[slot]
			if curItem then
				--if curItem IS the same type, check if it is our recipe and not another (completed) instance
				local bRecipeCheck = curItem:GetTypeID() ~= nextItemDef:GetTypeID() or curItem:IsRecipe()

				if behaviorLib.printShopDebug then
					BotEcho("  Checking if "..tostring(slot)..", "..curItem:GetName().." is a component")
					BotEcho("    NextItem Type check: "..tostring(curItem:GetTypeID()).." ~= "..tostring(nextItemDef:GetTypeID()).." is "..tostring(curItem:GetTypeID() ~= nextItemDef:GetTypeID()))
					BotEcho("    IsRecipe chieck: "..tostring(curItem:IsRecipe()))
				end

				for compSlot, compDef in ipairs(componentDefs) do
					if compDef then
						if behaviorLib.printShopDebug then
							BotEcho("    Component Type check: "..tostring(curItem:GetTypeID()).." == "..tostring(compDef:GetTypeID()).." is "..tostring(curItem:GetTypeID() == compDef:GetTypeID()))
						end

						if curItem:GetTypeID() == compDef:GetTypeID() and bRecipeCheck then
							tinsert(slotsToMove, slot)
							tremove(componentDefs, compSlot) --remove this out so we don't mark wrong duplicates

							if behaviorLib.printShopDebug then
								BotEcho("    Component found!")
							end
							break
						end
					end
				end
			elseif behaviorLib.printShopDebug then
				BotEcho("  Checking if "..tostring(slot)..", EMPTY_SLOT is a component")
			end
		end

		if behaviorLib.printShopDebug then
			BotEcho("ShuffleCombine - numComponents "..numComponents.."  #slotsToMove "..#slotsToMove)
			BotEcho("slotsToMove:")
			core.printTable(slotsToMove)
		end

		if numComponents == #slotsToMove then
			if behaviorLib.printShopDebug then
				BotEcho("Finding Slots to swap into")
			end

			--swap all components into your stash to combine them, avoiding any components in your stash already
			local destSlot = 7
			for _, slot in ipairs(slotsToMove) do
				if slot < 7 then
					--Make sure we don't swap with another component
					local num = core.tableContains(slotsToMove, destSlot)
					while num > 0 do
						destSlot = destSlot + 1
						num = core.tableContains(slotsToMove, destSlot)
					end

					if behaviorLib.printShopDebug then
						BotEcho("Swapping: "..slot.." to "..destSlot)
					end

					unit:SwapItems(slot, destSlot)
					destSlot = destSlot + 1
				end
			end
		end
	end
end

behaviorLib.BootsList = {"Item_PostHaste", "Item_EnhancedMarchers", "Item_PlatedGreaves", "Item_Steamboots", "Item_Striders", "Item_Marchers"}
behaviorLib.MagicDefList = {"Item_Immunity", "Item_BarrierIdol", "Item_MagicArmor2", "Item_MysticVestments"}
behaviorLib.sPortalKeyName = "Item_PortalKey"

function behaviorLib.SortInventoryAndStash(botBrain)
	--[[
	C) Swap items to fill inventory
       1. Boots / +ms
	   2. Magic Armor
       3. Homecoming Stone
       4. PortalKey
       5. Most Expensive Item(s) (price decending)
	--]]
	local unitSelf = core.unitSelf
	local inventory = core.unitSelf:GetInventory(true)
	local inventoryBefore = inventory
	local slotsAvailable = {true, true, true, true, true, true} --represents slots 1-6 (backpack)
	local slotsLeft = 6
	local bFound = false

	--TODO: optimize via 1 iteration and storing item refs in tables for each category, then filling 1-6
	--  because this is hella bad and inefficent.

	--boots
	for slot = 1, 12, 1 do
		local curItem = inventory[slot]

		if behaviorLib.printShopDebug then
			local name = "EMPTY_SLOT"
			if curItem then
				name = curItem:GetName()
			end
			BotEcho("  Checking if "..tostring(slot)..", "..name.." is a boot")
		end

		if curItem and (slot > 6 or slotsAvailable[slot] ~= false) then
			for _, bootName in ipairs(behaviorLib.BootsList) do
				if curItem:GetName() == bootName then

					if behaviorLib.printShopDebug then
						BotEcho("    Boots found")
					end

					for i = 1, #slotsAvailable, 1 do
						if slotsAvailable[i] then
							if behaviorLib.printShopDebug then BotEcho("    Swapping "..inventory[slot]:GetName().." into slot "..i) end

							unitSelf:SwapItems(slot, i)
							slotsAvailable[i] = false
							slotsLeft = slotsLeft - 1
							inventory[slot], inventory[i] = inventory[i], inventory[slot]
							break
						end
					end
					bFound = true
				end

				if bFound then
					break
				end
			end
		end

		if bFound then
			break
		end
	end

	--magic armor
	bFound = false
	for slot = 1, 12, 1 do
		local curItem = inventory[slot]
		if slotsLeft < 1 then
			break
		end

		if behaviorLib.printShopDebug then
			local name = "EMPTY_SLOT"
			if curItem then
				name = curItem:GetName()
			end
			BotEcho("  Checking if "..tostring(slot)..", "..name.." has magic defense")
		end

		if curItem and (slot > 4 or slotsAvailable[slot] ~= false) then
			for _, magicArmorItemName in ipairs(behaviorLib.MagicDefList) do
				if curItem:GetName() == magicArmorItemName then
					for i = 1, #slotsAvailable, 1 do
						if slotsAvailable[i] then
							unitSelf:SwapItems(slot, i)
							slotsAvailable[i] = false
							slotsLeft = slotsLeft - 1
							inventory[slot], inventory[i] = inventory[i], inventory[slot]
							break
						end
					end
					bFound = true
				end

				if bFound then
					break
				end
			end
		end

		if bFound then
			break
		end
	end

	--homecoming stone
	bFound = false
	local tpName = core.idefHomecomingStone:GetName()
	for slot = 1, 12, 1 do
		local curItem = inventory[slot]
		if slotsLeft < 1 then
			break
		end

		if behaviorLib.printShopDebug then
			local name = "EMPTY_SLOT"
			if curItem then
				name = curItem:GetName()
			end
			BotEcho("  Checking if "..tostring(slot)..", "..name.." is a homecoming stone")
		end

		if curItem and (slot > 6 or slotsAvailable[slot] ~= false) then
			if curItem:GetName() == tpName then
				for i = 1, #slotsAvailable, 1 do
					if slotsAvailable[i] then
						unitSelf:SwapItems(slot, i)
						slotsAvailable[i] = false
						slotsLeft = slotsLeft - 1
						inventory[slot], inventory[i] = inventory[i], inventory[slot]
						break
					end
				end
				bFound = true
			end
		end

		if bFound then
			break
		end
	end

	--portal key
	bFound = false
	local sPortalKeyName = behaviorLib.sPortalKeyName
	for slot = 1, 12, 1 do
		local curItem = inventory[slot]
		if slotsLeft < 1 then
			break
		end

		if behaviorLib.printShopDebug then
			local name = "EMPTY_SLOT"
			if curItem then
				name = curItem:GetName()
			end
			BotEcho("  Checking if "..tostring(slot)..", "..name.." is a homecoming stone")
		end

		if curItem and (slot > 6 or slotsAvailable[slot] ~= false) then
			if curItem:GetName() == sPortalKeyName then
				for i = 1, #slotsAvailable, 1 do
					if slotsAvailable[i] then
						unitSelf:SwapItems(slot, i)
						slotsAvailable[i] = false
						slotsLeft = slotsLeft - 1
						inventory[slot], inventory[i] = inventory[i], inventory[slot]
						break
					end
				end
				bFound = true
			end
		end

		if bFound then
			break
		end
	end

	if botBrain.printShopDebug then
		BotEcho("Inv:")
		printInventory(inventory)
	end

	--finally, most expensive
	while slotsLeft > 0 do
		--selection sort
		local highestValue = 0
		local highestSlot = -1
		for slot = 1, 12, 1 do
			local curItem = inventory[slot]
			if curItem and (slot > 6 or slotsAvailable[slot] ~= false) then
				local cost = 0
				if not curItem:IsRecipe() then
					cost = curItem:GetTotalCost()
				end

				if cost > highestValue then
					highestValue = cost
					highestSlot = slot
				end
			end
		end

		if highestSlot ~= -1 then

			if botBrain.printShopDebug then
				BotEcho("Highest Cost: "..highestValue.."  slots available:")
				core.printTable(slotsAvailable)
			end

			for i = 1, #slotsAvailable, 1 do
				if slotsAvailable[i] then
					if behaviorLib.printShopDebug then BotEcho("  Swapping "..inventory[highestSlot]:GetName().." into slot "..i) end

					unitSelf:SwapItems(highestSlot, i)
					slotsAvailable[i] = false
					inventory[highestSlot], inventory[i] = inventory[i], inventory[highestSlot]
					slotsLeft = slotsLeft - 1
					break
				end
			end
		else
			--out of items
			break
		end
	end

	--compare backpack before and after to check for changes
	local bChanged = false
	for slot = 1, 6, 1 do
		if inventory[slot] ~= inventoryBefore[slot] then
			bChanged = true
			break
		end
	end


	return bChanged
end

function behaviorLib.SellLowestItems(botBrain, numToSell)
	if numToSell > 12 then --sanity checking
		return
	end

	local inventory = core.unitSelf:GetInventory(true)
	local lowestValue
	local lowestSlot

	while numToSell > 0 do
		lowestValue = 99999
		for slot = 1, 12, 1 do
			local curItem = inventory[slot]
			if curItem then
				local cost = curItem:GetTotalCost()

				if cost < lowestValue then
					lowestValue = cost
					lowestItem = curItem
				end
			end
		end

		if lowestItem then
			BotEcho("Selling "..lowestItem:GetName().." in slot "..lowestItem:GetSlot())
			core.unitSelf:Sell(lowestItem)
			inventory[lowestItem:GetSlot()] = ""
			numToSell = numToSell - 1
		else
			--out of items
			return
		end
	end
end

function behaviorLib.NumberSlotsOpen(inventory)
	local numOpen = 0
	--BotEcho("#inventory "..#inventory)
	for slot = 1, 12, 1 do
		curItem = inventory[slot]
		--BotEcho("NumberSlotsOpen - Checking Slot "..slot)
		if curItem == nil then
			--BotEcho("  slot is open")
			numOpen = numOpen + 1
		end
	end
	return numOpen
end

function behaviorLib.DetermineNextItemDef(botBrain)
	local inventory = core.unitSelf:GetInventory(true)
	
	--check if our last suggested buy was purchased
	local name, num, level = behaviorLib.ProcessItemCode(behaviorLib.curItemList[1])

	--BotEcho('Checkin item list for "'..name..'"')
	local tableItems = core.InventoryContains(inventory, name, true, true)

	if behaviorLib.printShopDebug then
		BotEcho("DetermineNextItemDef - behaviorLib.curItemList")
		core.printTable(behaviorLib.curItemList)
		BotEcho("DetermineNextItemDef - Checking for "..num.."x "..name.." lvl "..level.." in Inventory")
	end

	local idefCurrent = HoN.GetItemDefinition(name)
	local bStackable = idefCurrent:GetRechargeable() --"rechargeable" items are items that stack

	local numValid = 0
	if not bStackable then
		if tableItems then
			numValid = #tableItems
			for arrayPos, curItem in ipairs(tableItems) do
				if curItem:GetLevel() < level or curItem:IsRecipe() then
					tremove(tableItems, arrayPos)
					numValid = numValid - 1
					if behaviorLib.printShopDebug then BotEcho('One of the '..name..' is not valid level or is a recipe...') end
				end
			end
		end
	else
		num = num * idefCurrent:GetInitialCharges()
		for arrayPos, curItem in ipairs(tableItems) do
			numValid = numValid + curItem:GetCharges()
		end
	end

	--if we have this, remove it from our active list
	if numValid >= num then
		if behaviorLib.printShopDebug then BotEcho('Found it! Removing it from the list') end
		if #behaviorLib.curItemList > 1 then
			tremove(behaviorLib.curItemList, 1)
		else
			if behaviorLib.printShopDebug then BotEcho('End of this list, switching lists') end
			-- special case for last item in list
			if behaviorLib.buyState == behaviorLib.BuyStateStartingItems then
				behaviorLib.curItemList = core.CopyTable(behaviorLib.LaneItems)
				behaviorLib.buyState = behaviorLib.BuyStateLaneItems
			elseif behaviorLib.buyState == behaviorLib.BuyStateLaneItems then
				behaviorLib.curItemList = core.CopyTable(behaviorLib.MidItems)
				behaviorLib.buyState = behaviorLib.BuyStateMidItems
			elseif behaviorLib.buyState == behaviorLib.BuyStateMidItems then
				behaviorLib.curItemList = core.CopyTable(behaviorLib.LateItems)
				behaviorLib.buyState = behaviorLib.BuyStateLateItems
			else
				--keep repeating our last item
			end
		end
	end

	if behaviorLib.printShopDebug then
		BotEcho("DetermineNextItemDef - behaviorLib.curItemList")
		core.printTable(behaviorLib.curItemList)
	end

	local itemName = behaviorLib.ProcessItemCode(behaviorLib.curItemList[1])
	local retItemDef = HoN.GetItemDefinition(itemName)

	if behaviorLib.printShopDebug then
		if behaviorLib.curItemList[1] then
			BotEcho("DetermineNextItemDef - itemName: "..itemName)
		else
			BotEcho("DetermineNextItemDef - No item in list! Check your code!")
		end
	end

	return retItemDef
end

-------- Behavior Fns --------
function behaviorLib.ShopUtility(botBrain)
	--BotEcho('CanAccessStash: '..tostring(core.unitSelf:CanAccessStash()))
	local bCanAccessShop = core.unitSelf:CanAccessStash()

	--just got into shop access, try buying
	if bCanAccessShop and not behaviorLib.canAccessShopLast then
		--BotEcho("Open for shopping!")
		behaviorLib.finishedBuying = false
	end

	behaviorLib.canAccessShopLast = bCanAccessShop

	local utility = 0
	if bCanAccessShop and not behaviorLib.finishedBuying then
		if not core.teamBotBrain.bPurchasedThisFrame then
			utility = 99
		end
	end

	if botBrain.bDebugUtility == true and utility ~= 0 then
		BotEcho(format("  ShopUtility: %g", utility))
	end

	return utility
end


function behaviorLib.ShopExecute(botBrain)
--[[
Current algorithm:
    A) Buy items from the list
    B) Swap items to complete recipes
    C) Swap items to fill inventory, prioritizing...
       1. Boots / +ms
       2. Magic Armor
       3. Homecoming Stone
       4. Most Expensive Item(s) (price decending)
--]]
	if object.bUseShop == false then
		return
	end

	-- Space out your buys
	if behaviorLib.nextBuyTime > HoN.GetGameTime() then
		return
	end

	behaviorLib.nextBuyTime = HoN.GetGameTime() + behaviorLib.buyInterval

	--Determine where in the pattern we are (mostly for reloads)
	if behaviorLib.buyState == behaviorLib.BuyStateUnknown then
		behaviorLib.DetermineBuyState(botBrain)
	end
	
	local unitSelf = core.unitSelf
	local bChanged = false
	local bShuffled = false
	local bGoldReduced = false
	local tInventory = core.unitSelf:GetInventory(true)
	local nextItemDef = behaviorLib.DetermineNextItemDef(botBrain)

	--For our first frame of this execute
	if core.GetLastBehaviorName(botBrain) ~= core.GetCurrentBehaviorName(botBrain) then
		if nextItemDef:GetName() ~= core.idefHomecomingStone:GetName() then		
			--Seed a TP stone into the buy items after 1 min, Don't buy TP stones if we have Post Haste
			local sName = "Item_HomecomingStone"
			local nTime = HoN.GetMatchTime()
			local tItemPostHaste = core.InventoryContains(tInventory, "Item_PostHaste", true)
			if nTime > core.MinToMS(1) and #tItemPostHaste then
				tinsert(behaviorLib.curItemList, 1, sName)
			end
			
			nextItemDef = behaviorLib.DetermineNextItemDef(botBrain)
		end
	end
	
	if behaviorLib.printShopDebug then
		BotEcho("============ BuyItems ============")
		if nextItemDef then
			BotEcho("BuyItems - nextItemDef: "..nextItemDef:GetName())
		else
			BotEcho("ERROR: BuyItems - Invalid ItemDefinition returned from DetermineNextItemDef")
		end
	end

	if nextItemDef then
		core.teamBotBrain.bPurchasedThisFrame = true
		
		--open up slots if we don't have enough room in the stash + inventory
		local componentDefs = unitSelf:GetItemComponentsRemaining(nextItemDef)
		local slotsOpen = behaviorLib.NumberSlotsOpen(tInventory)

		if behaviorLib.printShopDebug then
			BotEcho("Component defs for "..nextItemDef:GetName()..":")
			core.printGetNameTable(componentDefs)
			BotEcho("Checking if we need to sell items...")
			BotEcho("  #components: "..#componentDefs.."  slotsOpen: "..slotsOpen)
		end

		if #componentDefs > slotsOpen + 1 then --1 for provisional slot
			behaviorLib.SellLowestItems(botBrain, #componentDefs - slotsOpen - 1)
		elseif #componentDefs == 0 then
			behaviorLib.ShuffleCombine(botBrain, nextItemDef, unitSelf)
		end

		local nGoldAmtBefore = botBrain:GetGold()
		unitSelf:PurchaseRemaining(nextItemDef)

		local nGoldAmtAfter = botBrain:GetGold()
		bGoldReduced = (nGoldAmtAfter < nGoldAmtBefore)
		bChanged = bChanged or bGoldReduced

		--Check to see if this purchased item has uncombined parts
		componentDefs = unitSelf:GetItemComponentsRemaining(nextItemDef)
		if #componentDefs == 0 then
			behaviorLib.ShuffleCombine(botBrain, nextItemDef, unitSelf)
		end
	end

	bShuffled = behaviorLib.SortInventoryAndStash(botBrain)
	bChanged = bChanged or bShuffled

	if not bChanged then
		if behaviorLib.printShopDebug then
			BotEcho("Finished Buying!")
		end
		
		behaviorLib.finishedBuying = true
	end
end


behaviorLib.ShopBehavior = {}
behaviorLib.ShopBehavior["Utility"] = behaviorLib.ShopUtility
behaviorLib.ShopBehavior["Execute"] = behaviorLib.ShopExecute
behaviorLib.ShopBehavior["Name"] = "Shop"
tinsert(behaviorLib.tBehaviors, behaviorLib.ShopBehavior)
