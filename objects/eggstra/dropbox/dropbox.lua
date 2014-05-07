function init(virtual)
  if not virtual then
    self.sellTable = entity.configParameter("sellable", {})
  end
end

function main()
  if entity.id() then
    if world.timeOfDay() < 0.4 then self.warmup = true end
    if self.warmup and world.timeOfDay() > 0.4 then
      local p = entity.position()
      if not world.isVisibleToPlayer({p[1] - 2, p[2] - 2, p[1] + 2, p[2] + 2}) then
          local money = sellItems()
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
  return total
end