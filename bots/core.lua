-- core v1.0


local _G = getfenv(0)
local object = _G.object

object.core = object.core or {}
local core, eventsLib, behaviorLib, metadata = object.core, object.eventsLib, object.behaviorLib, object.metadata

function core.BotLog(str)
	if object.logger.bWriteLog then
		Log(str or '')
	end
end

function core.VerboseLog(str)
	if object.logger.bVerboseLog then
		Log(str or '')
	end
end

function core.BotEcho(str)
	Echo(object.myName..': '..(str or ''))
	core.BotLog(object.myName..': '..(str or ''))
end

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, asin, min, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.asin, _G.math.min, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
	
local sqrtTwo = math.sqrt(2)
	


--Stored References
core.enemyTowers = {}
core.enemyRax = {}
core.enemyMainBaseStructure = nil
core.enemyWell = nil
core.enemyWellAttacker = nil
core.allyTowers = {}
core.allyRax = {}
core.allyMainBaseStructure = nil
core.allyWell = nil
core.shops = {}


--Misc Data
core.bTraverseForward = true
core.myTeam = 0
core.enemyTeam = 0

core.localCreepRange = 1200
core.localTreeRange = 1000
core.enemyNearRange = 500
core.moveVecMultiplier = 250

core.nOutOfPositionRangeSq = 2000*2000

core.idefBlightStones = nil
core.idefHealthPotion = nil
core.idefHomecomingStone = nil

core.nEASY_DIFFICULTY 	= 1
core.nMEDIUM_DIFFICULTY = 2
core.nHARD_DIFFICULTY 	= 3

core.bMyTeamHasHuman = nil
core.bEnemyTeamHasHuman = nil

core.nDifficulty = core.nEASY_DIFFICULTY

core.coreInitialized = false


function core.CoreInitialize(controller)
	BotEcho('CoreInitializing')
	
	local bDebugEchos = false
	
	core.myTeam = controller:GetTeam()
	if core.myTeam == HoN.GetLegionTeam() then
		core.enemyTeam = HoN.GetHellbourneTeam()
		core.bTraverseForward = true
	else
		core.enemyTeam = HoN.GetLegionTeam()
		core.bTraverseForward = false
	end
	
	--Get ItemDefinitions for some items
	local idefBlights = HoN.GetItemDefinition("Item_RunesOfTheBlight")
	core.idefBlightStones = core.WrapInTable(idefBlights)
	core.idefBlightStones.duration = 16000
	core.idefBlightStones.expireTime = 0
	core.idefBlightStones.stateName = "State_RunesOfTheBlight"	
	
	local idefHealthPots = HoN.GetItemDefinition("Item_HealthPotion")
	core.idefHealthPotion = core.WrapInTable(idefHealthPots)
	core.idefHealthPotion.duration = 10000
	core.idefHealthPotion.expireTime = 0
	core.idefHealthPotion.stateName = "State_HealthPotion"
	
	local idefTPStones = HoN.GetItemDefinition("Item_HomecomingStone")
	core.idefHomecomingStone = core.WrapInTable(idefTPStones)
	core.idefHomecomingStone.channelTime = 3000
	
	--get useful buildings
	local units = HoN.GetUnitsInRadius(Vector3.Create(), 99999, core.UNIT_MASK_ALIVE + core.UNIT_MASK_BUILDING)
	
	if bDebugEchos then BotEcho("building units:"..core.NumberElements(units)) end
	
	--BotEcho("Gathering and sorting buildings")	
	local sortedBuildings = {}
	core.SortBuildings(units, sortedBuildings)
	
	core.enemyTowers			= sortedBuildings.enemyTowers
	core.enemyRax				= sortedBuildings.enemyRax
	core.enemyMainBaseStructure	= sortedBuildings.enemyMainBaseStructure
	core.enemyWell				= sortedBuildings.enemyWell
	core.enemyWellAttacker		= sortedBuildings.enemyWellAttacker
	core.allyTowers				= sortedBuildings.allyTowers
	core.allyRax				= sortedBuildings.allyRax
	core.allyMainBaseStructure	= sortedBuildings.allyMainBaseStructure
	core.allyWell				= sortedBuildings.allyWell	
	core.shops					= sortedBuildings.shops
	
	
	if bDebugEchos then
		if true then
			BotEcho("enemyTowers:") core.printGetTypeNameTable(core.enemyTowers)
			BotEcho("enemyRax:") core.printGetTypeNameTable(core.enemyRax)
			BotEcho("enemyMainBaseStructure: "..tostring(core.enemyMainBaseStructure))
			BotEcho("enemyWell: "..tostring(core.enemyWell))
			BotEcho("enemyWellAttacker: "..tostring(core.enemyWellAttacker))
			BotEcho("allyTowers:") core.printGetTypeNameTable(core.allyTowers)
			BotEcho("allyRax:") core.printGetTypeNameTable(core.allyRax)
			BotEcho("allyMainBaseStructure: "..tostring(core.allyMainBaseStructure))
			BotEcho("allyWell: "..tostring(core.allyWell))
			BotEcho("shops:") core.printGetTypeNameTable(core.shops)
		elseif tSorted then
			core.printTableTable(tSorted)
		end
	end
	
	core.coreInitialized = true
end


------------------ Math and Print functions ------------------

-- the following several functions take in various points and variables to create a mathematical function F(x),
--   and then return the value of F at x.  This is very useful for creating and easily tweaking utility funcitons.
function core.CubicRootFn(x, vMax, vMin, bDebug)
	bDebug = bDebug or false
	-- y = h*( (x - originX)/w ) + originY
	local h = (vMax.y - vMin.y)/2
	local w = (vMax.x - vMin.x)/2
	local originY = (vMax.y + vMin.y)/2
	local originX = (vMax.x + vMin.x)/2
	
	if bDebug then
		Echo( format("CubicRootFn(%g, v(%g, %g), v(%g, %g))", x, vMax.x, vMax.y, vMin.x, vMin.y) )
		Echo( format( "%g*( ((x - %g)/%g)^(1/3)) + %g)", h, originX, w, originY) )
	end
	
	local val = 0
	local base = (x - originX)/w
	if base < 0 then
		local absBase = abs((x - originX)/w)
		val = -1*h*( (absBase)^(1/3) ) + originY
	elseif base > 0 then
		val = h*( ((x - originX)/w)^(1/3)) + originY
	end
	
	return val
end

function core.ExponentialFn(x, vPositivePoint, vOrigin, order, bDebug)
	bDebug = bDebug or false
	
	local w = (vPositivePoint.x - vOrigin.x)
	local h = (vPositivePoint.y - vOrigin.y)
	
	local val = h * ((x-vOrigin.x)/w) ^ order + vOrigin.y
	
	if bDebug then
		Echo( format("ExponentialFn(%g, v(%g, %g), v(%g, %g), %g)", 
		  x, vPositivePoint.x, vPositivePoint.y, vOrigin.x, vOrigin.y, order) )	
				
		Echo( format( "%g*( ((x - %g)/%g)^(%g) ) + %g", 
		  h, vOrigin.x, w, order, vOrigin.y) )
	end	
	
	return val
end

function core.UnbalancedSRootFn(x, vMaxIn, vMinIn, vOrigin, order, bDebug)
	-- an S shaped (think cubic) function with differeing curves on the left and right
	bDebug = bDebug or false
	
	if not vOrigin then
		return core.CubicRootFn(x, vMaxIn, vMinIn, bDebug)
	end
	
	if bDebug then
		Echo( format("UnbalancedSRootFn(%g, v(%g, %g), v(%g, %g), v(%g, %g), %d)", 
			x, vMaxIn.x, vMaxIn.y, vMinIn.x, vMinIn.y, vOrigin.x, vOrigin.y, order) )
		
		if true then
			local vMax = vMaxIn
			local vMin = vMinIn
			vMin = vOrigin + (vOrigin - vMax)
			
			local h = (vMax.y - vMin.y)/2
			local w = (vMax.x - vMin.x)/2
			local originY = vOrigin.y
			local originX = vOrigin.x			
				
			Echo( format( "x right of origin: %g*( ((x - %g)/%g)^(1/%g) ) + %g", h, originX, w, order, originY) )
		end
		if true then
			local vMax = vMaxIn
			local vMin = vMinIn
			vMax = vOrigin + (vOrigin - vMin)
			
			local h = (vMax.y - vMin.y)/2
			local w = (vMax.x - vMin.x)/2
			local originY = vOrigin.y
			local originX = vOrigin.x			
				
			Echo( format( "x left of origin: %g*( ((x - %g)/%g)^(1/%g) ) + %g", h, originX, w, order, originY) )
		end
	end	
	
	local vMax = vMaxIn
	local vMin = vMinIn
	if x > vOrigin.x then
		vMin = vOrigin + (vOrigin - vMax)
	else
		vMax = vOrigin + (vOrigin - vMin)
	end
	
	-- y = h*( ((x - originX)/w )^(1/order) ) + originY
	local h = (vMax.y - vMin.y)/2
	local w = (vMax.x - vMin.x)/2
	local originY = vOrigin.y
	local originX = vOrigin.x
	
	local val = 0
	local base = (x - originX)/w
	if base < 0 then
		local absBase = abs((x - originX)/w)
		val = -1*h*( (absBase)^(1/order) ) + originY
	elseif base > 0 then
		val = h*( ((x - originX)/w)^(1/order) ) + originY
	end
	
	return val
end

