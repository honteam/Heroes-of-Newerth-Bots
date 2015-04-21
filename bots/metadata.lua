-- metadata v1.0

local _G = getfenv(0)
local object = _G.object

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

object.metadata = object.metadata or {}
local metadata = object.metadata

local core = object.core
local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog

--------------------------------

metadata.tTop = nil
metadata.tMiddle = nil
metadata.tBottom = nil

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
	sLane = sLane or 'lane_mid'
	
	if sLane == 'lane_mid' then
		return metadata.tMiddle
	elseif sLane == 'lane_top' then
		return metadata.tTop
	elseif sLane == 'lane_bot' then
		return metadata.tBottom
	end
	
	return {}
end

metadata.MapMetadataFile = nil
metadata.JukeMetadataFile = nil

metadata.tMetadataFileNames = {}

metadata.bInitialized = false

function metadata.SetActiveLayer(sLayerName)
	if metadata.tMetadataFileNames[sLayerName] == true then
		BotMetaData.SetActiveLayer(sLayerName)
	else
		BotEcho("Metadata layer " .. sLayerName .. " not found.")
	end
end


function metadata.Initialize(sMapName)
	local tMetadataFileNames = metadata.tMetadataFileNames
	if sMapName == "caldavar" then
		metadata.MapMetadataFile = '/bots/metadata/caldavar.botmetadata'
		metadata.JukeMetadataFile = "/bots/metadata/jukePoints_caldavar.botmetadata"
	elseif sMapName == "midwars" then
		metadata.MapMetadataFile = '/bots/metadata/midwars.botmetadata'
		metadata.JukeMetadataFile = "/bots/metadata/jukePoints_midwars.botmetadata"
	elseif sMapName == "grimmscrossing" then
		metadata.MapMetadataFile = "/bots/metadata/grimmscrossing.botmetadata"
		metadata.JukeMetadataFile = "/bots/metadata/jukePoints_grimmscrossing.botmetadata"
	elseif sMapName == "tutorial_stage1" then
		metadata.MapMetadataFile = '/bots/metadata/tutorial1.botmetadata'
		metadata.JukeMetadataFile = "/bots/metadata/jukePoints_caldavar.botmetadata"
	elseif sMapName == "tutorial" then
		metadata.MapMetadataFile = '/bots/metadata/caldavar.botmetadata'
		metadata.JukeMetadataFile = "/bots/metadata/jukePoints_caldavar.botmetadata"
	elseif sMapName == "tutorial_lasthit" then
		metadata.MapMetadataFile = '/bots/metadata/tutorial1.botmetadata'
		metadata.JukeMetadataFile = "/bots/metadata/jukePoints_caldavar.botmetadata"
	else
		BotEcho(" ! ! Warning, no metadata for map "..sMapName.." ! !")
	end
	
	if metadata.MapMetadataFile ~= nil then
		metadata.tMetadataFileNames[metadata.MapMetadataFile] = true
		BotEcho("Trying to register \""..metadata.MapMetadataFile.."\"")
		BotMetaData.RegisterLayer(metadata.MapMetadataFile)
	end
	
	if metadata.JukeMetadataFile ~= nil then
		metadata.tMetadataFileNames[metadata.JukeMetadataFile] = true
		BotEcho("Trying to register \""..metadata.JukeMetadataFile.."\"")
		BotMetaData.RegisterLayer(metadata.JukeMetadataFile)
	end

	metadata.SetActiveLayer(metadata.MapMetadataFile)

	-- Set up lanes
	local vecStart = Vector3.Create()
	local vecEnd = Vector3.Create(16000, 16000)
	
	local sNodeLaneKey = 'top' -- upvalue for funcLaneCost
	
	local function funcLaneCost(nodeParent, nodeCurrent, link, nOriginalCost)	
		local laneProperty = nodeCurrent:GetProperty('lane')
		if laneProperty and laneProperty == sNodeLaneKey then
			return nOriginalCost
		end
		
		return nOriginalCost + 9999
	end

	local tLanes = {bTop = true, bMiddle = true, bBottom = true}
	if sMapName == "midwars" then
		tLanes.bTop = false
		tLanes.bBottom = false
	elseif sMapName == "grimmscrossing" then
		tLanes.bMiddle = false
	end

	if tLanes.bTop then
		metadata.tTop = BotMetaData.FindPath(vecStart, vecEnd, funcLaneCost)
		metadata.tTop.sLaneKey = sNodeLaneKey
		metadata.tTop.sLaneName = 'lane_top'
	end
	if tLanes.bMiddle then
		sNodeLaneKey = "middle"
		metadata.tMiddle = BotMetaData.FindPath(vecStart, vecEnd, funcLaneCost)
		metadata.tMiddle.sLaneKey = sNodeLaneKey
		metadata.tMiddle.sLaneName = 'lane_mid'
	end
	if tLanes.bBottom then
		sNodeLaneKey = 'bottom'
		metadata.tBottom = BotMetaData.FindPath(vecStart, vecEnd, funcLaneCost)
		metadata.tBottom.sLaneKey = sNodeLaneKey
		metadata.tBottom.sLaneName = 'lane_bot'
	end

	--if metadata.tTop == nil or core.NumberElements(metadata.tTop) == 0 then
	--	BotEcho('Top lane not found!')
	-- end
	--if metadata.tMiddle == nil or core.NumberElements(metadata.tMiddle) == 0 then
	--	BotEcho('Middle lane not found!')
	--end
	--if metadata.tBottom == nil or core.NumberElements(metadata.tBottom) == 0 then
	--	BotEcho('Bottom lane not found!')
	--end

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
