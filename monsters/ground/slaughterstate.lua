slaughterState = {
  offset = {0, 1.5},
  flySpeed = 2,
  delay = 2,
  range = 1.5
}

function slaughterState.enterWith(params)
  if creature ~= nil and creature.isTamed() and params.slaughterId then
    return {
      slaughterId = params.slaughterId,
      running = false,
      timer = slaughterState.delay
    }
  end

  return nil
end

function slaughterState.update(dt, stateData)

  stateData.timer = stateData.timer - dt
  
  -- target is nowhere around
  if not world.entityExists(stateData.slaughterId) then
    return true
  end

  if stateData.timer < 0 then
    local targetPosition = vec2.add(world.entityPosition(stateData.slaughterId), slaughterState.offset)
    local toTarget = world.distance(targetPosition, self.position)
    local distance = world.magnitude(toTarget)
    
    if distance < slaughterState.range then
      movement = 0
      world.callScriptedEntity(stateData.slaughterId, "completeSlaughter")
    elseif toTarget[1] < 0 then
      movement = -1
    elseif toTarget[1] > 0 then
      movement = 1
    end

    entity.setAnimationState("attack", "idle")
    move({ movement, toTarget[2] })
  end
  return false--stateData.timer < 0
end

function slaughterState.preventStateChange(stateData)
  return true
end

function slaughterState.enteringState(stateData)
  --entity.setAnimationState("movement", "jump")
    entity.setAnimationState("movement", "idle")
  --entity.setGravityEnabled(false)
  entity.setParticleEmitterActive("slaughter", true)
end

function slaughterState.leavingState(stateData)
  --entity.setGravityEnabled(true)
  --entity.setAnimationState("movement", "idle")
  entity.setParticleEmitterActive("slaughter", false)
end