function core.ExpDecay(x, yIntercept, xIntercept, order, bDebug)
	bDebug = bDebug or false

	local y = -1*( ((yIntercept)^(order)/xIntercept) * x ) ^ (1/order) + yIntercept
	
	if bDebug then
		Echo(format("ExpDecay(%g, %g, %g, %g)", x, yIntercept, xIntercept, order))
		Echo(format("  -1*( ((%g)^(%g)/%g) * %g ) ^ (1/%g) + %g", yIntercept, order, xIntercept, x, order, yIntercept))
	end
	
	return y
end

function core.ParabolicDecayFn(x, maxVal, zero, bDebug)
	local y = -1 * maxVal * (x/zero)^2 + maxVal
	
	if bDebug then
		Echo(format("ParabolicDecayFn(%g, %g, %g)", x, maxVal, zero))
		Echo(format("  -1 * %g * (x/%g)^2 + %g", maxVal, zero, maxVal))
	end
	
	return y
end

function core.ATanFn(x, vPoint, vOrigin, nLimit, bDebug)
	--Arctangent functions have a vertical asymptote of 0 and a horizontal asymptote of pi/2 and 
	--	increase in a convex slope between.  This function computes an ATan function based on your
	--	parameters and gives you the y value of the functions
	--
	--	vPoint is a static point on the line.
	--	vOrigin is the origin of the function.
	--	nLimit is the asymptote of the ATan function
	--
	--  This function will take those two points and the limit and comupte an ATan function that fits it
	
	--To get the right shape, we set our threshold and adjust the origin until the shape looks right
	--	Adding true to the end of the ATanFn() call will output the resultant function so you can graph it
	local bDebug = bDebug or false
	-- y = h * atan(x/w)*(2/pi)
	-- (0,0) (w,h/2) (inf, h)
	
	local h = nLimit
	local w = (vPoint.x-vOrigin.x) / tan(pi/2 * (vPoint.y-vOrigin.y)/nLimit)

	local y = h * atan((x-vOrigin.x)/w)*(2/pi) + vOrigin.y
	
	if bDebug then
		Echo(format("ATanFn(%g, (%g,%g), (%g,%g), %g)", x, vPoint.x, vPoint.y, vOrigin.x, vOrigin.y, nLimit))
		Echo(format("  %g * atan((x-%g)/%g)*(2/pi) + %g", h, vOrigin.x, w, vOrigin.y))
	end
	
	return y
end

----------------
function core.RandomReal(nMin, nMax)
	nMin = nMin or 0
	nMax = nMax or 1
	return random() * (nMax - nMin) + nMin
end

function core.RotateVec2DRad(vector, radians)
	local x = vector.x * cos(radians) - vector.y * sin(radians)
	local y = vector.x * sin(radians) + vector.y * cos(radians)
	
	return Vector3.Create(x, y)
end

function core.RotateVec2D(vector, degrees)
	local radians = (degrees * pi) / 180
	return core.RotateVec2DRad(vector, radians)
end

function core.AngleBetween(vec1, vec2)
	local radians = acos(Vector3.Dot(Vector3.Normalize(vec1), Vector3.Normalize(vec2)))
	return radians
end

function core.HeadingDifference(unit, vecTargetPos)
	return core.AngleBetween(unit:GetHeading(), vecTargetPos-unit:GetPosition())
end

function core.Clamp(val, low, high)
	local retVal = val
	if low <= high then
		if low ~= nil and retVal < low then
			retVal = low
		end	
		
		if high ~= nil and retVal > high then
			retVal = high
		end
	end
	
	return retVal
end

function core.DrawDebugLine(vStart, vEnd, color)
	HoN.DrawDebugLine(vStart, vEnd, false, color)
end

function core.DrawDebugArrow(vStart, vEnd, color)
	HoN.DrawDebugLine(vStart, vEnd, true, color)
end

function core.DrawXPosition(position, color, nSize)
	if not position then return end
	
	color = color or "red"
	nSize = nSize or 100
	local vecTL = Vector3.Create(0.5, -0.5) * nSize
	local vecBL = Vector3.Create(0.5,  0.5) * nSize
	
	HoN.DrawDebugLine(position - 0.5 * vecTL, position + 0.5 * vecTL, false, color)
	HoN.DrawDebugLine(position - 0.5 * vecBL, position + 0.5 * vecBL, false, color)
end

function core.DrawPath(tNodes)
	local lastNode = nil
	if tNodes then
		for i, node in ipairs(tNodes) do
			--BotEcho('  node: '..tostring(node:GetPosition()))
			if lastNode then
				core.DrawDebugArrow(lastNode:GetPosition(), node:GetPosition(), 'cyan')
			end
			core.DrawXPosition(node:GetPosition(), 'blue')
			
			lastNode = node
		end
	end		
end

function core.RadToDeg(x)
	return x * 180 / pi
end

function core.DegToRad(x)
	return x * pi / 180
end

function core.MSToS(x)
	return x / 1000
end

function core.SToMS(x)
	return x * 1000
end

function core.MinToS(x)
	return x * 60
end

function core.MinToMS(x)
	return x * 60 * 1000
end

----------------
function core.printTable(t) 
	print('{\n')
	if t then    
		for i,v in pairs(t) do
			print(' '..tostring(i)..', '.. tostring(v)..'\n')
		end
	end
	print('}\n')
end

function core.printTableTable (tableTable) 
    if tableTable then
		print('{\n')
        for i,v in pairs(tableTable) do
			print(tostring(i)..':\n')
            core.printTable(v)
        end
		print('}\n')
    end
end

function core.printGetNameTable (printThatTable) 
	Echo("{")
	if printThatTable then
		for i,v in pairs(printThatTable) do
			print('  '..tostring(i)..', '..v:GetName()..'\n')
		end
	end
	Echo("}")
end

function core.printGetTypeNameTable (printThatTable) 
	print('{\n')
	if printThatTable then    
		for i,v in pairs(printThatTable) do
			print(' '..tostring(i)..', '..v:GetTypeName()..'\n')
		end
	end
	print('}\n')
end

function core.printInventory(inventory)
	for slot = 1, 12, 1 do
		local curItem = inventory[slot]
		if curItem then
			print(tostring(slot)..', '..curItem:GetName()..'\n')
		else
			print(tostring(slot)..', nil\n')	
		end
	end
end

function core.NumberElements(theTable)
	if not theTable then
		return 0
	end

	local count = 0
	for key, value in pairs(theTable) do
		count = count + 1
	end
	return count
end

function core.IsTableEmpty(t)
	if not t then
		return true
	end

	local bReturn = true
	for key, value in pairs(t) do
		bReturn = false
		break
	end
	
	return bReturn	
end

function core.CopyTable(t)
	local tReturn = {}
	for key, value in pairs(t) do
		tReturn[key] = value
	end
	return tReturn
end

function core.RemoveByValue(t, valueToRemove)
	if not t then
		return false
	end

	local bSuccess = false
	for i, value in ipairs(t) do
		if value == valueToRemove then
			tremove(t, i)
			bSuccess = true
		end
	end
	
	return bSuccess
end

function core.NumberTablesEmpty(...)
	local nEmptyTables = 0
	--Echo('core.NumberTablesEmpty start, args: '..arg.n)
	--Echo(tostring(arg))
	--core.printTable(arg)
	local args = {...}
	for i,t in ipairs(args) do
		--Echo('  core.NumberTablesEmpty itr!')
		if core.IsTableEmpty(t) then
			nEmptyTables = nEmptyTables + 1
		end
	end
	--Echo('  core.NumberTablesEmpty end')
	return nEmptyTables
end

function core.InsertToTable(tDestination, tAdd)
	for _, val in ipairs(tAdd) do
		tinsert(tDestination, val)
	end
end

------------------- General Functions --------------------
core.distSqTolerance = 100*100
core.towerBuffer = 150
core.nStandBuffer = 10

--This should mirror the LuaUnitMask enum in lua_honapi.cpp
core.UNIT_MASK_UNIT		= 0x0000001
core.UNIT_MASK_BUILDING	= 0x0000002
core.UNIT_MASK_HERO		= 0x0000004
core.UNIT_MASK_POWERUP	= 0x0000008
core.UNIT_MASK_GADGET	= 0x0000010
core.UNIT_MASK_ALIVE	= 0x0000020
core.UNIT_MASK_CORPSE	= 0x0000040

function core.WrapInTable(userData)		
	local oldMetatable = getmetatable(userData)
	
	if userData == nil then
		BotEcho("core.WrapInTable - userData is nil")
		return nil
	elseif oldMetatable == nil then
		BotEcho("core.WrapInTable - userData's metatable is nil")
		return nil
	end
		
	--This is the object that holds our overloaded functions
	local new_class_obj = {} 
	--this is the metatable for our new table, which falls us back to the functions object when
	--  the new table can't find something (like class members)
	local newMetatable = { __index = new_class_obj } 
		
	--set the metatable of the class object to fall back to the original data
	setmetatable(new_class_obj, {__index = userData})
		
	--create duplicates of all functions in the original data's MT that call the original
	--  fns and pass the original data
	for key, fn in pairs(oldMetatable) do
		local function wrapperFn(t, ...)
			return fn(t.object, ...)
		end
			
		new_class_obj[key] = wrapperFn
	end
		
	local newTable = {}
	setmetatable(newTable, newMetatable)
	
	newTable.object = userData
	
	return newTable
end

