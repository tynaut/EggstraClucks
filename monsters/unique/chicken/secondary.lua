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
      timer = entity.randomizeParameterRange("eggstra.feedTime")
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
    local r = world.takeItemDrop(stateData.targetId, entity.id())
    if r ~= nil then
      if r.count ~= nil and r.count > 1 then
        world.spawnItem(r.name, stateData.targetPosition, r.count - 1)
      end
      if storage.feedCount == nil then
        storage.feedCount = 1
      else
        storage.feedCount = storage.feedCount + 1
      end
      --TODO maybe delay for a little eat time
      return true,entity.configParameter("eggstra.cooldown", 10)
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

  return nil
end
-------------------------------------------------
eggState = {}
-------------------------------------------------
function eggState.enter()
  local count = entity.randomizeParameterRange("eggstra.needForFeed")
  if storage.feedCount ~= nil and storage.feedCount >= count then
    storage.feedCount = storage.feedCount - count
    return {
      timer = entity.randomizeParameterRange("eggstra.eggTime")
    }
  end
  return nil,entity.configParameter("eggstra.cooldown", 10)
end
-------------------------------------------------
function eggState.update(dt, stateData)
  stateData.timer = stateData.timer - dt
  --TODO make chicken sit for eggs!
  entity.setAnimationState("movement", "idle")
  
  if stateData.timer < 0 then
    local egg = "egg"
    local p = entity.position()
    if math.random(1000) > 995 then egg = "goldenegg" end
    world.spawnItem(egg, {p[1], p[2] + 1}, 1)
    return true,entity.configParameter("eggstra.cooldown", 10)
  end
  
  return false
end