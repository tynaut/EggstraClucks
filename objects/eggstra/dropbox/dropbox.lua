dropbox = {
  mode = 1,
  range = 20,
  delay = 60
}
--------------------------------------------------------------------------------
function main()
  if dropbox.mode == 1 then
    local shouldSell,count = canPurchase()
    if shouldSell and count ~= storage.itemCount then
      storage.itemCount = count
      if storage.itemCount > 0 then dropbox.notify() end
    end
  elseif dropbox.mode == 2 then
    local deltaTime = os.time() - dropbox.delayStart
    if deltaTime > dropbox.delay then
      dropbox.spawnShipper()
    end
  elseif dropbox.mode == 3 then
    dropbox.reset()
  end
end
--------------------------------------------------------------------------------
function canPurchase()
  local containerId = entity.id()
  local items = world.containerItems(containerId)
  local count = dropbox.sellCount(items)
  return count > 0,count
end
--------------------------------------------------------------------------------
function dropbox.notify()
  if dropbox.mode ~= 1 then return end
  
  local position = entity.position()
  local objectIds = world.objectQuery(position, dropbox.range, { name = "eggstradropbox", withoutEntityId = entity.id() })
  for _,oId in ipairs(objectIds) do
      world.callScriptedEntity(oId, "dropbox.disable", true)
  end
  
  dropbox.delayStart = os.time()
  dropbox.mode = 2
end
--------------------------------------------------------------------------------
function dropbox.disable(args)
  dropbox.mode = 0
end
--------------------------------------------------------------------------------
function dropbox.spawnShipper()
  if dropbox.mode ~= 2 then return end
  if world.info() == nil then return end
  
  local p = entity.position()
  
  if world.underground(p) then return end
  dropbox.mode = 0
  
  p[2] = p[2] + 2
  world.spawnProjectile("orbitaldown", {p[1], p[2] + 10}, entity.id(), {0, -1}, false, {power = 0})
  world.spawnNpc(p, "apex", "eggstrashipper", 1)
end
--------------------------------------------------------------------------------
function dropbox.sellCount(itemList)
  if self.sellTable == nil then self.sellTable = entity.configParameter("sellable", {}) end
  if itemList == nil then return 0 end
  local count = 0
  for _,item in ipairs(itemList) do
    if item ~= nil then
      for n,v in pairs(self.sellTable) do
        if string.find(item.name, n) ~= nil then
          count = count + 1
        end
      end
    end
  end
  return count
end
--------------------------------------------------------------------------------
function dropbox.sellItems()
  if self.sellTable == nil then self.sellTable = entity.configParameter("sellable", {}) end
  local total = 0
  local container = entity.id()
  local size = world.containerSize(container)
  for i = 0,size,1 do
    local item = world.containerItemAt(container, i)
    if item ~= nil then
      for n,v in pairs(self.sellTable) do
        if string.find(item.name, n) ~= nil then
          item = world.containerTakeAt(container, i)
          if item then total = total + (v * item.count) end
        end
      end
    end
  end
  
  if total > 0 then
    local container = entity.id()
    local result = world.containerAddItems(container, {name = "money", count = total})
    if result and result.count then
      world.spawnItem("money", entity.position(), result.count)
    end
  end
  
  storage.itemCount = 0
  dropbox.mode = 3
end
--------------------------------------------------------------------------------
function dropbox.reset()
  local position = entity.position()
  local objectIds = world.objectQuery(position, dropbox.range, { callScript = "canPurchase", withoutEntityId = entity.id() })
  if #objectIds == 0 then
    dropbox.mode = 1
  end
end