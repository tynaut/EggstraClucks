--------------------------------------------------------------------------------
creature = {
  starvation = false,
  oldage = false,
  realtime = true,
  pheromones = {
    resource = 0.2,
    pregnancy = 0.5,
    gender = 0.5,
    energy = 0.8
  }
}
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
      creature.main = function(args)
        creature.age({dt = entity.dt()})
      end
    end
  end
  creature.damage = function(args)
    if args.sourceKind == "livestockmilking" then
      creature.milk()
      return true
    elseif string.find(args.sourceKind, "livestockpheromone", 1, true) ~= nil then
      local str = string.sub( args.sourceKind, 19)
      creature.releasePheromone({pheromone = str})
      return true
    elseif args.sourceKind == "livestocktreat" then
      self.hunger = self.hunger + 6
      if capturepod ~= nil and not capturepod.isCaptive() then
        delegate.delayCallback("creature", "beckon", {}, 7)
        creature.beckon({sourceId = args.sourceId})
      end
      return true
    elseif args.sourceKind == "capture" then
      storage.ownerUuid = world.entityUuid(args.sourceId)
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
    params.gender = creature.gender()
    if self.hunger then params.hunger = self.hunger end
    if self.thirst then params.thirst = self.thirst end
    if self.feedCooldown then params.feedCooldown = self.feedCooldown end
    if self.pregnant then params.pregnant = self.pregnant end
    params.age = self.age
    params.type = entity.type()
    params.seed = entity.seed()
    params.level = entity.level()
    params.familyIndex = entity.familyIndex()
    return params
  end
  return nil
end
--------------------------------------------------------------------------------
function creature.basicParameters()
  if type(targetId) == "number" then
    return world.callScriptedEntity(targetId, "creature.basicParameters")
  elseif world.isMonster(entity.id()) then
    local params = {}
    params.aggressive = false
    params.persistent = true
    params.damageTeamType = "friendly"
    params.damageTeam = 0
    params.type = entity.type()
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
  local growth = false
  
  if self.tparams.stages ~= nil then
    if creature.realtime then
      local delta = os.time() - self.age.spawn
      growth = delta > self.tparams.stages[2]
    else
      growth = self.tparams.stages[1] and self.age.stage >= self.tparams.stages[1]
    end
  end
  if growth then
    local generation = entity.configParameter("generation", 2)
    if generation == 1 then
      params = creature.basicParameters()
      params.generation = 2
      if self.tparams.growthType then
        params.type = self.tparams.growthType
      end
    else
      params.age = nil
      params.generation = generation + 1
      growth = false
      if creature.oldage and self.tparams.generations and generation >= self.tparams.generations then
        return nil
      end
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
    if self.tparams == nil then self.tparams = entity.configParameter("tamedParameters", {}) end
    if self.tparams.hunger then
      if self.hunger == nil then self.hunger = entity.configParameter("hunger", 25) end
      if self.hunger > -10 then self.hunger = self.hunger - (args.dt * self.tparams.hunger) end
    end
    if self.tparams.thirst then
      if self.thirst == nil then self.thirst = entity.configParameter("thirst", 25) end
      if self.thirst > -10 then self.thirst = self.thirst - (args.dt * self.tparams.thirst) end
    end
    if (self.hunger and self.hunger < 1) or (self.thirst and self.thirst < 1) then self.feedCooldown = 0 end
    if self.feedCooldown == nil then
      self.feedCooldown = entity.configParameter("feedCooldown", 1)
    elseif self.feedCooldown > 0 then
      self.feedCooldown = self.feedCooldown - args.dt
      if self.feedCooldown <= 0 then
        if self.state then self.state.pickState({feed = true}) end
      end
    end
    if self.tparams.span then
      self.age.span = self.age.span + args.dt
      if self.age.span > self.tparams.span then
        self.age.span = self.age.span - self.tparams.span
        self.age.stage = self.age.stage + 1
        creature.respawn = true
        return creature.despawn()
      end
    end
    if not creature.realtime and self.pregnant and self.pregnant > 0 then
      self.pregnant = self.pregnant - args.dt
      if self.pregnant < 0 then self.pregnant = 0 end
    end
    
    if creature.starvation then
      if (self.hunger and self.hunger <= -10) or (self.thirst and self.thirst <= -10) then
        self.dead = true
        creature.respawn = false
      end
    end
  end
  return nil
end
--------------------------------------------------------------------------------
--TODO Beckon?
function creature.beckon(args)
  if type(args) ~= "table" then return end
  if args.targetId then
    return world.callScriptedEntity(targetId, "creature.beckon", {sourceId = args.sourceId})
  else
    if args.sourceId then
      storage.ownerUuid = world.entityUuid(args.sourceId)
    else
      storage.ownerUuid = nil
    end
    if self.state then self.state.pickState() end
    return true
    --self.tameTargetId = args.sourceId      
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
  else
    if self.gender == nil then
      if entity.configParameter("generation") == 1 then
        self.gender = -1
      else
        local rg = math.random(0, 1)
        if rg == 1 and math.random() < 0.1 then rg = 2 end
        self.gender = entity.configParameter("gender", rg)
      end
    end
    return self.gender
  end
  return nil
