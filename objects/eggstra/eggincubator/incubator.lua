function tick()
  if entity.id() then
    local container = entity.id()
    local item = world.containerItemAt(container, 0)
    if canHatch(item) then
        if storage.incubationTime == nil then storage.incubationTime = os.time() end
        --TODO update time to config
        local hatchTime = 10800
        if item.name == "primedegg" then hatchTime = hatchTime / 10 end
        local delta = os.time() - storage.incubationTime
        self.indicator = math.ceil( (delta / hatchTime) * 9)
        if delta >= hatchTime then
          hatchEgg()
          indicator = 0
        end
    
        if self.indicator == nil then self.indicator = 0 end
        if self.timer == nil or self.timer > self.indicator then self.timer = self.indicator - 1 end
        if self.timer > -1 then entity.setGlobalTag("bin_indicator", self.timer) end
        self.timer = self.timer + 1
    else
      storage.incubationTime = nil
    end
  end
end

function canHatch(item)
  if item == nil then return false end
  if item.name == "egg" then return true end
  if item.name == "primedegg" then return true end
  if item.name == "goldenegg" then return true end  
  return false
end

function hatchEgg()
  local container = entity.id()
  local item = world.containerTakeNumItemsAt(container, 0, 1)
  if item then
    if item.name == "egg" or "primedegg" then
      local parameters = {}
      parameters.persistent = true
	  parameters.damageTeam = 0
      parameters.startTime = os.time()
      parameters.damageTeamType = "friendly"
      world.spawnMonster("babychick", entity.position(), parameters)
    elseif item.name == "goldenegg" then
      world.spawnItem("money", entity.position(), 5000)
    end
  end
  storage.incubationTime = nil
end