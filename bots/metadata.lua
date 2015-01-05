-- metadata v1.0


local _G = getfenv(0)
local object = _G.object

object.metadata = object.metadata or {}
local metadata = object.metadata

local core = object.core
local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog

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

metadata.MapMetadataFile = ""
metadata.bInitialized = false

function metadata.Initialize(sMapName)	
	if sMapName == "caldavar" then
		metadata.MapMetadataFile = '/bots/caldavar.botmetadata'
	elseif sMapName == "tutorial_stage1" then
		metadata.MapMetadataFile = '/bots/tutorial1.botmetadata'
	elseif sMapName == "tutorial" then
		metadata.MapMetadataFile = '/bots/caldavar.botmetadata'
	elseif sMapName == "tutorial_lasthit" then
		metadata.MapMetadataFile = '/bots/tutorial1.botmetadata'
	else
		BotEcho(" ! ! Warning, no metadata for map "..sMapName.." ! !")
	end

	--Todo: per map awaypoints
	BotMetaData.RegisterLayer('/bots/getAwayPoints.botmetadata')
	BotMetaData.RegisterLayer(metadata.MapMetadataFile)
	BotMetaData.SetActiveLayer(metadata.MapMetadataFile)

	-- Set up lanes
	local vecStart = Vector3.Create()
	local vecEnd = Vector3.Create(16000, 16000)
	
	local sLane = 'top' -- upvalue for funcLaneCost
	
	local function funcLaneCost(nodeParent, nodeCurrent, link, nOriginalCost)	
		local laneProperty = nodeCurrent:GetProperty('lane')
		if laneProperty and laneProperty == sLane then
			return nOriginalCost
		end
		
		return nOriginalCost + 9999
	end
	
	metadata.tTop = BotMetaData.FindPath(vecStart, vecEnd, funcLaneCost)
	metadata.tTop.sLaneKey = sLane
	metadata.tTop.sLaneName = 'lane_top'
	
	sLane = 'middle'
	metadata.tMiddle = BotMetaData.FindPath(vecStart, vecEnd, funcLaneCost)
	metadata.tMiddle.sLaneKey = sLane
	metadata.tMiddle.sLaneName = 'lane_mid'
	
	sLane = 'bottom'
	metadata.tBottom = BotMetaData.FindPath(vecStart, vecEnd, funcLaneCost)
	metadata.tBottom.sLaneKey = sLane
	metadata.tBottom.sLaneName = 'lane_bot'
	
	if metadata.tTop == nil or core.NumberElements(metadata.tTop) == 0 then
		BotEcho('Top lane is invalid!')
	end
	if metadata.tMiddle == nil or core.NumberElements(metadata.tMiddle) == 0 then
		BotEcho('Middle lane is invalid!')
	end
	if metadata.tBottom == nil or core.NumberElements(metadata.tBottom) == 0 then
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