function core.tableContains (tableToCheck, val) 
    local num = 0
	local tableSlots = {}
    if tableToCheck then
        for i,v in pairs(tableToCheck) do
            if v == val then
                num = num + 1
		tinsert(tableSlots, i)
            end
        end
    end
    return num, tableSlots
end

function core.AssessLocalUnits(botBrain, vecPosition, nRadius)
	StartProfile('Assess local units')
	
	StartProfile('Setup')
		local unitSelf = core.unitSelf
		vecPosition = vecPosition or unitSelf:GetPosition()
		nRadius = nRadius or core.localCreepRange
		local nMask = core.UNIT_MASK_ALIVE + core.UNIT_MASK_UNIT + core.UNIT_MASK_HERO + core.UNIT_MASK_BUILDING
	StopProfile()
	
	StartProfile('GetUnits')
		local tUnits = botBrain:GetLocalUnits()
		local tSortedUnits = botBrain:GetLocalUnitsSorted()
	StopProfile()
	
	-- BotEcho('local creep range '..core.localCreepRange)
	-- BotEcho('units in range '..core.localCreepRange..': '..core.NumberElements(tUnits))
	-- BotEcho('myTeam '..core.myTeam..'  enemyTeam'..core.enemyTeam)
	
	StartProfile('Loop')
		local teamBotBrain = core.teamBotBrain
		local tAllyHeroes = tSortedUnits.AllyHeroes
		local tAllyUnits = tSortedUnits.AllyUnits
		local tAllies = tSortedUnits.Allies
		for nUID,unitAlly in pairs(tAllyHeroes) do
			tAllyHeroes[nUID] = teamBotBrain:CreateMemoryUnit(unitAlly)
			tAllyUnits[nUID] = tAllyHeroes[nUID]
			tAllies[nUID] = tAllyHeroes[nUID]
		end
		local tEnemyHeroes = tSortedUnits.EnemyHeroes
		local tEnemyUnits = tSortedUnits.EnemyUnits
		local tEnemies = tSortedUnits.Enemies
		for nUID,unitEnemy in pairs(tEnemyHeroes) do
			tEnemyHeroes[nUID] = teamBotBrain:CreateMemoryUnit(unitEnemy)
			tEnemyUnits[nUID] = tEnemyHeroes[nUID]
			tEnemies[nUID] = tEnemyHeroes[nUID]
		end	
	StopProfile()
		
	StopProfile()
	return tSortedUnits
end

function core.GetExtraRange(unit)
	--for range checks, we check for the acutal range + the source unit's "width" + the target unit's "width".
	--  This is the "width" of the unit
	if unit then
		return unit:GetBoundsRadius() * sqrtTwo
	end
	
	return 0
end

function core.GetAbsoluteAttackRange(unit)
	--for range checks, we check for the acutal range + the source unit's "width" + the target unit's "width".
	if unit then
		return unit:GetAttackRange() + core.GetExtraRange(unit)
	end
	
	return 0
end

function core.GetAbsoluteAttackRangeToUnit(unit, unitTarget, bSquared)
	--for range checks, we check for the acutal range + the source unit's "width" + the target unit's "width".
	local nRange = 0
	if unit then
		local nUnitAttackRange = unit:GetAttackRange()
		if nUnitAttackRange ~= nil then
			nRange = nRange + nUnitAttackRange
		end
		nRange = nRange + core.GetExtraRange(unit)
	end
	if unitTarget and unitTarget:IsValid() then
		nRange = nRange + core.GetExtraRange(unitTarget)
	end
	
	if bSquared then
		nRange = nRange * nRange
	end
	
	return nRange
end

function core.IsUnitInRange(unitSelf, unitTarget, nRangeOverride)
	local nRange = nRangeOverride or core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
	
	if unitTarget and Vector3.Distance2DSq(unitSelf:GetPosition(), unitTarget:GetPosition()) < nRange * nRange then
		return true
	end
	
	return false
end

function core.GetFinalAttackDamageAverage(unit)
	--The final calculated damage (total of base, bonus, multipliers, etc)'s average
	return (unit:GetFinalAttackDamageMax() + unit:GetFinalAttackDamageMin()) * 0.5
end

function core.GetAttacksPerSecond(unit)
	if unit == nil then return 0 end

	local nAdjustedAttackCD = unit:GetAdjustedAttackCooldown()
	if nAdjustedAttackCD and nAdjustedAttackCD ~= 0 then
		nAdjustedAttackCD = nAdjustedAttackCD / 1000
	else
		nAdjustedAttackCD = 0
	end
	
	return 1/nAdjustedAttackCD
end

function core.GetClosestEnemyTower(vecPos, nMaxDist)
	nMaxDist = nMaxDist ~= nil and nMaxDist or 99999
	
	local nMaxDistanceSq = nMaxDist * nMaxDist
	
	local unitClosestTower = nil
	local nClosestTowerDistSq = 99999*99999
	for id, unitTower in pairs(core.enemyTowers) do
		if unitTower ~= nil then
			local nDistanceSq = Vector3.Distance2DSq(unitTower:GetPosition(), vecPos)
	 		if nDistanceSq < nClosestTowerDistSq and nDistanceSq < nMaxDistanceSq then
				nClosestTowerDistSq = nDistanceSq
				unitClosestTower = unitTower
			end
		end
	end
	
	return unitClosestTower
end

function core.GetClosestAllyTower(vecPos, nMaxDist)
	nMaxDist = nMaxDist ~= nil and nMaxDist or 99999
	
	local nMaxDistanceSq = nMaxDist * nMaxDist
	
	local unitClosestTower = nil
	local nClosestTowerDistSq = 99999*99999
	for id, unitTower in pairs(core.allyTowers) do
		if unitTower ~= nil then
			local nDistanceSq = Vector3.Distance2DSq(unitTower:GetPosition(), vecPos)
	 		if nDistanceSq < nClosestTowerDistSq and nDistanceSq < nMaxDistanceSq then
				nClosestTowerDistSq = nDistanceSq
				unitClosestTower = unitTower
			end
		end
	end
	
	return unitClosestTower
end

