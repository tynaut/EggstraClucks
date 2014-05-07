-------------------------------------------------
birthState = {
  scale = 0.7
}
-------------------------------------------------
function birthState.enter()
  if hasTarget() then return nil end
  if self.state.stateDesc() == "birthState" then return nil end
  
  if creature ~= nil then
    local isPregnant,t = creature.isPregnant()
    if isPregnant and t == 0 then
      return birthState.findNest(entity.position())
    end
  end
  return nil,entity.configParameter("tamedParameters.cooldown", 10)
end
-------------------------------------------------
function birthState.update(dt, stateData)
  stateData.timer = stateData.timer - dt
  
  local position = entity.position()
  local toTarget = world.distance(stateData.targetPosition, position)
  local distance = world.magnitude(toTarget)
  
  if distance <= entity.configParameter("tamedParameters.feedRange") then
    --TODO make chicken sit for eggs!
    entity.setAnimationState("movement", "idle")
    if stateData.timer < 0 then
      if stateData.birthItem then
        if math.random() > 0.995 then
          local mutator = entity.configParameter("tamedParameters.mutator", "")
          stateData.birthItem = mutator .. stateData.birthItem
        end
        local item = stateData.birthItem
        local count = stateData.count
        if stateData.targetId == nil or not self.inv.putInContainer(stateData.targetId, {name = item, count = count}) then
          world.spawnItem(item, position, count)      
        end
      else
        local bnds = entity.configParameter("movementSettings")
        local params = creature.basicParameters()
        if bnds.collisionPoly then
          for i,pnt in ipairs(bnds.collisionPoly) do
            for j,v in ipairs(pnt) do
              bnds.collisionPoly[i][j] = v * birthState.scale
            end
          end
          params.movementSettings = bnds
          params.scale = birthState.scale
          params.generation = 1
          if entity.type() == "eggstrabovine" then
            if math.random() < 0.5 and self.pSeed then params.seed = self.pSeed end
            if math.random() < 0.05 then params.seed = nil end
          end
        end
        world.spawnMonster(params.type, entity.position(), params)
      end
      creature.respawn = true
      creature.despawn()
      return true,entity.configParameter("tamedParameters.cooldown", 10)
    end
  else
    entity.setAnimationState("movement", "walk")
    move({util.toDirection(toTarget[1]), toTarget[2]})
  end
  
  return false
end

function birthState.findNest(position)
  local birth = creature.birth()
  local targetPosition = position
  local targetId = nil
  local timer = 1
  if birth.item then
    local range = entity.configParameter("tamedParameters.searchRange", 15.0)
    local p1 = {position[1] + range, position[2]}
    local p2 = {position[1] - range, position[2]}
    --TODO just look for a container that can add to
    local objectIds = world.objectQuery(position, range, { callScript = "entity.configParameter", callScriptArgs = {"objectName"}, callScriptResult = "chickennest" })
    for _,oId in ipairs(objectIds) do
      if entity.entityInSight(oId) then
        targetId = oId
        targetPosition = world.entityPosition(oId)
        break
      end
    end
    timer = entity.randomizeParameterRange("tamedParameters.birthTime", {10, 10})
  end
  
  return {
    targetPosition = targetPosition,
    targetId = targetId,
    birthItem = birth.item,
    count = birth.count,
    timer = timer
  }
end