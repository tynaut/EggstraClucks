function init(virtual)
  if not virtual then
    entity.setInteractive(true)
  end
end

function main()
    if storage.waterCount == nil then storage.waterCount = 0 end
    storage.waterCount = storage.waterCount + entity.dt()
end

function onInteraction(args)
  if storage.waterCount and storage.waterCount > 300 then
    local p = entity.position()
    world.spawnItem("waterbucket", p, 1)
    storage.waterCount = storage.waterCount - 300
  end
end