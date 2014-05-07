--------------------------------------------------------------------------------
creature = {
  starvation = false,
  oldage = false,
  realtime = true,
  furTime = 720,
  maxHunger = 150,
  barTicks = 8,
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
    if self.tparams == nil then return true end
    if args.sourceKind == "livestockmilking" then
      creature.milk()
      return true
    elseif args.sourceKind == "livestockshearing" then
      creature.shear()
      return true
    elseif string.find(args.sourceKind, "livestockpheromone", 1, true) ~= nil then
      local str = string.sub( args.sourceKind, 19)
      creature.releasePheromone({pheromone = str})
      return true
    elseif args.sourceKind == "livestocktreat" then
      self.hunger = self.hunger + 6
      if capturepod ~= nil and not capturepod.isCaptive() then
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
    params.gender = creature.gender()
    if self.hunger then params.hunger = self.hunger end
    if self.thirst then params.thirst = self.thirst end
    if self.feedCooldown then params.feedCooldown = self.feedCooldown end
    if self.pregnant then params.pregnant = self.pregnant end
    if self.pSeed then params.pSeed = self.pSeed end
    if self.furGrowth then params.furGrowth = self.furGrowth end
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
  if world.isMonster(entity.id()) then
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
    creature.main = nil
    creature.damage = nil
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
    if generation == 1 or self.tparams.growthType ~= nil then
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
      self.age = entity.configParameter("age", { stage = 0, spawn = os.time() })
    end
    if args.dt == nil then args.dt = entity.dt() end
    if self.tparams == nil then self.tparams = entity.configParameter("tamedParameters", {}) end
    if self.tparams.hunger then
      local d = args.dt * self.tparams.hunger
      if self.hunger == nil then self.hunger = entity.configParameter("hunger", 25) end
      if self.state and self.state.stateDesc() == "grazeState" then d = d * -1 end
      if self.hunger > -10 then self.hunger = self.hunger - d end
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
    if self.furGrowth == nil then self.furGrowth = entity.configParameter("furGrowth", os.time()) end
    if not creature.realtime and self.pregnant and self.pregnant > 0 then
      self.pregnant = self.pregnant - args.dt
      if self.pregnant < 0 then self.pregnant = 0 end
    end

    --death by
    if creature.starvation then
      if (self.hunger and self.hunger <= -10) or (self.thirst and self.thirst <= -10) then
        self.dead = true
        creature.respawn = false
      end
    end
    --aging
    if self.tparams.span then
      if type(self.updateSpan) ~= "number" then self.updateSpan = 0 end
      self.updateSpan = self.updateSpan + args.dt
      if self.updateSpan > self.tparams.span then
        self.age.stage = self.age.stage + 1
        creature.respawn = true
        return creature.despawn()
      end
    end
  end
  return nil
end
--------------------------------------------------------------------------------
function creature.beckon(args)
  if type(args) ~= "table" then return end
  if args.targetId then
    return world.callScriptedEntity(targetId, "creature.beckon", {sourceId = args.sourceId})
  else
    if args.sourceId and self.state then
      return self.state.pickState({beckonId = args.sourceId})
    end
    return false
  end
  return nil
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
      if self.gender > 0 then
        entity.setGlobalTag("gender", 1)
      else
        entity.setGlobalTag("gender", 0)
      end
    end
    return self.gender
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
        local cost = self.tparams.matingCost
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
      local cost = self.tparams.matingCost
      if cost[1] and self.hunger then self.hunger = self.hunger - cost[1] end
      if cost[2] and self.thirst then self.thirst = self.thirst - cost[2] end
      if creature.gender(args.targetId) == 0 then
        local pregnancy = entity.configParameter("tamedParameters.termLength", 1)
        if creature.realtime then pregnancy = os.time() end
        creature.isPregnant({targetId = args.targetId, seed = entity.seed(), pregnant = pregnancy})
      end
    end
  end
end
--------------------------------------------------------------------------------
function creature.isPregnant(args)
  if type(args) == "table" and args.targetId then
    return world.callScriptedEntity(args.targetId, "creature.isPregnant", {seed = args.seed, pregnant = args.pregnant})
  elseif creature.isTamed() then
    if type(args) == "number" then
      self.pregnant = args
    elseif type(args) == "table" then
      if args.seed then self.pSeed = args.seed end
      if args.pregnant then self.pregnant = args.pregnant end
    end
    if self.pregnant == nil then self.pregnant = entity.configParameter("pregnant", -1) end
    if type(self.pregnant) ~= "number" then self.pregnant = -1 end
    local value = self.pregnant
    if creature.realtime and self.pregnant > -1 then
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
    local cost = self.tparams.birthCost
    --if cost == nil then return nil end
    --if self.hunger and cost[1] and cost[1] > self.hunger then return nil end
    --if self.thirst and cost[2] and cost[2] > self.thirst then return nil end
    if cost[1] and self.hunger then self.hunger = self.hunger - cost[1] end
    if cost[2] and self.thirst then self.thirst = self.thirst - cost[2] end
    self.pregnant = -1
    return {
      item = self.tparams.birthItem,
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
      local cost = self.tparams.milkCost
      local milk = entity.randomizeParameter("tamedMilkType")
      if cost == nil or milk == nil then return false end
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
      local cost = self.tparams.milkCost
      local milk = entity.randomizeParameter("tamedMilkType")
      if cost[1] and self.hunger then self.hunger = self.hunger - cost[1] end
      if cost[2] and self.thirst then self.thirst = self.thirst - cost[2] end
      if milk then
        world.spawnItem(milk, entity.position(), 1)
      end
      creature.respawn = true
      creature.despawn()
      return true
    end
    creature.displayStatus()
    return false
  end
  return nil
end
--------------------------------------------------------------------------------
function creature.canShear(targetId)
  if type(targetId) == "number" then
    return world.callScriptedEntity(targetId, "creature.canShear")
  elseif creature.isTamed() then
    if self.furGrowth == nil then return false end
    local count = math.floor((os.time() - self.furGrowth) / creature.furTime)
    local fibre = entity.randomizeParameter("tamedFibreType")
    if fibre and count > 0 then return true end
    return false
  end
  return nil
end
--------------------------------------------------------------------------------
function creature.shear(targetId)
  if type(targetId) == "number" then
    return world.callScriptedEntity(targetId, "creature.shear")
  elseif creature.isTamed() then
    if creature.canShear() then
      local count = math.floor((os.time() - self.furGrowth) / creature.furTime)
      local fibre = entity.randomizeParameter("tamedFibreType")
      if count > 5 then count = 5 end
      world.spawnItem(fibre, entity.position(), count)
      self.furGrowth = os.time()
      creature.respawn = true
      creature.despawn()
      return true
    else
      entity.burstParticleEmitter("fur")
      creature.displayStatus()
      return false
    end
  end
  return nil
end
--------------------------------------------------------------------------------
function creature.slaughter(args)
  if type(args) ~= "table" then return nil end
  if args.stage == "begin" then
    if args.sourceId and self.state then
      creature.displayStatus()
      return self.state.pickState({slaughterId = args.sourceId})
    end
  elseif args.stage == "release" then
    if self.state and self.state.stateDesc() == "slaughterState" then
      return self.state.endState()
    end
  elseif args.stage == "complete" then
    local generation = math.abs(self.tparams.generations / 2 - entity.configParameter("generation", 2)) * 2 / self.tparams.generations
    local hunger = self.hunger / creature.maxHunger
    local primed = (hunger + generation) / 2
    local slaughter = entity.configParameter("slaughterPool")
    if slaughter ~= nil then
      for i,v in ipairs(slaughter) do
        local odds = math.random()
        if i == 1 or odds < primed then
          if v.name and v.count then
            local count = math.floor((v.count * primed) + (1 - odds))
            if i == 1 and count < 1 then count = 1 end
            if count > 0 then world.spawnItem(v.name, entity.position(), count) end
          end
        end
      end
    end
    creature.respawn = false
    creature.despawn()
    return true
  end
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
      if creature.canShear() then
        entity.burstParticleEmitter("fur")
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
function creature.displayStatus(targetId)
  if type(targetId) == "number" then
    return world.callScriptedEntity(targetId, "creature.shear")
  elseif creature.isTamed() then
    local generation = entity.configParameter("generation", 2) / self.tparams.generations
    local hunger = self.hunger / creature.maxHunger
    local p = entity.position()
    local bounds = entity.configParameter("metaBoundBox")
    if bounds then
      p[1] = p[1] + bounds[1]/2
      p[2] = p[2] + bounds[4]/2
    end
    creature.spawnStatusBar(generation, "age", p)
    creature.spawnStatusBar(hunger, "hunger", {p[1] + 2, p[2]})
    return true
  end
  return nil
end
--------------------------------------------------------------------------------
function creature.spawnStatusBar(v, t, p)
  v = math.floor(v * creature.barTicks + 0.5)
  if v > creature.barTicks then v = creature.barTicks end
    local config = {
        movementSettings = {
          gravityMultiplier = 0.0,
          bounceFactor = 0.0,
          maxMovementPerStep = 0.0,
          maximumCorrection = 0,

          collisionPoly = { {0, 0}, {0, 0}, {0, 0}, {0, 0} },
          ignorePlatformCollision = true,

          airFriction = 0.0,
          liquidFriction = 0.0
        }
    }
    local tick = nil
    if 0 < v then
      tick = "eggstradetails" .. t .. v
    else
      tick = "eggstradetails"
    end
    if tick then
      world.spawnProjectile("eggstradetails" .. t, {p[1], p[2]}, entity.id(), {0, 0}, true, config)
      world.spawnProjectile(tick, {p[1]+0.7, p[2]}, entity.id(), {0, 0}, true, config)
    end
end