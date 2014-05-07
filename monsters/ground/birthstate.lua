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
      local birth = creature.birth()
      if birth.name then
        if math.random() > 0.995 then
          local mutator = entity.configParameter("tamedParameters.mutator", "")
          birth.name = mutator .. birth.name
        end
        local item = creature.deposit(stateData.targetId, birth)
        if item ~= nil then
          world.spawnItem(item.name, position, item.count)
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
      return true,entity.configParameter("tamedParameters.cooldown", 10)
    end
  else
    entity.setAnimationState("movement", "walk")
    move({util.toDirection(toTarget[1]), toTarget[2]})
  end
  
  return false
end
-------------------------------------------------
function birthState.findNest(position)
  local targetPosition = position
  local targetId = nil
  local timer = 1
  if entity.configParameter("tamedParameters.birthItem") then
    local range = entity.configParameter("tamedParameters.searchRange", 15.0)
    local p1 = {position[1] - range, position[2]}
    local p2 = {position[1] + range, position[2]}
    targetId = birthState.getContainer(p1, p2, "chickennest")
    if targetId == nil then
      targetId = birthState.getContainer(p1, p2)
    end
    if targetId ~= nil then
      targetPosition = world.entityPosition(targetId)
    end
    timer = entity.randomizeParameterRange("tamedParameters.birthTime", {10, 10})
  end
  
  return {
    targetPosition = targetPosition,
    targetId = targetId,
    timer = timer
  }
end
-------------------------------------------------
function birthState.getContainer(p1, p2, name)
  local args = {"category"}
  local result = "storage"
  if name ~= nil then
    args = {"objectName"}
    result = "chickennest"
  end
  local objectIds = world.objectLineQuery(p1, p2, { callScript = "entity.configParameter", callScriptArgs = args, callScriptResult = result})
  for _,oId in ipairs(objectIds) do
    if entity.entityInSight(oId) then
      return oId
    end
  end
end