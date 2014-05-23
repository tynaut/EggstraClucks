--------------------------------------------------------------------------------
creature = {
  starvation = false,
  oldage = true,
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

  end
  
  creature.main = function(args)
    if entity.id() then
      if not creature.isTamed() then
        creature.main = nil
        creature.die = nil
        creature.damage = nil
        creature = nil
        return
      end
      creature.main = function(args)
        if storage.spawnPoint == nil then
          storage.spawnPoint = entity.configParameter("spawnPoint", entity.position())
        end
        creature.age(entity.dt())
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
        creature.beckon(args.sourceId)
      end
      return true
    elseif args.sourceKind == "capture" then
      storage.ownerUuid = world.entityUuid(args.sourceId)
    end
  end
  
  creature.die = function()
    if creature.respawn then
      local id,growth = creature.spawn()
      if id ~= nil then
        entity.setDeathParticleBurst(nil)
      end
    end
  end
end
--------------------------------------------------------------------------------
function creature.isTamed(targetId)
  if world.isMonster(entity.id()) then
    --Some "wild" tamed creatures should be included
    if entity.type() == "chicken" then return true end
    local teamType = entity.configParameter("damageTeamType", nil)
    return teamType == "friendly" and capturepod ~= nil and not capturepod.isCaptive()
  end
  return nil
end
--------------------------------------------------------------------------------
function creature.uniqueParameters()
  if world.isMonster(entity.id()) then
    local params = entity.uniqueParameters()
    params.gender = creature.gender()
    if self.hunger then params.hunger = self.hunger end
    if self.thirst then params.thirst = self.thirst end
    if self.feedCooldown then params.feedCooldown = self.feedCooldown end
    if self.pregnant then params.pregnant = self.pregnant end
    if self.pSeed then params.pSeed = self.pSeed end
    if self.furGrowth then params.furGrowth = self.furGrowth end
    if storage.spawnPoint then params.spawnPoint = storage.spawnPoint end
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
function creature.despawn(respawn)
  creature.respawn = respawn
  creature.main = nil
  creature.damage = nil
  entity.setDropPool(nil)
  self.dead = true
  return creature.uniqueParameters()
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
function creature.age(dt)
  if type(dt) ~= number then dt = entity.dt() end
  if self.age == nil then
    self.age = entity.configParameter("age", { stage = 0, spawn = os.time() })
  end
  if self.tparams == nil then self.tparams = entity.configParameter("tamedParameters", {}) end
  if self.tparams.hunger then
    local d = dt * self.tparams.hunger
    if self.hunger == nil then self.hunger = entity.configParameter("hunger", 25) end
    if self.state and self.state.stateDesc() == "grazeState" then d = d * -1 end
    if self.hunger > -10 then self.hunger = self.hunger - d end
  end
  if self.tparams.thirst then
    if self.thirst == nil then self.thirst = entity.configParameter("thirst", 25) end
    if self.thirst > -10 then self.thirst = self.thirst - (dt * self.tparams.thirst) end
  end
  --if (self.hunger and self.hunger < 1) or (self.thirst and self.thirst < 1) then self.feedCooldown = 0 end
  --if self.feedCooldown == nil then
  --  self.feedCooldown = entity.configParameter("feedCooldown", 1)
  --elseif self.feedCooldown > 0 then
  --  self.feedCooldown = self.feedCooldown - dt
  --  if self.feedCooldown <= 0 then
  --    if self.state then self.state.pickState({feed = true}) end
  --  end
  --end
  if self.feedCooldown == nil then self.feedCooldown = entity.configParameter("feedCooldown", os.time()) end
  if self.furGrowth == nil then self.furGrowth = entity.configParameter("furGrowth", os.time()) end
  
  if not creature.realtime and self.pregnant and self.pregnant > 0 then
    self.pregnant = self.pregnant - dt
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
    self.updateSpan = self.updateSpan + dt
    if self.updateSpan > self.tparams.span then
      self.age.stage = self.age.stage + 1
      return creature.despawn(true)
    end
  end
end
--------------------------------------------------------------------------------
function creature.beckon(sourceId)
  if type(sourceId) == "number" and self.state then
    return self.state.pickState({beckonId = sourceId})
  end
  return false
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
function creature.canMate(targetId)
  if type(targetId) == "number" then
    local g1 = creature.gender()
    local g2 = creature.gender(targetId)
    if g2 == 0 and creature.isPregnant({targetId = targetId}) then return false end
    if (g1 == 1 and g2 == 0) or (g1 == 2 and g2 == 2) then
      local cost = self.tparams.matingCost
      if cost == nil then return false end
      if self.hunger and cost[1] and cost[1] > self.hunger then return false end
      if self.thirst and cost[2] and cost[2] > self.thirst then return false end
      return true
    end
  end
  return false
end
--------------------------------------------------------------------------------
function creature.mate(targetId)
  if type(targetId) == "number" then
    local cost = self.tparams.matingCost
    if cost[1] and self.hunger then self.hunger = self.hunger - cost[1] end
    if cost[2] and self.thirst then self.thirst = self.thirst - cost[2] end
    if creature.gender(targetId) == 0 then
      local pregnancy = entity.configParameter("tamedParameters.termLength", 1)
      if creature.realtime then pregnancy = os.time() end
      creature.isPregnant({targetId = targetId, seed = entity.seed(), pregnant = pregnancy})
    end
    return true
  end
  return false
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
  if self.pregnant == -1 then return end
  
  local cost = self.tparams.birthCost
  if cost[1] and self.hunger then self.hunger = self.hunger - cost[1] end
  if cost[2] and self.thirst then self.thirst = self.thirst - cost[2] end
  self.pregnant = -1
  
  --TODO death during birth
  creature.despawn(true)
  return {
    name = self.tparams.birthItem,
    count = 1
  }
end
--------------------------------------------------------------------------------
function creature.canMilk()
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
--------------------------------------------------------------------------------
function creature.milk(targetId)
  if creature.canMilk() then
    local cost = self.tparams.milkCost
    local milk = entity.randomizeParameter("tamedMilkType")
    if cost[1] and self.hunger then self.hunger = self.hunger - cost[1] end
    if cost[2] and self.thirst then self.thirst = self.thirst - cost[2] end
    if milk then
      world.spawnItem(milk, entity.position(), 1)
    end
    creature.despawn(true)
    return true
  end
  creature.displayStatus()
  return false
end
--------------------------------------------------------------------------------
function creature.canShear(targetId)
  if self.furGrowth == nil then return false end
  local count = math.floor((os.time() - self.furGrowth) / creature.furTime)
  local fibre = entity.randomizeParameter("tamedFibreType")
  if fibre and count > 0 then return true end
  return false
end
--------------------------------------------------------------------------------
function creature.shear(targetId)
  if creature.canShear() then
    local count = math.floor((os.time() - self.furGrowth) / creature.furTime)
    local fibre = entity.randomizeParameter("tamedFibreType")
    if count > 5 then count = 5 end
    world.spawnItem(fibre, entity.position(), count)
    self.furGrowth = os.time()
    creature.despawn(true)
    return true
  end
  entity.burstParticleEmitter("fur")
  creature.displayStatus()
  return false
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
    local generation = 1
    if self.tparams.generations then 
      generation = math.abs(self.tparams.generations / 2 - entity.configParameter("generation", 2)) * 2 / self.tparams.generations
    end
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
    creature.despawn()
    return true
  end
  return false
end
--------------------------------------------------------------------------------
function creature.releasePheromone(args)
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
--------------------------------------------------------------------------------
function creature.displayStatus(targetId)
  if self.tparams == nil or self.tparams.generations == nil then return nil end
  local generation = entity.configParameter("generation", 2) / self.tparams.generations
  local hunger = self.hunger / creature.maxHunger
  local p = entity.position()
  local bounds = entity.configParameter("metaBoundBox")
  if bounds then
    p[1] = p[1] - 1.25
    p[2] = p[2] + bounds[4]/2
  end
  creature.spawnStatusBar(generation, "age", p)
  creature.spawnStatusBar(hunger, "hunger", {p[1] + 2, p[2]})
  return true
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
--------------------------------------------------------------------------------
function creature.deposit(containerId, item)
  if type(containerId) ~= "number" then return item end
  return world.containerAddItems(containerId, item)
end
--------------------------------------------------------------------------------
function checkTerritory()
  local home = storage.basePosition
  if creature and creature.isTamed() and storage.spawnPoint then
    home = storage.spawnPoint
  end
  local tdist = entity.configParameter("territoryDistance")
  local hdist = world.distance(self.position, home)[1]
  
  if hdist > tdist then
    self.territory = -1
    return
  elseif hdist < -tdist then
    self.territory = 1
  else
    self.territory = 0
  end
end