end
--------------------------------------------------------------------------------
function creature.releasePheromone(args)
  if args and args.targetId then
    return world.callScriptedEntity(args.targetId, "creature.releasePheromone", {pheromone = args.pheromone})
  else
    if args == nil or not args.pheromone then
      args = {}
      for t,r in pairs(creature.pheromones) do
        if math.random() < r then args.pheromone = t;break end
      end
    end
    
    if args.pheromone == "gender" then
      if creature.gender() == 0 then 
        entity.burstParticleEmitter("female")
      elseif creature.gender() > 0 then 
        entity.burstParticleEmitter("male")
      end
    elseif args.pheromone == "resource" then
      if creature.canMilk() then
        entity.burstParticleEmitter("milking")
      end
    elseif args.pheromone == "pregnancy" then
      if creature.isPregnant() then
        entity.burstParticleEmitter("pregnant")
      end
    elseif args.pheromone == "energy" then
      if self.hunger and self.hunger < 10 then
        entity.burstParticleEmitter("hunger")
      end
      if self.thirst and self.thirst < 10 then
        entity.burstParticleEmitter("thirst")
      end
    end
  end
  return nil
end
--------------------------------------------------------------------------------
function creature.canMate(args)
  if type(args) ~= "table" then return end
  if args.sourceId then
    return world.callScriptedEntity(args.sourceId, "creature.canMate", {targetId = args.targetId})
  elseif creature.isTamed() then
    if args.targetId then
      local g1 = creature.gender()
      local g2 = creature.gender(args.targetId)
      if g2 == 0 and creature.isPregnant({targetId = args.targetId}) then return false end
      if (g1 == 1 and g2 == 0) or (g1 == 2 and g2 == 2) then
        local cost = entity.configParameter("tamedParameters.matingCost", nil)
        if cost == nil then return false end
        if self.hunger and cost[1] and cost[1] > self.hunger then return false end
        if self.thirst and cost[2] and cost[2] > self.thirst then return false end
        return true
      end
      return false
    end
  end
  return nil
end
--------------------------------------------------------------------------------
function creature.mate(args)
  if type(args) ~= "table" then return end
  if args.sourceId then
    return world.callScriptedEntity(args.sourceId, "creature.mate", {targetId = args.targetId})
  else
    if args.targetId then
      local cost = entity.configParameter("tamedParameters.matingCost", nil)
      if cost[1] and self.hunger then self.hunger = self.hunger - cost[1] end
      if cost[2] and self.thirst then self.thirst = self.thirst - cost[2] end
      if creature.gender(args.targetId) == 0 then
        local pregnancy = entity.configParameter("tamedParameters.termLength", 1)
        if creature.realtime then pregnancy = os.time() end
        creature.isPregnant({targetId = args.targetId, pregnant = pregnancy})
      end
    end
  end
end
--------------------------------------------------------------------------------
function creature.isPregnant(args)
  if type(args) == "table" then
    return world.callScriptedEntity(args.targetId, "creature.isPregnant", args.pregnant)
  elseif creature.isTamed() then
    if type(args) == "number" then self.pregnant = args end
    if self.pregnant == nil then self.pregnant = entity.configParameter("pregnant", -1) end
    if type(self.pregnant) ~= "number" then self.pregnant = -1 end
    local value = self.pregnant
    if creature.realtime then
      local term = entity.configParameter("tamedParameters.termLength", 1)
      value = term - (os.time() - self.pregnant)
      if value < 0 then value = 0 end
    end
    return self.pregnant > -1,value
  end
  return nil
end

--------------------------------------------------------------------------------
function creature.birth(targetId)
  if type(targetId) == "number" then
    return world.callScriptedEntity(targetId, "creature.birth")
  else
    --TODO check pregnant
    local cost = entity.configParameter("tamedParameters.birthCost", {})--nil)
    --if cost == nil then return nil end
    --if self.hunger and cost[1] and cost[1] > self.hunger then return nil end
    --if self.thirst and cost[2] and cost[2] > self.thirst then return nil end
    if cost[1] and self.hunger then self.hunger = self.hunger - cost[1] end
    if cost[2] and self.thirst then self.thirst = self.thirst - cost[2] end
    self.pregnant = -1
    return {
      item = entity.configParameter("tamedParameters.birthItem", nil),
      count = 1
    }
  end
  return nil
end
--------------------------------------------------------------------------------
function creature.canMilk(targetId)
  if type(targetId) == "number" then
    return world.callScriptedEntity(targetId, "creature.canMilk")
  elseif creature.isTamed() then
    local g = creature.gender()
    if g == 0 and not creature.isPregnant() then
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
  elseif creature.isTamed() then
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
  elseif creature.isTamed() then
    --TODO Shearing stuff
  end
  return nil
end