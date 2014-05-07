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
    "birthState"
  })
  self.state.leavingState = function(stateName)
    entity.setAnimationState("movement", "idle")
    entity.setRunning(false)
  end

  entity.setAggressive(false)
  entity.setAnimationState("movement", "idle")
end


function main()
  self.state.update(entity.dt())
  self.sensors.clear()
  if self.hunger then
    local cost = entity.configParameter("tamedParameters.birthCost", nil)
    if cost == nil then return nil end
    if self.hunger and cost[1] and cost[1] > self.hunger then return nil end
    if self.thirst and cost[2] and cost[2] > self.thirst then return nil end
    creature.isPregnant(1)
  end
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
function hasTarget()
  return false
end