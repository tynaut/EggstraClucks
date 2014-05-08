function init(virtual)
  if not virtual then
    entity.setInteractive(true)
  end
end

function onInteraction(args)
  local monsterIds = world.monsterQuery(entity.position(), 40)
  entity.playSound("sounds")
  for _,mId in ipairs(monsterIds) do
    world.callScriptedEntity(mId, "creature.beckon", entity.id())
  end
end