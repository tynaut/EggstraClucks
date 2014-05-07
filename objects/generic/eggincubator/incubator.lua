function main()
  if entity.id() then
    local container = entity.id()
    local count = 0
    local item = world.containerItemAt(container, 0)
    if canHatch(item) then
        if storage.incubationTime == nil then storage.incubationTime = os.time() end
        --TODO update time to config
        local hatchTime = 10800
        if item.name == "primedegg" then hatchTime = hatchTime / 10 end
        if os.time() - storage.incubationTime > hatchTime then hatchEgg() end
    else
      storage.incubationTime = nil
    end
    
    if item ~= nil and item.count ~= nil then count = item.count end
    local fill = math.ceil(count / 100)
    if self.fill ~= fill then
      self.fill = fill
      entity.setAnimationState("fill", tostring(fill))
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
      world.spawnMonster("babychick", entity.position(), parameters)
    elseif item.name == "goldenegg" then
      world.spawnItem("money", entity.position(), 5000)
    end
  end
  storage.incubationTime = nil
end