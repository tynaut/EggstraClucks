function main()
  if entity.id() then
    local container = entity.id()
    local item = world.containerItemAt(container, 0)
    if canTame(item) then
        if storage.incubationTime == nil then storage.incubationTime = os.time() end
        --TODO update time to config
        local hatchTime = 1200
        local delta = os.time() - storage.incubationTime
        if delta > hatchTime then
          spawnTamed()
        end
    else
      storage.incubationTime = nil
    end
  end
end

function canTame(item)
  if item and item.name == "filledcapturepod" then return true end  
  return false
end

function spawnTamed()
    local container = entity.id()
    local item = world.containerItemAt(container, 0)
    if canTame(item) then
      local data = item.data
      if data == nil then return end
      data = data.projectileConfig
      if data == nil then return end
      data = data.actionOnReap
      if data == nil then return end
      local params = data[1].arguments
      local mtype = data[1]["type"]
      local p = entity.position()
      params.ownerUuid = nil
      params.gender = math.random(0, 1)
      local mId = world.spawnMonster(mtype, {p[1], p[2] + 2}, params)
      if mId then
        world.containerTakeAt(container, 0)
      end
    end
end