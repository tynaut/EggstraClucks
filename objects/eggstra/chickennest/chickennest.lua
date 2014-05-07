function tick()
  if entity.id() then
    local container = entity.id()
    local item = world.containerItemAt(container, 0)
    if item and item.name == "egg" then
        if storage.incubationTime == nil then storage.incubationTime = os.time() end
        --TODO update time to config
        if os.time() - storage.incubationTime > 21600 then hatchEgg() end
    else
      storage.incubationTime = nil
    end
  end
end

function hatchEgg()
  local container = entity.id()
  local item = world.containerTakeNumItemsAt(container, 0, 1)
  if item then
    if item.name == "egg" then
      local parameters = {}
      parameters.persistent = true
	  parameters.damageTeam = 0
      parameters.startTime = os.time()
      world.spawnMonster("babychick", entity.position(), parameters)
    end
  end
  storage.incubationTime = nil
end