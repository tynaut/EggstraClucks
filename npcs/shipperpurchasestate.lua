shipperpurchaseState = {
  cooldown = 10,
  interactRange = 3,
  searchRange = 20,
  offset = {0, 2}
}

function shipperpurchaseState.enter()
  local position = entity.position()
  local target = shipperpurchaseState.findTargetPosition(position)
    if target ~= nil then
      return {
        targetPosition = target.position,
        targetId = target.id,
        timer = shipperpurchaseState.cooldown
      }
    end

  return nil
end

function shipperpurchaseState.update(dt, stateData)
  stateData.timer = stateData.timer - dt

  local position = entity.position()
  local toTarget = world.distance(stateData.targetPosition, position)
  local distance = world.magnitude(toTarget)
  if distance < shipperpurchaseState.interactRange then
    world.callScriptedEntity(stateData.targetId, "dropbox.sellItems")
    
    return true
  else
    move(toTarget, dt)
  end

  return stateData.timer < 0
end

function shipperpurchaseState.findTargetPosition(position)
  local direction = entity.facingDirection()

  local objectIds = world.objectQuery(position, shipperpurchaseState.searchRange, { callScript = "canPurchase", order = "nearest" })
  if #objectIds > 0 then
    return {
      position = vec2.add(world.entityPosition(objectIds[1]), shipperpurchaseState.offset),
      id = objectIds[1]
    }
  end

  return nil
end

