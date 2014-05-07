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
    "eggState",
    "storageState"
  })
  self.state.leavingState = function(stateName)
    entity.setAnimationState("movement", "idle")
    entity.setRunning(false)
  end
  
  self.inv = inventoryManager.create()
  self.needForFeed = math.floor(entity.randomizeParameterRange("eggstra.needForFeed"))

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
  return nil,entity.configParameter("eggstra.cooldown", 10)
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
        local feed = self.inv.matchInContainer(stateData.targetId, {name = "animalfeed"})
        if feed == nil then feed = self.inv.matchInContainer(stateData.targetId, {name = "seed"}) end
        r = self.inv.takeFromContainer(stateData.targetId, {name = feed, count = 1})
      else
        r = world.takeItemDrop(stateData.targetId, entity.id())
      end
      if r ~= nil then
        if r.count ~= nil and r.count > 1 then
          world.spawnItem(r.name, stateData.targetPosition, r.count - 1)
        end
        if self.feedCount == nil then
          self.feedCount = entity.configParameter("feedCount", 0)
          self.startCount = self.feedCount
        end
        self.feedCount = self.feedCount + 1
        return true,entity.configParameter("eggstra.feedCooldown", 10)
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

    if n == "animalfeed" or match ~= nil then
      local oPos = world.entityPosition(oId)
	  if entity.entityInSight(oId) then
        return { targetId = oId, targetPosition = oPos }
	  end
    end
  end

  objectIds = world.objectQuery(p1, p2, { callScript = "entity.configParameter", callScriptArgs = {"category"}, callScriptResult = "storage" })
  for _,oId in ipairs(objectIds) do
    if entity.entityInSight(oId) then
      local feed = self.inv.matchInContainer(oId, {name = "animalfeed"})
      if feed == nil then feed = self.inv.matchInContainer(oId, {name = "seed"}) end
      if feed ~= nil then
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
  if self.needForFeed == nil then self.needForFeed = 10 end
  local count = self.needForFeed
  if self.feedCount ~= nil and self.feedCount >= count then
    self.feedCount = self.feedCount - count
    if self.startCount then self.startCount = 0 end
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
-------------------------------------------------
storageState = {}

function storageState.enter()
  if self.state.stateDesc() == "storageState" then return nil end
  if self.feedCount and self.feedCount - self.startCount >= 3 then
    entity.setAnimationState("movement", "invisible")
    return {}
  end
  return nil,entity.configParameter("eggstra.cooldown", 10)
end

function storageState.update()
  local animationState = entity.animationState("movement")
  if animationState == "invisible" then
    entity.setDropPool(nil)
    local parameters = {}
    parameters.persistent = true
    parameters.damageTeam = 0
    parameters.feedCount = self.feedCount
    world.spawnMonster("chicken", entity.position(), parameters)
    self.dead = true
    return true
  end

  return false
end