function core.AdjustMovementForTowerLogic(vecDesiredPos, bCanEnterRange)
	if bCanEnterRange == nil then
		bCanEnterRange = true
	end

	local bDebugEchos = false
	local bDebugLines = false
	local lineLen = 150

	--if object.myName == 'ShamanBot' then bDebugEchos = true bDebugLines = true end
	
	local nStandBuffer = core.nStandBuffer
	
	--don't stand in towers if your creeps are not closer to the tower than you, as you will be the next aggro target
	--  if you do
	local unitSelf = core.unitSelf
	local nMyID = unitSelf:GetUniqueID()
	local vecMyPos = unitSelf:GetPosition()
	
	local tAllies = core.localUnits["AllyUnits"]
	
	local bAdjusted = false
	local bWellDiving = false
	
	local vecNewDesiredPos = vecDesiredPos
	local vecCurDesiredPos = vecNewDesiredPos
	
	--Anti-Towerdive
	local unitWellAttacker = core.enemyWellAttacker 
	local nWellAttackerID = unitWellAttacker:GetUniqueID()

	local tTowers = core.CopyTable(core.localUnits["EnemyTowers"])
	tTowers[nWellAttackerID] = unitWellAttacker

	--[[
	local nMoveStep = 200
	--adjust target position to be a small enough jaunt to not accidentally intersect a tower's threatened area
	if Vector3.Distance2D(vecMyPos, vecDesiredPos) > nMoveStep then
		vecNewDesiredPos = vecMyPos + Vector3.Normalize(vecNewDesiredPos - vecMyPos) * nMoveStep
		vecCurDesiredPos = vecNewDesiredPos		
	end
	--]]

	for id, localTower in pairs(tTowers) do
		if localTower:IsAlive() then		
			local nTowerDistanceSq = Vector3.Distance2DSq(vecMyPos, localTower:GetPosition())		
			local nTowerBuffer = core.towerBuffer
			local nTowerRange = core.GetAbsoluteAttackRangeToUnit(localTower, core.unitSelf)
			local nTowerRangeSq = nTowerRange * nTowerRange
			local nTowerRadiusSq = (nTowerRange + nTowerBuffer) * (nTowerRange + nTowerBuffer)
			local vecTowerPosition = localTower:GetPosition()
			local nClosestAllyDistSq = 9999*9999
			local unitClosestAlly = nil
			
			local bIsWellAttacker = (localTower:GetUniqueID() == nWellAttackerID)
			
			local nDesiredDistanceSq = Vector3.Distance2DSq(vecNewDesiredPos, vecTowerPosition)
			
			if nDesiredDistanceSq < nTowerRadiusSq then	
				bAdjusted = true
			
				if bIsWellAttacker then
					bWellDiving = true
				end
			
				local nAlliesInRange = 0
				if bCanEnterRange then
					--check for ally creeps
					if bDebugEchos then BotEcho("Checkin for allies in tower range. #allies: "..core.NumberElements(tAllies)) end
					for id, unitAlly in pairs(tAllies) do
						if id ~= nMyID then
							local nCreepDistanceSq = Vector3.Distance2DSq(vecTowerPosition, unitAlly:GetPosition())
							if nCreepDistanceSq < nTowerRangeSq then
								nAlliesInRange = nAlliesInRange + 1
								if nCreepDistanceSq < nClosestAllyDistSq then
									nClosestAllyDistSq = nCreepDistanceSq
									unitClosestAlly = unitAlly
								end
								if bDebugLines then core.DrawXPosition(unitAlly:GetPosition(), 'teal') end
							end
						end
					end
				end
				
				if bDebugEchos then 
					BotEcho(format("AlliesInRange: %d  nClosestAllyDistSq: %d  canEnterRange: %s  wellDiving: %s  nDesiredDistanceSq: %s",
						nAlliesInRange, nClosestAllyDistSq, tostring(bCanEnterRange), tostring(bWellDiving), nDesiredDistanceSq)
					)
				end
					
				local vecToDesiredFromTower = Vector3.Normalize(vecNewDesiredPos - vecTowerPosition)
				if nAlliesInRange <= 0 or not bCanEnterRange or bWellDiving then
					--BotEcho("  NotDivin")
					--don't be in tower range
					if nTowerDistanceSq < nTowerRadiusSq then 
						--I am already in range, retreat!
						local vecTower = Vector3.Normalize(vecMyPos - vecTowerPosition)
						local vecNewDesired = Vector3.Normalize(vecTower + vecToDesiredFromTower)
						vecCurDesiredPos = vecTowerPosition + (vecNewDesired * (nTowerRange + core.towerBuffer))
					else
						--Stay outside
						vecCurDesiredPos = vecTowerPosition + vecToDesiredFromTower * (nTowerRange + nTowerBuffer)
					end
				elseif nClosestAllyDistSq > nDesiredDistanceSq then
					--move to be further away from ally creep(as tower takes closest target)
					local vecAllyDistance = Vector3.Distance2D(vecTowerPosition, unitClosestAlly:GetPosition())
					vecCurDesiredPos = vecTowerPosition + vecToDesiredFromTower * (vecAllyDistance + nStandBuffer)
				end	
				
				if bDebugLines then
					core.DrawDebugLine( vecTowerPosition, vecTowerPosition + vecToDesiredFromTower * lineLen, 'yellow')
				end

				vecNewDesiredPos = vecCurDesiredPos
				
				--TODO: predict ally creep death times and use that to know when to book it
			end

			--BotEcho('AdjustMovementForTowerLogic localTower: '..((localTower and localTower:GetTypeName()) or 'nil'))
			if bDebugLines and localTower ~= nil then
				local nTowerExtraRange = core.GetExtraRange(localTower)
				local nMyExtraRange = core.GetExtraRange(unitSelf)
				local vecTowards = Vector3.Normalize(vecMyPos - vecTowerPosition)
				local vecOrtho = Vector3.Create(-vecTowards.y, vecTowards.x) --quick 90 rotate z
				core.DrawDebugLine( (vecTowerPosition + vecTowards * nTowerRange) - (vecOrtho * 0.5 * lineLen),
										(vecTowerPosition + vecTowards * nTowerRange) + (vecOrtho * 0.5 * lineLen), 'orange')
										
				core.DrawDebugLine( vecTowerPosition + vecTowards * nTowerExtraRange, vecTowerPosition + vecTowards * nTowerRange, 'orange')
				
				core.DrawDebugLine( vecTowerPosition + vecTowards * nTowerRange, vecTowerPosition + vecTowards * (nTowerRange + core.towerBuffer), 'blue')
				core.DrawDebugLine( (vecTowerPosition + vecTowards * (nTowerRange + core.towerBuffer)) - (vecOrtho * 0.25 * lineLen),
										(vecTowerPosition + vecTowards * (nTowerRange + core.towerBuffer)) + (vecOrtho * 0.25 * lineLen), 'blue')
										
				core.DrawDebugLine( (vecMyPos - vecTowards * nMyExtraRange) - (vecOrtho * 0.5 * lineLen),
										(vecMyPos - vecTowards * nMyExtraRange) + (vecOrtho * 0.5 * lineLen), 'white')
				
				if unitClosestAlly then
					local vecAllyPosition = unitClosestAlly:GetPosition()
					local vecTowardsAlly = Vector3.Normalize(vecAllyPosition - vecTowerPosition)
					core.DrawDebugLine( (vecAllyPosition - vecTowardsAlly) - (vecOrtho * 0.5 * lineLen),
											(vecAllyPosition - vecTowardsAlly) + (vecOrtho * 0.5 * lineLen), 'teal')
				end				
										
				core.DrawXPosition(vecDesiredPos, 'blue', 150)
				core.DrawXPosition(vecNewDesiredPos, 'orange', 125)			
				core.DrawXPosition(vecTowerPosition, 'red')
			end --bDebugLines
		end --if localTower is alive
	end -- foreach local tower
	
	return vecNewDesiredPos, bAdjusted, bWellDiving
end

