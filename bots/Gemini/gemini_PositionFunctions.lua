--inspired by St0len_ID
local tHeroPositions = {}
object.nPositionRemindTime = 10000
object.vecUnknown = Vector3.Create()
local function CreateHeroPositionTable(unitThis)
	local bDebugEchoes = true
	
	local nUniqueID = unitThis:GetUniqueID()
	
	if not tHeroPositions[nUniqueID] then
	
		tHeroPositions[nUniqueID] = {
			unit = unitThis
			bIsValid = false,
			vecCurrentPosition = object.vecUnknown,
			vecRelativeMovement = object.vecUnknown,
			nTimestamp = 0
		}
		
		if bDebugEchoes then
			BotEcho("Creating hero position table for  "..unitThis:GetDisplayName())
		end
	end

end

local function funcInitializeHeroPositions ()
	local bDebugEchoes = false
	
	if core.IsTableEmpty(tHeroPositions) then	
		local tEnemyTeam = HoN.GetHeroes(core.enemyTeam)
		
		for x, hero in pairs(tEnemyTeam) do
			CreateHeroPositionTable(hero)
		end
	end
end

local function funcGetUnitPosition (unit)
	local bDebugEchoes = false
	
	if not unit then return end
	
	local nUniqueID = unit:GetUniqueID()
	local tUnitData = tHeroPositions[nUniqueID]
	
	if debugEchoes then BotEcho("Get position for unit "..unitThis:GetDisplayName())	end
	
	if tUnitData and tUnitData.bIsValid then
		if debugEchoes then BotEcho("Position"..tostring(tUnitData.vecCurrentPosition).." Timestamp: "..tostring(tUnitData.nTimestamp))	end
		
		return tUnitData.vecCurrentPosition
	end
	
end

local function funcGetUnitExpectedPosition (unit, nTime)
	local bDebugEchoes = false
	
	if not unit or not nTime then return end
	
	local nUniqueID = unit:GetUniqueID()
	local tUnitData = tHeroPositions[nUniqueID]
	
	if debugEchoes then BotEcho("Get expected position for unit "..unitThis:GetDisplayName())	end
	
	if tUnitData and tUnitData.bIsValid then
	
		local nTimeStamp = tUnitData.nTimestamp
		local nTimeFactor = (nTime - nTimestamp) / 50
		local vecResult = tUnitData.vecCurrentPosition + tUnitData.vecRelativeMovement * nTimeFactor
		
		if debugEchoes then BotEcho("Current position: "..tostring(tUnitData.vecCurrentPosition).." Expected position: "..tostring(vecResult).." Timestamp: "..tostring(nTime))	end
		
		return vecResult
	end
end

local function funcUpdatePositionData (nNow)
	local bDebugEchoes = true
	
	if not nNow or not tHeroPositions then return end
	
	if debugEchoes then BotEcho("Updating position data for all heroes") end
	
	for index, tUnitData in pairs(tHeroPositions) do
		local unitToUpdate = tUnitData.unit
		local vecPosition = unitToUpdate:GetPosition()
		
		if debugEchoes then BotEcho("..Updating hero: "..unitThis:GetDisplayName())	end
		
		if vecPosition then
			if tUnitData.bIsValid then
				local vecOldPosition = tUnitData.vecCurrentPosition
				local nTimeSpan = (nNow - tUnitData.nTimestamp) / 50
				tUnitData.vecCurrentPosition = vecPosition
				tUnitData.vecRelativeMovement = (vecPosition - vecOldPosition) / nTimeSpan
				tUnitData.nTimestamp = nNow
				if debugEchoes then 
					BotEcho("....Updating Data! Old position : "..tostring(vecOldPosition).." New position "..tostring(vecPosition))
					BotEcho("....New relative Movement "..tostring(tUnitData.vecRelativeMovement).." TimeSpan: "..tostring(nTimeSpan))
				end
			else
				tUnitData.vecCurrentPosition = vecPosition
				tUnitData.vecRelativeMovement = object.vecUnknown
				tUnitData.bIsValid = true
				tUnitData.nTimestamp = nNow
				if debugEchoes then BotEcho("....New Data avaible! New Position "..tostring(vecPosition)) end
			end
		else
			--check timestamp
			if tUnitData.nTimestamp + object.nPositionRemindTime < nNow then
				tUnitData.bIsValid = false
				if debugEchoes then BotEcho("....Too old data")	end
			else
				if debugEchoes then BotEcho("....No data")	end
			end
		end
	end
	
end


