-------------------------------------------------
feedState = {}
-------------------------------------------------
function feedState.enter()
  if creature ~= nil and creature.isTamed() then
    if self.feedCooldown == nil then
      self.feedCooldown = entity.configParameter("tamedParameters.feedCooldown", 0)
    end
    if self.feedCooldown > 0 then return nil end
    local position = entity.position()
    local feed = feedState.findSeed(position)
    if feed ~= nil then
      return {
        targetId = feed.targetId,
        targetPosition = feed.targetPosition,
        timer = entity.randomizeParameterRange("tamedParameters.feedTime"),
        isContainer = feed.isContainer
      }
    end
  end
  return nil,entity.configParameter("tamedParameters.cooldown", 10)
end
-------------------------------------------------
function feedState.update(dt, stateData)
  stateData.timer = stateData.timer - dt
  
  local position = entity.position()
  local toTarget = world.distance(stateData.targetPosition, position)
  local distance = world.magnitude(toTarget)
  if distance <= entity.configParameter("tamedParameters.feedRange", 2) then
    entity.setAnimationState("movement", "idle")
    if stateData.timer < 0 then
      local r = nil
      if stateData.isContainer then
        local feedType = entity.configParameter("tamedParameters.feed", "animalfeed")
        local feed = self.inv.matchInContainer(stateData.targetId, {name = feedType})
        r = self.inv.takeFromContainer(stateData.targetId, {name = feed.name, count = 1})
      else
        r = world.takeItemDrop(stateData.targetId, entity.id())
      end
      if r ~= nil then
        if r.count ~= nil and r.count > 1 then
          world.spawnItem(r.name, stateData.targetPosition, r.count - 1)
        end
        self.hunger = self.hunger + 18
        self.feedCooldown = entity.configParameter("tamedParameters.feedCooldown", 10)
        return true,entity.configParameter("tamedParameters.cooldown", 10)
      end
    end
  else
    entity.setAnimationState("movement", "run")
    move({util.toDirection(toTarget[1]), toTarget[2]})
  end

  return stateData.timer < 0
end
-------------------------------------------------
function feedState.findSeed(position)
  local range = entity.configParameter("tamedParameters.searchRange", 5.0)
  local p1 = {position[1] - range, position[2] - 1}
  local p2 = {position[1] + range, position[2] + 1}
  local objectIds = world.itemDropQuery(p1, p2)
  for _,oId in pairs(objectIds) do
	local n = world.entityName(oId)
    local feedType = entity.configParameter("tamedParameters.feed", "animalfeed")
    if type(feedType) ~= "table" then feedType = {feedType} end
    for i,v in ipairs(feedType) do
	  local match = string.find(n, v)
      if match ~= nil then
        local oPos = world.entityPosition(oId)
	    if entity.entityInSight(oId) then
          return { targetId = oId, targetPosition = oPos }
        end
	  end
    end
  end

  objectIds = world.objectQuery(p1, p2, { callScript = "entity.configParameter", callScriptArgs = {"category"}, callScriptResult = "storage" })

  for _,oId in ipairs(objectIds) do
    if entity.entityInSight(oId) then
      local feedType = entity.configParameter("tamedParameters.feed", "animalfeed")
      local feed = self.inv.matchInContainer(oId, {name = feedType})
      if feed ~= nil then
        local oPos = world.entityPosition(oId)
        return { targetId = oId, targetPosition = oPos, isContainer = true }
      end
    end
  end
  
  return nil
end