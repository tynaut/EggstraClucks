-------------------------------------------------
-- override init so we can add a new stateMachine
function init(args)
  self.dead = false
  self.sensors = sensors.create()

  self.state = stateMachine.create({
    "moveState",
    "fleeState",
    "dieState",
    "feedState",
    "eggState"
  })
  self.state.leavingState = function(stateName)
    entity.setAnimationState("movement", "idle")
    entity.setRunning(false)
  end
  
  self.inv = inventoryManager.create()

  entity.setAggressive(false)
  entity.setAnimationState("movement", "idle")
end
-------------------------------------------------
feedState = {}
-------------------------------------------------
function feedState.enter()
  local position = entity.position()
  local feed = feedState.findSeed(position)
  if feed ~= nil then
    return {
      targetId = feed.targetId,
      targetPosition = feed.targetPosition,
      timer = entity.randomizeParameterRange("eggstra.feedTime"),
      isContainer = feed.isContainer
    }
  end
  return nil,entity.configParameter("eggstra.feedCooldown", 10)
end
-------------------------------------------------
function feedState.update(dt, stateData)
  stateData.timer = stateData.timer - dt
  
  local position = entity.position()
  local toTarget = world.distance(stateData.targetPosition, position)
  local distance = world.magnitude(toTarget)
  if distance <= entity.configParameter("eggstra.feedRange") then
    entity.setAnimationState("movement", "idle")
    if stateData.timer < 0 then
      local r = nil
      if stateData.isContainer then
        local seed = self.inv.matchInContainer(stateData.targetId, {name = "seed"})
        r = self.inv.takeFromContainer(stateData.targetId, {name = seed, count = 1})
      else
        r = world.takeItemDrop(stateData.targetId, entity.id())
      end
      if r ~= nil then
        if r.count ~= nil and r.count > 1 then
          world.spawnItem(r.name, stateData.targetPosition, r.count - 1)
        end
        if storage.feedCount == nil then
          storage.feedCount = 1
        else
          storage.feedCount = storage.feedCount + 1
        end
        return true,entity.configParameter("eggstra.cooldown", 10)
      end
    end
  else
    entity.setAnimationState("movement", "move")
    move(util.toDirection(toTarget[1]))
  end

  return stateData.timer < 0
end
-------------------------------------------------
function feedState.findSeed(position)
  local range = entity.facingDirection() * entity.configParameter("eggstra.searchRange", 5.0)
  local p1 = {position[1] + range, position[2]}
  local p2 = {position[1] - range, position[2]}
  local objectIds = world.itemDropQuery(position, p1)
  for _,oId in pairs(objectIds) do
	local n = world.entityName(oId)
	local match = string.match(n, "seed")

    if match ~= nil then
      local oPos = world.entityPosition(oId)
	  if entity.entityInSight(oId) then
        return { targetId = oId, targetPosition = oPos }
	  end
    end
  end

  objectIds = world.objectQuery(p1, p2, { callScript = "entity.configParameter", callScriptArgs = {"category"}, callScriptResult = "storage" })
  for _,oId in ipairs(objectIds) do
    if entity.entityInSight(oId) then
      seed = self.inv.matchInContainer(oId, {name = "seed"})
      if seed ~= nil then
        local oPos = world.entityPosition(oId)
        return { targetId = oId, targetPosition = oPos, isContainer = true }
      end
    end
  end
  
  return nil
end
-------------------------------------------------
eggState = {}
-------------------------------------------------
function eggState.enter()
  local count = entity.randomizeParameterRange("eggstra.needForFeed")
  if storage.feedCount ~= nil and storage.feedCount >= count then
    storage.feedCount = storage.feedCount - count
    local nest = eggState.findNest(entity.position())
    return {
      targetId = nest.targetId,
      targetPosition = nest.targetPosition,
      timer = entity.randomizeParameterRange("eggstra.eggTime")
    }
  end
  return nil,entity.configParameter("eggstra.cooldown", 10)
end
-------------------------------------------------
function eggState.update(dt, stateData)
  stateData.timer = stateData.timer - dt
  
  local position = entity.position()
  local toTarget = nil
  local distance = nil
  if stateData.targetPosition then toTarget = world.distance(stateData.targetPosition, position) end
  if toTarget then distance = world.magnitude(toTarget) end
  
  if distance == nil or distance <= entity.configParameter("eggstra.feedRange") then
    --TODO make chicken sit for eggs!
    entity.setAnimationState("movement", "idle")
    if stateData.timer < 0 then
      local egg = "egg"
      if math.random(1000) > 995 then egg = "goldenegg" end
      if stateData.targetId == nil or not self.inv.putInContainer(stateData.targetId, {name = egg, count = 1}) then
        world.spawnItem(egg, position, 1)      
      end
      return true,entity.configParameter("eggstra.cooldown", 10)
    end
  else
    entity.setAnimationState("movement", "move")
    move(util.toDirection(toTarget[1]))
  end
  
  return false
end

function eggState.findNest(position)
  local range = entity.facingDirection() * entity.configParameter("eggstra.searchRange", 15.0)
  local p1 = {position[1] + range, position[2]}
  local p2 = {position[1] - range, position[2]}
  local objectIds = world.objectQuery(position, entity.configParameter("eggstra.searchRange", 15.0), { callScript = "entity.configParameter", callScriptArgs = {"objectName"}, callScriptResult = "chickennest" })
  for _,oId in ipairs(objectIds) do
    if entity.entityInSight(oId) then
        local oPos = world.entityPosition(oId)
        return { targetId = oId, targetPosition = oPos}
    end
  end
  
  return {}
end