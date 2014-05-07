tameState = {}

function tameState.enter()
  if not isTamed() or hasTarget() then return nil end
  local targetPosition = world.entityPosition(self.tameTargetId)
  return {
    targetPosition = targetPosition
  }
end

function tameState.update(dt, stateData)
  if hasTarget() then return true end
  
  local toTarget = world.distance(stateData.targetPosition, self.position)
  local distance = world.magnitude(toTarget)

  local movement
  if distance < captiveState.closeDistance then
    stateData.running = false
    movement = 0
  else
    movement = util.toDirection(toTarget[1])
  end

  if distance > captiveState.runDistance then
    stateData.running = true
  end

  entity.setAnimationState("attack", "idle")
  move({ movement, toOwner[2] }, captiveState.closeDistance)
  entity.setRunning(stateData.running)

  return false
end