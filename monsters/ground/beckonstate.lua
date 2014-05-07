beckonState = {
  closeDistance = 4,
  runDistance = 12,
  teleportDistance = 50,
}

function beckonState.enterWith(params)
  if creature ~= nil and creature.isTamed() and params.beckonId then
    return {
      beckonId = params.beckonId,
      running = false,
      timer = 6
    }
  end

  return nil
end

function beckonState.update(dt, stateData)
  if hasTarget() then return true end

  stateData.timer = stateData.timer - dt
  
  -- Owner is nowhere around
  if not world.entityExists(stateData.beckonId) then
    return true
  end

  local targetPosition = world.entityPosition(stateData.beckonId)
  local toTarget = world.distance(targetPosition, self.position)
  local distance = math.abs(toTarget[1])

  local movement
  if distance > beckonState.teleportDistance then
    movement = 0
    entity.setPosition(ownerPosition)
  elseif distance < beckonState.closeDistance then
    stateData.running = false
    movement = 0
  elseif toTarget[1] < 0 then
    movement = -1
  elseif toTarget[1] > 0 then
    movement = 1
  end

  if distance > beckonState.runDistance then
    stateData.running = true
  end

  entity.setAnimationState("attack", "idle")
  move({ movement, toTarget[2] }, beckonState.closeDistance)
  entity.setRunning(stateData.running)

  return stateData.timer < 0
end
