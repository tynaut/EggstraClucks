--------------------------------------------------------------------------------
creature = {}
--------------------------------------------------------------------------------
if delegate ~= nil then
  delegate.create("creature")
  creature.init = function()  
    if inventoryManager and self.inv == nil then
      self.inv = inventoryManager.create()     
    end
  end
  
  creature.main = function(args)
    if entity.id() then
      if not creature.isTamed() then
        creature.main = nil
        creature.die = nil
        creature.damage = nil
        return
      end
      creature.age({dt = entity.dt()})
    end
  end
  creature.damage = function(args)
    if args.sourceKind == "livestockmilking" then
      return creature.milk()
    elseif args.sourceKind == "livestockpheromone" then
      return creature.releasePheromone()
    end
  end
  creature.die = function()
    if creature.respawn then
      entity.setDeathParticleBurst(nil)
      creature.spawn()
    end
  end
end
--------------------------------------------------------------------------------
function creature.uniqueParameters()
  if type(targetId) == "number" then
    return world.callScriptedEntity(targetId, "creature.uniqueParameters")
  elseif world.isMonster(entity.id()) then
    local params = entity.uniqueParameters()
    --TODO Add gender, hunger, thirst, age {span, stage}, fur level
    params.type = entity.type()
    params.gender = creature.gender()
    if self.hunger then params.hunger = self.hunger end
    if self.thirst then params.thirst = self.thirst end
    if self.feedCooldown then params.feedCooldown = self.feedCooldown end
    params.age = self.age
    params.seed = entity.seed()
    params.level = entity.level()
    params.familyIndex = entity.familyIndex()
    return params
  end
  return nil
end
--------------------------------------------------------------------------------
function creature.despawn(targetId)
  if type(targetId) == "number" then
    return world.callScriptedEntity(targetId, "creature.despawn")
  elseif world.isMonster(entity.id()) then
    local params = creature.uniqueParameters()
    entity.setDropPool(nil)
    self.dead = true
    return params
  end
  return nil
end
--------------------------------------------------------------------------------
function creature.spawn()
  if not world.isMonster(entity.id()) then return nil end
  local params = creature.uniqueParameters()
  local tamed = entity.configParameter("tamedParameters", {})
  local growth = false
  if tamed.stages and self.age.stage >= tamed.stages then
    if tamed.growthType then
      params.type = tamed.growthType
      params.age.spawn = os.time()
      growth = true
    else
      return nil
    end
  end
  local id = world.spawnMonster(params.type, entity.position(), params)
  return id,growth
end
--------------------------------------------------------------------------------
function creature.age(args)
  if type(args) ~= "table" then return nil end
  if args.targetId then
    return world.callScriptedEntity(targetId, "creature.age", args.dt)
  else
    if self.age == nil then
      self.age = entity.configParameter("age", { span = 0, stage = 0, spawn = os.time() })
    end
    if args.dt == nil then args.dt = entity.dt() end
    local tparams = entity.configParameter("tamedParameters", {})
    if tparams.hunger then
      if self.hunger == nil then self.hunger = entity.configParameter("hunger", 50) end
      if self.hunger > 0 then self.hunger = self.hunger - (args.dt * tparams.hunger) end
    end
    if self.feedCooldown and self.feedCooldown > 0 then
      self.feedCooldown = self.feedCooldown - args.dt
    end
    if tparams.thirst then
      if self.thirst == nil then self.thirst = entity.configParameter("thirst", 50) end
      if self.thirst > 0 then self.thirst = self.thirst - (args.dt * tparams.thirst) end
    end
    if tparams.span then
      self.age.span = self.age.span + args.dt
      if self.age.span > tparams.span then
        self.age.span = self.age.span - tparams.span
        self.age.stage = self.age.stage + 1
        creature.respawn = true
        return creature.despawn()
      end
    end
  end
  return nil
end
--------------------------------------------------------------------------------
--TODO Beckon?
function creature.tame(args)
  if type(args) ~= "table" then return end
  if args.targetId then
    return world.callScriptedEntity(targetId, "creature.tame", {sourceId = args.sourceId})
  elseif world.isMonster(entity.id()) and isTamed() then
    self.tameTargetId = args.sourceId      
  end
