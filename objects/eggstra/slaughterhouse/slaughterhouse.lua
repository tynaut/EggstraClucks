slaughter = {
  offset = {0, 1.5},
  range = 20,
  resetTime = 4
}
--------------------------------------------------------------------------------
function init(virtual)
  if not virtual then
    entity.setInteractive(true)
    entity.setParticleEmitterActive("doors", false)
    self.position = vec2.add(entity.position(), slaughter.offset)
  end
end
--------------------------------------------------------------------------------
function main()
  if self.resetTimer then
    if self.resetTimer > 0 then
      self.resetTimer = self.resetTimer - entity.dt()
    else
      self.resetTimer = nil
      self.slaughterIds = nil
    end
  end
  --[[if self.slaughterTarget then
    local targetPosition = world.entityPosition(self.slaughterTarget)
    if targetPosition == nil then
      self.slaughterTarget = nil
      return
    end
    local toTarget = world.distance(targetPosition, self.position)
    if math.abs(toTarget[1]) < 0.5 then
      completeSlaughter()
    end
    --entity.scaleGroup("arm", {toTarget[1] * 8 * entity.direction(), 1})
  end]]--
end
--------------------------------------------------------------------------------
function onInteraction(args)
  self.resetTimer = slaughter.resetTime
  if self.slaughterTarget then
    cancelSlaughter()
  else
    prepSlaughter()
  end
end
--------------------------------------------------------------------------------
function prepSlaughter()
    if self.slaughterIds == nil or next(self.slaughterIds) == nil then getSlaughterTable() end
    local i = getSlaughterIndex()
    if i then
      self.slaughterTarget = self.slaughterIds[i]
      world.callScriptedEntity(self.slaughterTarget, "creature.slaughter", {stage = "begin", sourceId = entity.id()})
      entity.setParticleEmitterActive("doors", true)
    end
end
--------------------------------------------------------------------------------
function completeSlaughter()
    world.callScriptedEntity(self.slaughterTarget, "creature.slaughter", {stage = "complete"})
    self.slaughterTarget = nil
    entity.setParticleEmitterActive("doors", false)
end
--------------------------------------------------------------------------------
function cancelSlaughter()
  if self.slaughterTarget then
    world.callScriptedEntity(self.slaughterTarget, "creature.slaughter", {stage = "release"})
    self.slaughterTarget = nil
    entity.setParticleEmitterActive("doors", false)
  end
end
--------------------------------------------------------------------------------
function getSlaughterTable()
  self.slaughterIds = world.monsterQuery(self.position, slaughter.range, { callScript = "creature.isTamed", order = "nearest" }) 
  self.slaughterIndex = 1
end
--------------------------------------------------------------------------------
function getSlaughterIndex()
  if self.slaughterIndex > #self.slaughterIds then self.slaughterIndex = 1 end
  if self.slaughterIds[self.slaughterIndex] == nil then return nil end
  local nextIndex = self.slaughterIndex + 1
  if nextIndex > #self.slaughterIds then nextIndex = 1 end
  
  local targetPosition = world.entityPosition(self.slaughterIds[self.slaughterIndex])
  if targetPosition then
    local toTarget = world.distance(targetPosition, self.position)
    local distance = world.magnitude(toTarget)
    if distance < slaughter.range then
      local i = self.slaughterIndex
      self.slaughterIndex = nextIndex
      return i
    end
  end
  table.remove(self.slaughterIds, self.slaughterIndex)
  return getSlaughterIndex()
end