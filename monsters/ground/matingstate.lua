matingState = {
  closeDistance = 2,
  runDistance = 12,
}

function matingState.enter()
  if hasTarget() then return nil end
  
  if creature ~= nil and creature.isTamed() and creature.gender() > 0 then
      local position = entity.position()
      local targetId = matingState.findTarget(position)
      if targetId then
        return {
          mateId = targetId,
          timer = 10
        }
      end
   end
   return nil,entity.configParameter("tamedParameters.cooldown", 10)
end

function matingState.update(dt, stateData)
  if hasTarget() then return true end
  
  stateData.timer = stateData.timer - dt
  
  if not world.entityExists(stateData.mateId) then return true end
  local matePosition = world.entityPosition(stateData.mateId)
  local toMate = world.distance(matePosition, self.position)
  local distance = math.abs(toMate[1])

  local movement
  stateData.running = false
  if distance < matingState.closeDistance then
    movement = 0
  elseif toMate[1] < 0 then
    movement = -1
  elseif toMate[1] > 0 then
    movement = 1
  end

  if distance > matingState.runDistance then
    stateData.running = true
  end

  entity.setAnimationState("attack", "idle")
  move({ movement, toMate[2] }, matingState.closeDistance)
  entity.setRunning(stateData.running)

  if movement == 0 and stateData.timer < 0 then
    if creature.canMate({targetId = stateData.mateId}) then
      entity.playSound(entity.randomizeParameter("idleNoise"))
      creature.mate({targetId = stateData.mateId})
    end
  end
  return stateData.timer < 0
end

function matingState.findTarget(position)
  local range = entity.configParameter("tamedParameters.searchRange", 5.0)
  local p1 = {position[1] - range, position[2] - 1}
  local p2 = {position[1] + range, position[2] + 1}
  local objectIds = nil
  if entity.type() == "eggstrabovine" then
    objectIds = world.monsterQuery(position, range, { callScript = "entity.type", callScriptResult = entity.type(), withoutEntityId = entity.id() })
  else
    objectIds = world.monsterQuery(position, range, { callScript = "entity.seed", callScriptResult = entity.seed(), withoutEntityId = entity.id() })
  end
  for _,oId in pairs(objectIds) do
    if creature.canMate({targetId = oId}) then
      return oId
    end
  end
  return nil
end