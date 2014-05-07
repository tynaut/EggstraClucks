function init(virtual)
  if not virtual then
    self.sellTable = entity.configParameter("sellable", {})
  end
end

function main()
  if entity.id() then
    if world.timeOfDay() < 0.4 then self.warmup = true end
    if self.warmup and world.timeOfDay() > 0.4 then
      local sell = sellItems()
      local p = entity.position()
      if sell and not world.isVisibleToPlayer({p[1] - 2, p[2] - 2, p[1] + 2, p[2] + 2}) then
          local money = 0
          for _,v in ipairs(sell) do
            money = money + sellIndex(v)
          end
          if money > 0 then
            local container = entity.id()
            local count = world.containerItemsCanFit(container, {name = "money", count = money})
            local result = world.containerAddItems(container, {name = "money", count = count})
            money = money - count
            if money > 0 then
              world.spawnItem("money", entity.position(), money)
            end
          end
          self.warmup = false
      end
    end
  end
end

function sellItems()
  local sell = {}
  local container = entity.id()
  local size = world.containerSize(container)
  for i = 0,size,1 do
    local item = world.containerItemAt(container, i)
    if item ~= nil and self.sellTable[item.name] ~= nil then
      table.insert(sell, i)
    end
  end
  if next(sell) == nil then return nil end
  return sell
end

function sellIndex(index)
  local container = entity.id()
  local item = world.containerTakeAt(container, index)
  if item then
    local value = self.sellTable[item.name]
    if value ~= nil then return value * item.count end
  end
  return 0
end