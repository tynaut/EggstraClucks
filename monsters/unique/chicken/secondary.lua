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
function move(direction)
  if type(direction) == "table" then direction = direction[1] end
  entity.setFacingDirection(direction)
  if direction < 0 then
    entity.moveLeft()
  else
    entity.moveRight()
  end
end
-------------------------------------------------
function cageCreature(destroy)
  if destroy then
    return creature.despawn()
  end
  return true
end
-------------------------------------------------
eggState = {}
-------------------------------------------------
function eggState.enter()
  local birth = creature.birth()
  if birth then
    local nest = eggState.findNest(entity.position())
    return {
      targetId = nest.targetId,
      targetPosition = nest.targetPosition,
      timer = entity.randomizeParameterRange("tamedParameters.birthTime")
    }
  end
  return nil,entity.configParameter("tamedParameters.cooldown", 10)
end
-------------------------------------------------
function eggState.update(dt, stateData)
  stateData.timer = stateData.timer - dt
  
  local position = entity.position()
  local toTarget = world.distance(stateData.targetPosition, position)
  local distance = world.magnitude(toTarget)
  
  if distance <= entity.configParameter("tamedParameters.feedRange") then
    --TODO make chicken sit for eggs!
    entity.setAnimationState("movement", "idle")
    if stateData.timer < 0 then
      local egg = "egg"
      if math.random(1000) > 995 then egg = "goldenegg" end
      if stateData.targetId == nil or not self.inv.putInContainer(stateData.targetId, {name = egg, count = 1}) then
        world.spawnItem(egg, position, 1)      
      end
      return true,entity.configParameter("tamedParameters.cooldown", 10)
    end
  else
    entity.setAnimationState("movement", "move")
    move(util.toDirection(toTarget[1]))
  end
  
  return false
end

function eggState.findNest(position)
  local range = entity.facingDirection() * entity.configParameter("tamedParameters.searchRange", 15.0)
  local p1 = {position[1] + range, position[2]}
  local p2 = {position[1] - range, position[2]}
  local objectIds = world.objectQuery(position, entity.configParameter("tamedParameters.searchRange", 15.0), { callScript = "entity.configParameter", callScriptArgs = {"objectName"}, callScriptResult = "chickennest" })
  for _,oId in ipairs(objectIds) do
    if entity.entityInSight(oId) then
        local oPos = world.entityPosition(oId)
        return { targetId = oId, targetPosition = oPos}
    end
  end
  
  return {targetPosition = position}
end