end
--------------------------------------------------------------------------------
function creature.isTamed(targetId)
  if type(targetId) == "number" then
    return world.callScriptedEntity(targetId, "creature.isTamed")
  elseif world.isMonster(entity.id()) then
    --Some "wild" tamed creatures should be included
    if entity.type() == "chicken" then return true end
    local teamType = entity.configParameter("damageTeamType", nil)
    return teamType == "friendly" and capturepod ~= nil and not capturepod.isCaptive()
  end
  return nil
end
--------------------------------------------------------------------------------
function creature.gender(targetId)
  if type(targetId) == "number" then
    return world.callScriptedEntity(targetId, "creature.gender")
  elseif world.isMonster(entity.id()) then
    if self.gender == nil then
      local rg = math.random(0, 1)
      self.gender = entity.configParameter("gender", rg)
    end
    return self.gender
  end
  return nil
end
--------------------------------------------------------------------------------
function creature.releasePheromone(targetId)
  if type(targetId) == "number" then
    return world.callScriptedEntity(targetId, "creature.releasePheromone")
  elseif world.isMonster(entity.id()) then
      if creature.gender() == 0 then 
        entity.burstParticleEmitter("female")
      end
      if creature.canMilk() then
        entity.burstParticleEmitter("milking")
      end
  end
  return nil
end
--------------------------------------------------------------------------------
function creature.mate(args)
  if type(args) ~= "table" then return end
  if args.targetId then
    return world.callScriptedEntity(args.targetId, "creature.mate", {sourceId = args.sourceId})
  elseif world.isMonster(entity.id()) and creature.isTamed() then
    if args.sourceId and creature.isTamed(args.sourceId) then
      local g1 = creature.gender()
      local g2 = creature.gender(args.sourceId)
      if g1 ~= nil and g2 ~= nil and g1 ~= g2 then
        --TODO Check if pregnant
        --TODO Some mating stuff, match seed
        --TODO Reduce hunger/thirst
      end
    end
  end
end
--------------------------------------------------------------------------------
function creature.birth(targetId)
  if type(targetId) == "number" then
    return world.callScriptedEntity(targetId, "creature.birth")
  elseif world.isMonster(entity.id()) then
    --TODO check pregnant
    local cost = entity.configParameter("tamedParameters.birthCost", nil)
    if cost == nil then return nil end
    if self.hunger and cost[1] and cost[1] > self.hunger then return nil end
    if self.thirst and cost[2] and cost[2] > self.thirst then return nil end
    if cost[1] and self.hunger then self.hunger = self.hunger - cost[1] end
    if cost[2] and self.thirst then self.thirst = self.thirst - cost[2] end
    return {
      kind = entity.configParameter("tamedParameters.birthKind", nil),
      name = entity.configParameter("tamedParameters.birthName", nil),
      count = 1
    }
  end
  return nil
end
--------------------------------------------------------------------------------
function creature.canMilk(targetId)
  if type(targetId) == "number" then
    return world.callScriptedEntity(targetId, "creature.milk")
  elseif world.isMonster(entity.id()) and creature.isTamed() then
    local g = creature.gender()
    if g == 0 then
      local cost = entity.configParameter("tamedParameters.milkCost", nil)
      if cost == nil then return false end
      if self.hunger and cost[1] and cost[1] > self.hunger then return false end
      if self.thirst and cost[2] and cost[2] > self.thirst then return false end
      return true
    end
    return false
  end
  return nil
end
--------------------------------------------------------------------------------
function creature.milk(targetId)
  if type(targetId) == "number" then
    return world.callScriptedEntity(targetId, "creature.milk")
  elseif world.isMonster(entity.id()) and creature.isTamed() then
    if creature.canMilk() then
      local cost = entity.configParameter("tamedParameters.milkCost", nil)
      if cost[1] and self.hunger then self.hunger = self.hunger - cost[1] end
      if cost[2] and self.thirst then self.thirst = self.thirst - cost[2] end
      world.spawnItem("milk", entity.position(), 1)
      return true
    end
    return false
  end
  return nil
end
--------------------------------------------------------------------------------
function creature.shear(targetId)
  if type(targetId) == "number" then
    return world.callScriptedEntity(targetId, "creature.shear")
  elseif world.isMonster(entity.id()) and creature.isTamed() then
    --TODO Shearing stuff
  end
  return nil
end