function core.GetFirstNode(tLanePath, bForward)	
	local nodeReturn = nil
	
	if tLanePath then
		if bForward then
			nodeReturn = tLanePath[1]
		else
			nodeReturn = tLanePath[#tLanePath]
		end
	end
	
	if nodeReturn == nil then	
		BotEcho('ERROR - Unable to find first lane node in path')
	end
	
	return nodeReturn
end

function core.GetLastNode(tLanePath, bForward)
	return core.GetFirstNode(tLanePath, not bForward)
end

function core.GetNextWaypoint(tPath, vecPos, bForward)	
	if bForward == nil then
		bForward = true
	end
	
	local nodeReturn = nil
	
	local node,nIndex = BotMetaData.GetClosestNodeOnPath(tPath, vecPos, bForward)
	
	if nIndex ~= nil then
		local nPathSize = #tPath
		
		if bForward and nIndex < nPathSize then
			nIndex = nIndex + 1
			nodeReturn = tPath[nIndex]
		elseif not bForward and nIndex > 1 then
			nIndex = nIndex - 1
			nodeReturn = tPath[nIndex]
		end
	end
	
	return nodeReturn,nIndex
end

function core.GetPrevWaypoint(tPath, vecPos, bForward)
	return core.GetNextWaypoint(tPath, vecPos, not bForward)
end

function core.GetFurthestLaneTower(tNodes, bTraverseForward, nTargetTeam)
	local bDebugEchos = false
	--[[
	if object.myName == "Bot1" then
		bDebugEchos = true
	end--]]
	
	if tNodes == nil or #tNodes < 1 then
		BotEcho('GetFurthestLaneTower - invalid path!')
		return nil
	end
	
	if bDebugEchos then BotEcho('GetFurthestLaneTower - bForward: '..tostring(bTraverseForward)) end
	
	--Traverse backward down the lane nodes and seach in a 2000 unit radius for the creeps from each node
	local wellNodePos = (core.allyWell and core.allyWell:GetPosition()) or nil
	if nTargetTeam ~= core.myTeam then --hacky
		wellNodePos = (core.enemyWell and core.enemyWell:GetPosition()) or nil
	end
	if bDebugEchos then BotEcho("WellNodePos: "..tostring(wellNodePos).."  allyWell: "..tostring(core.allyWell)) end
	
	local nSize = #tNodes
	
	local i = nSize
	if bTraverseForward == false then
		i = 1
	end
	
	local node = tNodes[i] --Get furthest node
	if wellNodePos then
		while node ~= nil do
			if bDebugEchos then BotEcho("  Checking node at "..tostring(node:GetPosition())) end
			
			local tBuildings = HoN.GetUnitsInRadius(node:GetPosition(), 2000, core.UNIT_MASK_ALIVE + core.UNIT_MASK_BUILDING)
			if core.NumberElements(tBuildings) > 0 then
				for _, tower in pairs(tBuildings) do
					if tower:GetTeam() == nTargetTeam then
						return tower
					end
				end
			end
			
			if bTraverseForward == true then
				i = i - 1
			else
				i = i + 1
			end			
			node = tNodes[i]
		end
	end
	
	BotEcho('GetFurthestLaneTower - unable to find tower!')
	return nil
end

function core.GetClosestLaneTower(tNodes, bTraverseForward, nTargetTeam)
	return core.GetFurthestLaneTower(tNodes, not bTraverseForward, nTargetTeam)
end

function core.GetFurthestCreepWavePos(tLane, bTraverseForward)
	local bDebugEchos = false
	local bDebugLines = false
	--[[
	if object.myName == "FlintBot" then
		bDebugLines = true
		bDebugEchos = true
	end
	--]]
	
	if tLane == nil or #tLane < 1 then
		BotEcho('GetFurthestCreepWavePos - invalid path!')
		return nil
	end
	
	if bDebugEchos then BotEcho('GetFurthestCreepWavePos - bForward: '..tostring(bTraverseForward)) end
	
	local tbotTeam = HoN.GetTeamBotBrain()
	if not tbotTeam then
		if bDebugEchos then BotEcho("GetTeamBotBrain() returned nil") end
		return nil
	end
		
	vecReturn = tbotTeam:GetFrontOfCreepWavePosition(tLane.sLaneName)
	
	if bDebugEchos then BotEcho("Front of "..tLane.sLaneName..":"..tostring(vecReturn)) end	
	if bDebugLines and vecReturn then
		core.DrawXPosition(vecReturn, 'red')
	end
	
	return vecReturn
end

function core.AssessLaneDirection(position, tPath, bTraverseForward)
	if bTraverseForward == nil then
		bTraverseForward = true
	end
	
	local bDebugEchos = false
	--[[
	if object.myName == "Bot3" then
		bDebugEchos = true
	end
	--]]
	
	--Determine "forward" and "right" for my lane
	if tPath == nil or #tPath < 1 then
		BotEcho('AssessLaneDirection - invalid path!')
		return nil
	end
	
	local vLaneForward = nil
	local vLaneForwardOrtho = nil	
	local nSize = #tPath
	
	local i = 1
	if not bTraverseForward then
		i = nSize
	end
	
	local node = tPath[i]
	local lastNode = nil
	
	if bTraverseForward == true then
		i = i + 1
	else
		i = i - 1
	end	
	
	if bDebugEchos then BotEcho('AssessLaneDirection nodes: '..nSize..'  i: '..i) end
	while node do
		if tPath[i] == nil then
			if bDebugEchos then BotEcho('end of the path, break') end
			break
		end
	
		lastNode = node
		node = tPath[i]
		if bDebugEchos then BotEcho('loop i: '..i..'  node: '..tostring(node:GetPosition())..'  lastNode: '..tostring(lastNode:GetPosition())) end
		
		local vecNodePos = node:GetPosition()
		local vecLastNodePos = lastNode:GetPosition()
		
		local curPathVec = vecNodePos - vecLastNodePos
		local curPosVec = position - vecNodePos		
		local dot = Vector3.Dot(curPathVec, curPosVec)		
		if dot <= 0 and Vector3.Distance2DSq(vecNodePos, position) > core.distSqTolerance then
			if bDebugEchos then BotEcho('We have passed our position') end
			break
		end
				
		if bTraverseForward == true then
			i = i + 1
		else
			i = i - 1
		end	
	end
	
	if lastNode ~= nil then		
		vLaneForward = node:GetPosition() - lastNode:GetPosition()
		vLaneForward.z = 0
		vLaneForward = Vector3.Normalize(vLaneForward)
		
		vLaneForwardOrtho = Vector3.Create(-vLaneForward.y, vLaneForward.x) --quick 90 rotate z
	end
	
	if bDebugEchos then BotEcho('returning vLaneForward: '..tostring(vLaneForward)..'  vLaneForwardOrtho: '..tostring(vLaneForwardOrtho)) end	
	return vLaneForward, vLaneForwardOrtho
end

function core.GetClosestTeleportBuilding(position)
	local closestDistSq = 99999999
	local closestBuilding = nil
	
	local tBuildings = core.GetTeleportBuildings()
	for key, building in pairs(tBuildings) do
		local distSQ = Vector3.Distance2DSq(position, building:GetPosition())
		if distSQ < closestDistSq then
			closestBuilding = building
			closestDistSq = distSQ
		end
	end
	
	return closestBuilding
end

function core.GetTeleportBuildings()	
	return core.teamBotBrain:GetTeleportBuildings()
end

function core.InventoryContains(inventory, val, bIgnoreRecipes, bIncludeStash)
	if bIgnoreRecipes == nil then
		bIgnoreRecipes = false
	end
	if bIncludeStash == nil then
		bIncludeStash = false
	end

	--searches for a particular item in the inventory, returning a table of the Items
	local tableOfThings = {}
    
	local nLast = (bIncludeStash and 12) or 6
	
	for slot = 1, nLast, 1 do
		local curItem = inventory[slot]
		if curItem and not curItem:IsRecipe() then
			--Echo(format("%d - Type:%s  Name:%s", slot, type(curItem), (curItem.GetName and curItem:GetName()) or "ERROR"))
			--if type(curItem) == "table" then
			--	printTable(curItem)
			--end
			
			if curItem:GetName() == val and (not bIgnoreRecipes or not curItem:IsRecipe()) then
				tinsert(tableOfThings, curItem)
			end
		end
	end
	
    return tableOfThings
end

core.tFoundItems = {}
core.tsearchTimes = {}
core.nSearchFrequency = 2000
--Finds an item on your hero.
function core.GetItem(val, bIncludeStash)
	if core.tFoundItems[val] then -- We have checked the item before. Validate it.
		core.ValidateItem(core.tFoundItems[val])
		if core.tFoundItems[val] and core.tFoundItems[val]:IsValid() then -- still valid, return it
			return core.tFoundItems[val]
		else
			core.tFoundItems[val] = nil
		end
	end
	--First time seeing the item, or it was invalidated.
	if not core.tFoundItems[val] then
		local nLastSearchTime = core.tsearchTimes[val] or 0
		if nLastSearchTime + core.nSearchFrequency <= HoN:GetGameTime() then -- Only look at every x seconds
			core.tsearchTimes[val] = HoN:GetGameTime()
			inventory = core.unitSelf:GetInventory()
			if bIncludeStash == nil then
				bIncludeStash = false
			end
			local nLast = (bIncludeStash and 12) or 6
			for slot = 1, nLast, 1 do
				local curItem = inventory[slot]
				if curItem then
					if curItem:GetTypeName() == val and not curItem:IsRecipe() then --ignore recipes!
						core.tFoundItems[val] = core.WrapInTable(curItem)
						return core.tFoundItems[val]
					end
				end
			end
		end
	end
	return nil
end

function core.IsLaneCreep(unit)
	return (strfind(unit:GetTypeName(), "Creep") ~= nil)
end

function core.IsCourier(unit)
	return unit:IsUnitType("Courier")
end

function core.EnemyTeamHasHuman()
	if core.bEnemyTeamHasHuman == nil then
		local tEnemyHeroes = HoN.GetHeroes(core.enemyTeam)
		for _, unitHero in pairs(tEnemyHeroes) do
			if not unitHero:IsBotControlled() then
				core.bEnemyTeamHasHuman = true
				break
			end
		end
	end

	return core.bEnemyTeamHasHuman
end

function core.MyTeamHasHuman()
	if core.bMyTeamHasHuman == nil then
		local tAllyHeroes = HoN.GetHeroes(core.myTeam)
		for _, unitHero in pairs(tAllyHeroes) do
			if not unitHero:IsBotControlled() then
				core.bMyTeamHasHuman = true
				break
			end
		end
	end

	return core.bMyTeamHasHuman
end

function core.IsTowerSafe(unitEnemyTower, unitSelf)
	--Is this tower safe to attack (as in it won't switch targets to me)
	local bSafe = false
	
	if unitEnemyTower then
		local unitAttackTarget = unitEnemyTower:GetAttackTarget()
		if unitAttackTarget ~= nil and unitAttackTarget:GetUniqueID() ~= core.unitSelf:GetUniqueID() then
			bSafe = true
		else
			local nRange = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitEnemyTower)
			local nTowerRange = core.GetAbsoluteAttackRangeToUnit(unitEnemyTower, unitSelf)
			local nTowerRangeSq = nTowerRange * nTowerRange
			local myDistanceSq = Vector3.Distance2DSq(unitEnemyTower:GetPosition(), unitSelf:GetPosition())
	
			if nRange > nTowerRange and myDistanceSq > nTowerRangeSq then
				--I outrange the tower
				bSafe = true
			end		
		end
	end
	
	return bSafe
end

function core.SortUnitsAndBuildings(tUnitList, tSortedUnits, bHeroesAsMemoryUnits)
	--TODO: consolidate this with the SortBuildings
	StartProfile('setup')
	tSortedUnits = tSortedUnits or {}
	
	tSortedUnits.enemyCreeps	= tSortedUnits.enemyCreeps or {}
	tSortedUnits.enemyHeroes	= tSortedUnits.enemyHeroes or {}
	tSortedUnits.tEnemyUnits	= tSortedUnits.tEnemyUnits or {}
	tSortedUnits.enemyBuildings	= tSortedUnits.enemyBuildings or {}
	tSortedUnits.enemyRax		= tSortedUnits.enemyRax or {}
	tSortedUnits.enemyTowers	= tSortedUnits.enemyTowers or {}
	tSortedUnits.enemies		= tSortedUnits.enemies or {}
	
	tSortedUnits.allyCreeps		= tSortedUnits.allyCreeps or {}
	tSortedUnits.allyHeroes		= tSortedUnits.allyHeroes or {}
	tSortedUnits.allyUnits		= tSortedUnits.allyUnits or {}
	tSortedUnits.allyBuildings	= tSortedUnits.allyBuildings or {}
	tSortedUnits.allyRax		= tSortedUnits.allyRax or {}
	tSortedUnits.allyTowers		= tSortedUnits.allyTowers or {}
	tSortedUnits.allies			= tSortedUnits.allies or {}
	
	local allyTeam = core.myTeam
	local enemyTeam = core.enemyTeam
	
	local teamBotBrain = core.teamBotBrain
	StopProfile()
	
	StartProfile('Loop')
	for key,curUnit in pairs(tUnitList) do
		if curUnit ~= core.unitSelf then  
			StartProfile('Inner part')
			local id = curUnit:GetUniqueID()
			if curUnit:GetTeam() == allyTeam then
				if curUnit:IsHero() and bHeroesAsMemoryUnits then
					curUnit = teamBotBrain:CreateMemoryUnit(curUnit)
				end
				
				tSortedUnits.allies[id] = curUnit
				
				if curUnit:IsBuilding() then
					tSortedUnits.allyBuildings[id] = curUnit
					
					if curUnit:IsTower() then
						tSortedUnits.allyTowers[id] = curUnit
					elseif curUnit:IsUnitType("Well") and curUnit:GetCanAttack() then
						tSortedUnits.allyTowers[id] = curUnit
					elseif curUnit:IsRax() then
						tSortedUnits.allyRax[id] = curUnit					
					end
				else
					tSortedUnits.allyUnits[id] = curUnit
					
					if curUnit:IsHero() then
						tSortedUnits.allyHeroes[id] = curUnit
					elseif not core.IsCourier(curUnit) then
						tSortedUnits.allyCreeps[id] = curUnit
					end	
				end
			elseif curUnit:GetTeam() == enemyTeam then
				if curUnit:IsHero() and bHeroesAsMemoryUnits then
					curUnit = teamBotBrain:CreateMemoryUnit(curUnit)
				end
				
				tSortedUnits.enemies[id] = curUnit
				
				if curUnit:IsBuilding() then
					tSortedUnits.enemyBuildings[id] = curUnit
					
					if curUnit:IsTower() then
						tSortedUnits.enemyTowers[id] = curUnit
					elseif curUnit:IsUnitType("Well") and curUnit:GetCanAttack() then
						tSortedUnits.enemyTowers[id] = curUnit
					elseif curUnit:IsRax() then
						tSortedUnits.enemyRax[id] = curUnit					
					end
				else
					tSortedUnits.tEnemyUnits[id] = curUnit
					
					if curUnit:IsHero() then
						tSortedUnits.enemyHeroes[id] = curUnit
					else
						tSortedUnits.enemyCreeps[id] = curUnit
					end	
				end
			end
			StopProfile()
		end
	end
	StopProfile()
	
	return tSortedUnits
end

function core.SortBuildings(tBuildingList, tSortedTable)
	local dDebugEchos = false
	
	--Filter a list of buildings into convenient tables
	tSortedTable = tSortedTable or {}
	tSortedTable.enemyBuildings				= tSortedTable.enemyBuildings or {}
	tSortedTable.enemyTowers				= tSortedTable.enemyTowers or {}
	tSortedTable.enemyRax					= tSortedTable.enemyRax or {}
	tSortedTable.enemyMainBaseStructure		= tSortedTable.enemyMainBaseStructure or nil
	tSortedTable.enemyWell					= tSortedTable.enemyWell or nil
	tSortedTable.enemyWellAttacker			= tSortedTable.enemyWellAttacker or nil
	tSortedTable.enemyOtherBuildings		= tSortedTable.enemyOtherBuildings or {}
	tSortedTable.allyBuildings				= tSortedTable.allyBuildings or {}
	tSortedTable.allyTowers					= tSortedTable.allyTowers or{}
	tSortedTable.allyRax					= tSortedTable.allyRax or {}
	tSortedTable.allyMainBaseStructure		= tSortedTable.allyMainBaseStructure or nil
	tSortedTable.allyWell					= tSortedTable.allyWell or nil
	tSortedTable.allyWellAttacker			= tSortedTable.allyWellAttacker or nil
	tSortedTable.allyOtherBuildings			= tSortedTable.allyOtherBuildings or {}
	tSortedTable.shops						= tSortedTable.shops or {}
	
	local allyTeam = core.myTeam
	local enemyTeam = core.enemyTeam
	
	for key, building in pairs(tBuildingList) do
		--BotEcho("SortBuildings - building: "..tostring(building:GetTypeName()))
		if building ~= nil and building:IsBuilding() then
			local nID = building:GetUniqueID()
			local team = building:GetTeam()
			if team == allyTeam then
				local bPlaced = false
				if building:IsTower() then
					tSortedTable.allyTowers[nID] = building
					bPlaced = true
				end
				if building:IsRax() then
					tSortedTable.allyRax[nID] = building
					bPlaced = true
				end
				if building:IsBase() then
					if tSortedTable.allyMainBaseStructure ~= nil then
						Echo(format("%s - ERROR: more than one ally base discovered!! %s and %s", 
						object.myName, building:GetTypeName(), tSortedTable.allyMainBaseStructure:GetTypeName()))
					end
					tSortedTable.allyMainBaseStructure = building
					bPlaced = true
				end
				if building:IsUnitType("Well") then
					if building:GetCanAttack() then
						tSortedTable.allyWellAttacker = building
					else
						tSortedTable.allyWell = building
					end
					bPlaced = true
				end
				if not bPlaced then
					tSortedTable.allyOtherBuildings[nID] = building
				end
				tSortedTable.allyBuildings[nID] = building
			elseif team == enemyTeam then
				local bPlaced = false
				if building:IsTower() then
					tSortedTable.enemyTowers[nID] = building
					bPlaced = true
				end
				if building:IsRax() then
					tSortedTable.enemyRax[nID] = building
					bPlaced = true
				end
				if building:IsBase() then
					if tSortedTable.enemyMainBaseStructure ~= nil then
						Echo(format("%s - ERROR: more than one enemy base discovered!! %s and %s", 
						object.myName, building:GetTypeName(), tSortedTable.enemyMainBaseStructure:GetTypeName()))
					end
					tSortedTable.enemyMainBaseStructure = building
					bPlaced = true
				end
				if building:IsUnitType("Well") then
					if building:GetCanAttack() then
						tSortedTable.enemyWellAttacker = building
					else
						tSortedTable.enemyWell = building
					end
					bPlaced = true
				end
				if not bPlaced then
					tSortedTable.enemyOtherBuildings[nID] = building
				end
				tSortedTable.enemyBuildings[nID] = building
			end
			
			if building:IsShop() then
				tSortedTable.shops[nID] = building
			end
		end
	end
		
	if dDebugEchos then
		BotEcho("BuildingList:")
		core.printGetTypeNameTable(tBuildingList)		
		BotEcho("--enemyTowers:")
		core.printGetTypeNameTable(tSortedTable.enemyTowers)
		BotEcho("--enemyRax:")
		core.printGetTypeNameTable(tSortedTable.enemyRax)
		BotEcho("--enemyMainBaseStructure:")
		BotEcho((tSortedTable.enemyMainBaseStructure and tSortedTable.enemyMainBaseStructure:GetTypeName()) or "nil")
		BotEcho("--enemyOtherBuildings:")
		core.printGetTypeNameTable(tSortedTable.enemyOtherBuildings)
		BotEcho("--allyTowers:")
		core.printGetTypeNameTable(tSortedTable.allyTowers)
		BotEcho("--allyRax:")
		core.printGetTypeNameTable(tSortedTable.allyRax)
		BotEcho("--allyMainBaseStructure:")
		BotEcho((tSortedTable.allyMainBaseStructure and tSortedTable.allyMainBaseStructure:GetTypeName()) or "nil")
		BotEcho("--allyOtherBuildings:")
		core.printGetTypeNameTable(tSortedTable.allyOtherBuildings)
		BotEcho("--shops:")
		core.printGetTypeNameTable(tSortedTable.shops)
	end
	
	return tSortedTable
end

function core.TimeToPosition(position, myLocation, moveSpeed, itemGhostMarchers)
	local bDebugLines = false
	local bDebugEchos = false
	
	--How long will it take to move to a position.  Takes into account ghostmarchers, but not TPs
	local tPath = BotMetaData.FindPath(myLocation, position)
	local totalDist = 0
	local nPathDistance = 0
	if tPath ~= nil then
		local vecLastNodePosition = nil
		for i, node in ipairs(tPath) do
			if node then
				local vecNodePosition = node:GetPosition()
				if vecLastNodePosition then
					--node to node
					nPathDistance = nPathDistance + Vector3.Distance2D(vecLastNodePosition, vecNodePosition)					
					if bDebugLines then
						core.DrawDebugArrow(vecLastNodePosition, vecNodePosition, 'blue')
					end					
				else
					--start to first node
					nPathDistance = nPathDistance + Vector3.Distance2D(myLocation, vecNodePosition)					
					if bDebugLines then
						core.DrawDebugArrow(myLocation, vecNodePosition, 'blue')
					end			
				end
				vecLastNodePosition = vecNodePosition
			end
		end
		--last to end
		nPathDistance = nPathDistance + Vector3.Distance2D(vecLastNodePosition, position) 
		if bDebugLines then
			core.DrawDebugArrow(vecLastNodePosition, position, 'blue')
		end		
	end
	
	if bDebugEchos then BotEcho(format("TimeToPosition - pathDist: %s  cartesianDist: %s", nPathDistance, nCartesianDistance)) end
	
	if nPathDistance > 0 then
		totalDist = nPathDistance
	else
		local nCartesianDistance = Vector3.Distance2D(myLocation, position)	
		totalDist = nCartesianDistance
	end
	
	local moveSpeedPerMS = moveSpeed / 1000
	local timeMS = 0
	
	if itemGhostMarchers == nil then
		timeMS = totalDist / moveSpeedPerMS
	else
		local bGhostOn = HoN.GetGameTime() < itemGhostMarchers.expireTime
		local curCDTimeMS = itemGhostMarchers:GetRemainingCooldownTime()
		
		local ghostMoveSpeedPerMS = 0
		local cdTimeMS = itemGhostMarchers:GetCooldownTime()
		
		local remainingDist = totalDist
		
		if bGhostOn then
			--already activated, need to get our original MS
			ghostMoveSpeedPerMS = moveSpeedPerMS
			moveSpeed = moveSpeed / (1 + itemGhostMarchers.msMult)
			moveSpeedPerMS = moveSpeed / 1000
		else
			ghostMoveSpeedPerMS = moveSpeedPerMS * (1 + itemGhostMarchers.msMult)
		end
		
		--[[
		Echo(format(
			"GhostOn: %s, ghostMS: %d, normalMS: %d, CD: %g, curCD: %g",
			tostring(bGhostOn), ghostMoveSpeedPerMS * 1000, moveSpeedPerMS * 1000, cdTimeMS / 1000, 
			curCDTimeMS / 1000
			)
		)
		--]]
		
		--simulate the "use ghost when up" movement
		while remainingDist > 0 do
			if not bGhostOn then
				--calc movement until ghost is up
				local timeStep = curCDTimeMS
				local moveStep = moveSpeedPerMS * timeStep
				if remainingDist < moveStep then --we will arrive during
					timeMS = timeMS + (remainingDist / moveSpeedPerMS)
					remainingDist = 0
				else
					timeMS = timeMS + timeStep
					remainingDist = remainingDist - moveStep
					
					curCDTimeMS = cdTimeMS
					bGhostOn = true
				end
			else 
				--calc movement while ghost is applied
				local timeStep = itemGhostMarchers.duration
				local ghostMoveStep = ghostMoveSpeedPerMS * timeStep
				if remainingDist < ghostMoveStep then --we will arrive during
					timeMS = timeMS + (remainingDist / ghostMoveSpeedPerMS)
					remainingDist = 0
				else
					timeMS = timeMS + timeStep
					remainingDist = remainingDist - ghostMoveStep
					
					curCDTimeMS = curCDTimeMS - itemGhostMarchers.duration
					bGhostOn = false
				end
			end
		end		
	end
	
	return timeMS
end

function core.GetLaneBreakdown(unit)
	local bDebugLines = false
	local lineLen = 150

	local tLanePoints = nil
	local sLaneName = nil
	local nPercent = nil
	
	local position = unit:GetPosition()
	local topDist = 99999
	local midDist = 99999
	local botDist = 99999
	local inTop = -1
	local inMid = -1
	local inBot = -1		

	local vecTopPoint = core.GetFurthestPointOnPath(position, metadata.GetTopLane(), core.bTraverseForward)		
	if vecTopPoint then
		topDist = Vector3.Distance2D(position, vecTopPoint)
	end
	
	local vecMidPoint = core.GetFurthestPointOnPath(position, metadata.GetMiddleLane(), core.bTraverseForward)
	if vecMidPoint then
		midDist = Vector3.Distance2D(position, vecMidPoint)
	end
	
	local vecBotPoint = core.GetFurthestPointOnPath(position, metadata.GetBottomLane(), core.bTraverseForward)
	if vecBotPoint then
		botDist = Vector3.Distance2D(position, vecBotPoint)
	end
	
	--pick two lowest ones
	local nBiggestDist = max(topDist, midDist, botDist)
	local nLowestDist = min(topDist, midDist, botDist)
	if (nLowestDist > 1200) then --clearly not in a lane.
		return {top=0, mid=0, bot=0}, {top=vecTopPoint, mid=vecMidPoint, bot=vecBotPoint}
	end
	
	if topDist == nBiggestDist then
		topDist = 0
		inTop = 0
	elseif midDist == nBiggestDist then
		midDist = 0
		inMid = 0
	elseif botDist == nBiggestDist then
		botDist = 0
		inBot = 0
	end
	
	local totalDist = topDist + midDist + botDist
	
	if inTop ~= 0 then
		inTop = 1 - topDist / totalDist
	end
	if inMid ~= 0 then
		inMid = 1 - midDist / totalDist
	end
	if inBot ~= 0 then
		inBot = 1 - botDist / totalDist
	end
	
	--BotEcho(format('%s - top: %g  mid: %g  bot:%g', unit:GetTypeName(), inTop, inMid, inBot))
	--BotEcho(format('%s Dists - top: %g  mid: %g  bot:%g  total:%g', unit:GetTypeName(), topDist, midDist, botDist, totalDist))
	if bDebugLines then
		core.DrawXPosition(position, 'red')
		if vecTopPoint then
			core.DrawDebugArrow(position, position + Vector3.Normalize(vecTopPoint - position) * inTop * lineLen, 'yellow')
		end
		if vecMidPoint then
			core.DrawDebugArrow(position, position + Vector3.Normalize(vecMidPoint - position) * inMid * lineLen, 'yellow')
		end
		if vecBotPoint then
			core.DrawDebugArrow(position, position + Vector3.Normalize(vecBotPoint - position) * inBot * lineLen, 'yellow')
		end
	end
	
	return {top=inTop, mid=inMid, bot=inBot}, {top=vecTopPoint, mid=vecMidPoint, bot=vecBotPoint}
end

function core.GetFurthestPointOnPath(position, tPath, bTraverseForward)
	if bTraverseForward == nil then
		bTraverseForward = true
	end
	
	local bDebugLines = false

	if tPath == nil or #tPath < 1 then
		BotEcho('GetFurthestPointOnPath - invalid path!')
		return nil
	end
	
	local furthestDistSq = 0
	local vecFurthestPoint = nil
			
	local i = 1
	local nSize = #tPath
	if not bTraverseForward then
		i = nSize
	end
	
	local node = tPath[i]
	local lastNode = nil
	
	local vecStartPos = node:GetPosition()
	local nMyDistSq = Vector3.Distance2DSq(vecStartPos, position)
	--BotEcho('vecStartPos: '..tostring(vecStartPos))
	
	if bDebugEchos then BotEcho('AssessLaneDirection nodes: '..nSize..'  i: '..i) end
	while node do
		if bDebugEchos then BotEcho('loop i: '..i..'  node: '..tostring(node:GetPosition())..'  lastNode: '..tostring(lastNode:GetPosition())) end
		
		local vecCurPoint = nil
		local nCurDistSq = 0
		if lastNode then			
			vecCurPoint = core.GetFurthestPointOnLine(position, lastNode:GetPosition(), node:GetPosition())			
			nCurDistSq = Vector3.Distance2DSq(vecStartPos, vecCurPoint)
			
			local nLastNodeDistSq = Vector3.Distance2DSq(vecStartPos, lastNode:GetPosition())
			if abs(nCurDistSq - nLastNodeDistSq) < 1 then
				break --we can't project onto this segment
			end
			
			if nCurDistSq > furthestDistSq then
				furthestDistSq = nCurDistSq
				vecFurthestPoint = vecCurPoint
			end
		end
		
		if bDebugLines then
			if lastNode then
				core.DrawDebugArrow(lastNode:GetPosition(), node:GetPosition(), 'cyan')
			end			
			--core.DrawXPosition(node:GetPosition(), 'blue')
			if vecCurPoint then
				core.DrawXPosition(vecCurPoint, 'yellow')
			end
		end
		
		--iterate		
		if bTraverseForward == true then
			i = i + 1
		else
			i = i - 1
		end	
		
		if tPath[i] == nil then
			if bDebugEchos then BotEcho('end of the path, break') end
			break
		end
		
		lastNode = node
		node = tPath[i]
	end
	
	if bDebugLines then core.DrawXPosition(vecFurthestPoint, 'red') end
	
	return vecFurthestPoint
end

function core.GetFurthestPointOnLine(vecPosition, vecStart, vecEnd)
	local vecA = vecStart
	local vecB = vecEnd
	local vecC = vecPosition
	
	--[[   A          D     B
	       *----------?-----*
		              |
					  |
					C *
	--]]
	
	local vecAB = vecB - vecA
	local nMagAB = Vector3.Length(vecAB)
	local vecAC = vecC - vecA
	
	local nMagAD = Vector3.Dot(vecAB, vecAC) / nMagAB
	if nMagAD > nMagAB then
		nMagAD = nMagAB
	end
	
	if nMagAD < 0 then
		nMagAD = 0
	end
	
	local vecPointD = vecA + nMagAD * (vecAB / nMagAB)
	
	--BotEcho(format('A: %s  B: %s  C: %s  D: %s', tostring(vecA), tostring(vecB), tostring(vecC), tostring(vecPointD)))
	
	return vecPointD
end

function core.GetTowersThreateningPosition(vecPosition, nTargetExtraRange, nTeamToIgnore)
	--TODO: switch to just iterate through the enemy towers instead of calling GetUnitsInRadius
	nTargetExtraRange = nTargetExtraRange or 0
	
	local nTowerRange = 821.6 --700 + (86 * sqrtTwo)
	nTowerRange = nTowerRange + nTargetExtraRange
	local tBuildings = HoN.GetUnitsInRadius(vecPosition, nTowerRange, core.UNIT_MASK_ALIVE + core.UNIT_MASK_BUILDING)
	for key, unitBuilding in pairs(tBuildings) do
		if not unitBuilding:IsTower() or (nTeamToIgnore ~= nil and unitBuilding:GetTeam() == nTeamToIgnore) then
			tBuildings[key] = nil
		end
	end
	
	return tBuildings
end

function core.GetTowersThreateningUnit(unit, bIncludeAllyTowers)
	if bIncludeAllyTowers == nil then
		bIncludeAllyTowers = false
	end
	
	local nTeamToIgnore = nil
	if not bIncludeAllyTowers then
		nTeamToIgnore = unit:GetTeam()
	end
	
	return core.GetTowersThreateningPosition(unit:GetPosition(), core.GetExtraRange(unit), nTeamToIgnore)
end

function core.FindCenterOfMass(tUnitList, funcWeighting)
	if funcWeighting == nil then
		funcWeighting = function(unit) return 1 end
	end
	
	--Get total weight
	local tWeightPairs = {}
	local nTotalWeight = 0
	for key, unit in pairs(tUnitList) do
		local nWeight = funcWeighting(unit)
		tWeightPairs[unit] = nWeight
		nTotalWeight = nTotalWeight + nWeight		
	end
	
	local vecCenter = Vector3.Create()
	for unit, nWeight in pairs(tWeightPairs) do
		vecCenter = vecCenter + unit:GetPosition() * (nWeight / nTotalWeight)
	end
	
	return vecCenter
end

function core.AoETargeting(unitSelf, nRange, nRadius, bPositionTargets, unitPriorityTarget, nTeamFilter, funcWeighting)
	local bDebugEchos = false
	local bDebugLines = false
	local nLineLength = 50	
	
	local vecMyPosition = unitSelf:GetPosition()
	local target = nil
	local nTargetID = (unitPriorityTarget and unitPriorityTarget:GetUniqueID()) or nil
	local nMyExtraRange = core.GetExtraRange(core.unitSelf)
	
	local teamBotBrain = core.teamBotBrain
	
	if bDebugEchos then 
		BotEcho(format("unitSelf: %s  nRange: %s  nRadius: %s  bPositionTargets: %s  unitPriorityTarget: %s  nTeamFilter: %s  \n\tfuncWeighting: (%s)",
			tostring(unitSelf), tostring(nRange), tostring(nRadius), tostring(bPositionTargets), tostring(unitPriorityTarget), 
			tostring(nTeamFilter), tostring(funcWeighting)))
	end
	
	if nRange then
		local tTargets = HoN.GetUnitsInRadius(vecMyPosition, nRange + nMyExtraRange, core.UNIT_MASK_ALIVE + core.UNIT_MASK_HERO)
		--teamBotBrain:AddMemoryUnitsToTable(tTargets, nTeamFilter, vecMyPosition, nRange + nMyExtraRange)
		
		local nLargestHitValue = 0
		local tBestTargets = {}
		for _, unitTarget in pairs(tTargets) do
			local vecTargetPosition = unitTarget:GetPosition()
			local tUnitsHit = HoN.GetUnitsInRadius(vecTargetPosition, nRadius, core.UNIT_MASK_ALIVE + core.UNIT_MASK_HERO)
			teamBotBrain:AddMemoryUnitsToTable(tUnitsHit, nTeamFilter, vecTargetPosition, nRadius)
			
			local nCurrentHitValue = 0
			local bTargetHit = false
			
			for _, unitHero in pairs(tUnitsHit) do
				if nTeamFilter == nil or unitHero:GetTeam() == nTeamFilter then
					local nWeight = 1.0
					if funcWeighting then
						nWeight = funcWeighting(unitHero)
					end
					nCurrentHitValue = nCurrentHitValue + nWeight
				
					if nTargetID == nil or nTargetID == unitHero:GetUniqueID() then
						bTargetHit = true
					end
				end
			end
			
			if bTargetHit then
				if nCurrentHitValue == nLargestHitValue then
					tinsert(tBestTargets, unitTarget)
				elseif nCurrentHitValue > nLargestHitValue then
					nLargestHitValue = nCurrentHitValue
					tBestTargets = nil
					tBestTargets = {}
					tinsert(tBestTargets, unitTarget)
				end
			end
			
			if bDebugLines then
				if nTeamFilter == nil or unitTarget:GetTeam() == nTeamFilter then
					core.DrawXPosition(unitTarget:GetPosition(), 'teal')
					core.DrawDebugLine(unitTarget:GetPosition(), unitTarget:GetPosition() + Vector3.Create(0,1) * nCurrentHitValue * nLineLength, 'teal')
				end
			end
		end
		
		local nNumberBestTargets = core.NumberElements(tBestTargets)
		if bDebugEchos then BotEcho(format("numTargets: %d  numBestTargets: %d", core.NumberElements(tTargets), nNumberBestTargets)) end
		if nNumberBestTargets > 0 then
			local nRand = random(nNumberBestTargets)
			target = tBestTargets[nRand]
		end
		
		if bDebugLines then
			for _, unit in pairs(tBestTargets) do
				local sColor = (unit == target and 'red') or 'yellow'
				core.DrawXPosition(unit:GetPosition(), sColor)
			end
		end
	end	
	
	if bPositionTargets and target ~= nil then
		target = target:GetPosition()
	end
	
	return target
end

function core.HasBuildingTargets(tBuildings)
	--Does this table have buildings worth targeting (rax, towers, or base)?
	for _, unitBuilding in pairs(tBuildings) do
		if unitBuilding:IsTower() or unitBuilding:IsRax() or unitBuilding:IsBase() then
			return true
		end		
	end
	
	return false
end

function core.GetGroupCenter(tGroup)	
	return HoN.GetGroupCenter(tGroup)
end


function core.ValidateReferenceTable(tReferences)
	for key, thing in pairs(tReferences) do
		if thing == nil or not thing:IsValid() then
			tReferences[key] = nil
		end
	end
end

function core.ValidateUnitReferences()
	if core.enemyMainBaseStructure and not core.enemyMainBaseStructure:IsValid() then
		core.enemyMainBaseStructure = nil
		BotEcho('ERROR - enemyMainBaseStructure is not valid!')
	end
	
	if core.enemyWell and not core.enemyWell:IsValid() then
		core.enemyWell = nil
		BotEcho('ERROR - enemyWell is not valid!')
	end
	
	if core.allyMainBaseStructure and not core.allyMainBaseStructure:IsValid() then
		core.allyMainBaseStructure = nil
		BotEcho('ERROR - allyMainBaseStructure is not valid!')
	end
	
	if core.allyWell and not core.allyWell:IsValid() then
		core.allyWell = nil
		BotEcho('ERROR - allyWell is not valid!')
	end

	core.ValidateReferenceTable(core.enemyTowers)
	core.ValidateReferenceTable(core.enemyRax)
	core.ValidateReferenceTable(core.allyTowers)
	core.ValidateReferenceTable(core.allyRax)
end


---------------------- Translators -----------------------
function core.GetAttackSequenceProgress(unit)
	--[[
	|---------attackCooldown--------|   1700 (except for a few heroes)
	|--attackDuration--|            |   1000 (except for a few heroes)
	|-------|  (attackActionTime)   |   variable, usually 300-500
	        ^  (when the attack goes off)
	
	|-------|                       | == "windup"
	|       |----------|            | == "followThrough"
	|                  |------------| == "idle"
	
	the whole thing is scaled down with increased attack speed
	--]]

	if unit == nil then
		return ""
	end
	
	local retVal = ""

	local behav = unit:GetBehavior()	
	if behav ~= nil and behav.GetAttackingActionState ~= nil then
		local attackAS = behav:GetAttackingActionState()
		if attackAS ~= nil and attackAS.IsActive ~= nil and attackAS.IsCompleted ~= nil then
			if attackAS:IsActive() and attackAS:IsCompleted() then
				retVal = "followThrough"
			elseif attackAS:IsActive() then
				retVal = "windup"
			else
				retVal = "idle"
			end
		end
	end
	
	return retVal
end

--unitCreepTarget is an optional parameter that will be passed in
function core.GetAttackDamageMinOnCreep(unitCreepTarget)
	local unitSelf = core.unitSelf
	local nDamageMin = unitSelf:GetFinalAttackDamageMin()
				
	if core.itemHatchet then
		nDamageMin = nDamageMin * core.itemHatchet.creepDamageMul
	end	

	return nDamageMin
end


------------------ misc overrides and remanes ------------------
function core.CanSeeUnit(botBrain, unit)
	local unitParam = (unit ~= nil and unit.object) or unit
	return botBrain:CanSeeUnit(unitParam)
end

--==== Item ====
local itemMetatable = HoN.GetMetatable("IEntityItem")
--GetValue -> GetSellValue
if itemMetatable.GetValue ~= nil and itemMetatable.GetSellValue == nil then
	itemMetatable.GetSellValue = itemMetatable.GetValue
end
--GetIsChanneling -> IsChanneling
if itemMetatable.GetIsChanneling ~= nil and itemMetatable.IsChanneling == nil then
	itemMetatable.IsChanneling = itemMetatable.GetIsChanneling
end
--GetType -> GetTypeID
if itemMetatable.GetType ~= nil and itemMetatable.GetTypeID == nil then
	itemMetatable.GetTypeID = itemMetatable.GetType
end
--GetTypeName -> GetName
if itemMetatable.GetTypeName ~= nil and itemMetatable.GetName == nil then
	itemMetatable.GetName = itemMetatable.GetTypeName
end

--==== Ability ====
local abilityMetatable = HoN.GetMetatable("IEntityAbility")
--GetType -> GetTypeID
if abilityMetatable.GetType ~= nil and abilityMetatable.GetTypeID == nil then
	abilityMetatable.GetTypeID = abilityMetatable.GetType
end
--GetTypeName -> GetName
if abilityMetatable.GetTypeName ~= nil and abilityMetatable.GetName == nil then
	abilityMetatable.GetName = abilityMetatable.GetTypeName
end

--==== Unit ====
local unitMetatable = HoN.GetMetatable("IUnitEntity")
--GetUnitwalking -> IsUnitwalking
if unitMetatable.GetUnitwalking ~= nil and unitMetatable.IsUnitwalking == nil then
	unitMetatable.IsUnitwalking = unitMetatable.GetUnitwalking
end
--GetTreewalking -> IsTreewalking
if unitMetatable.GetTreewalking ~= nil and unitMetatable.IsTreewalking == nil then
	unitMetatable.IsTreewalking = unitMetatable.GetTreewalking
end
--GetCliffwalking -> IsCliffwalking
if unitMetatable.GetCliffwalking ~= nil and unitMetatable.IsCliffwalking == nil then
	unitMetatable.IsCliffwalking = unitMetatable.GetCliffwalking
end
--GetStashAccess -> CanAccessStash
if unitMetatable.GetStashAccess ~= nil and unitMetatable.CanAccessStash == nil then
	unitMetatable.CanAccessStash = unitMetatable.GetStashAccess
end
