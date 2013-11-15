-- metadata v1.0


local _G = getfenv(0)
local object = _G.object

object.metadata = object.metadata or {}
local metadata = object.metadata

local core = object.core
local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog

--------------------------------

BotMetaData.RegisterLayer('/bots/test.botmetadata')
BotMetaData.RegisterLayer('/bots/getAwayPoints.botmetadata')
BotMetaData.SetActiveLayer('/bots/test.botmetadata')

--------------------------------

metadata.tTop = {}
metadata.tMiddle = {}
metadata.tBottom = {}

function metadata.GetTopLane()
	return metadata.tTop
end

function metadata.GetMiddleLane()
	return metadata.tMiddle
end

function metadata.GetBottomLane()
	return metadata.tBottom
end

function metadata.GetLane(sLane)
	sLane = sLane or 'middle'
	
	if sLane == 'middle' then
		return metadata.tMiddle
	elseif sLane == 'top' then
		return metadata.tTop
	elseif sLane == 'bottom' then
		return metadata.tBottom
	end
	
	return {}
end

metadata.bInitialized = false

function metadata.Initialize()
	local vecStart = Vector3.Create()
	local vecEnd = Vector3.Create(16000, 16000)
	
	local sLane = 'top'
	
	local function funcLaneCost(nodeParent, nodeCurrent, link, nOriginalCost)	
		local laneProperty = nodeCurrent:GetProperty('lane')
		if laneProperty and laneProperty == sLane then
			return nOriginalCost
		end
		
		return nOriginalCost + 9999
	end
	
	metadata.tTop = BotMetaData.FindPath(vecStart, vecEnd, funcLaneCost)
	metadata.tTop.sLaneName = 'top'
	
	sLane = 'middle'
	metadata.tMiddle = BotMetaData.FindPath(vecStart, vecEnd, funcLaneCost)
	metadata.tMiddle.sLaneName = 'middle'
	
	sLane = 'bottom'
	metadata.tBottom = BotMetaData.FindPath(vecStart, vecEnd, funcLaneCost)
	metadata.tBottom.sLaneName = 'bottom'
	
	if metadata.tTop == nil then
		BotEcho('Top lane is invalid!')
	end
	if metadata.tMiddle == nil then
		BotEcho('Middle lane is invalid!')
	end
	if metadata.tBottom == nil then
		BotEcho('Bottom lane is invalid!')
	end

	metadata.bInitialized = true
end

function metadata.PathToTest(botBrain, vecPos)
	local unitHero = botBrain:GetHeroUnit()
		
	if (botBrain.tPathing == nil or botBrain.tPathing.vecGoal ~= vecPos) then
		botBrain.tPathing = {}
		botBrain.tPathing.vecStart = unitHero:GetPosition()
		botBrain.tPathing.vecGoal = vecPos
		core.BotEcho("Okay! Pathing from <" .. botBrain.tPathing.vecStart.x .. ", " .. botBrain.tPathing.vecStart.y .. ", " .. botBrain.tPathing.vecStart.Z
				.. "> to <" .. botBrain.tPathing.vecGoal.x .. ", " .. botBrain.tPathing.vecGoal.y .. ", " .. botBrain.tPathing.vecGoal.z .. ">")
		
		botBrain.tPathing.tPath = BotMetaData.FindPath(botBrain.tPathing.vecStart, botBrain.tPathing.vecGoal)
		if (botBrain.tPathing.tPath ~= nil) then
			botBrain.tPathing.nNode = 1
			botBrain.tPathing.bMove = true
		else
			BotBrain.tPathing = nil
		end
	end
	
	if (botBrain.tPathing ~= nil) then
		for i, node in ipairs(botBrain.tPathing.tPath) do
			if (i + 1 <= #botBrain.tPathing.tPath) then
				core.DrawDebugArrow(node:GetPosition(), botBrain.tPathing.tPath[i + 1]:GetPosition(), "red")
			end
		end
		
		if (botBrain.tPathing.nNode <= #botBrain.tPathing.tPath) then
			if (botBrain.tPathing.bMove == true) then
				local vecTarget = botBrain.tPathing.tPath[botBrain.tPathing.nNode]:GetPosition()
				core.OrderMoveToPosClamp(botBrain, unitHero, vecTarget)
				botBrain.tPathing.bMove = false
			end
			
			local vecNodePos = botBrain.tPathing.tPath[botBrain.tPathing.nNode]:GetPosition()
			core.DrawXPosition(vecNodePos, "red")
			
			local vecMyPos = unitHero:GetPosition()
			core.DrawDebugArrow(vecMyPos, vecNodePos, "blue")
			
			vecNodePos.z = 0
			vecMyPos.z = 0
			
			if (Vector3.DistanceSq(vecNodePos, vecMyPos) < (256 * 256)) then
				core.BotEcho("Hit node " .. botBrain.tPathing.nNode .. " (" .. botBrain.tPathing.tPath[botBrain.tPathing.nNode]:GetName() .. ")")
				botBrain.tPathing.nNode = botBrain.tPathing.nNode + 1
				if (botBrain.tPathing.nNode <= #botBrain.tPathing.tPath) then
					core.BotEcho("Moving on to node " .. botBrain.tPathing.nNode .. " (" .. botBrain.tPathing.tPath[botBrain.tPathing.nNode]:GetName() .. ")")
					botBrain.tPathing.bMove = true
				else
					core.BotEcho("All done pathing!")
				end
			end
		end
	end
end
