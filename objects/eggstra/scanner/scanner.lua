function init(args)
  entity.setInteractive(true)
  entity.setAllOutboundNodes(entity.animationState("switchState") == "on")
  self.cooldown = 1
end

function main()
  if entity.animationState("switchState") ~= "off" then
    if self.cooldown > 0 then
      self.cooldown = self.cooldown - entity.dt()
    else
        local position = entity.position()
        local mIds = world.monsterQuery(position, 30, { callScript = "creature.isTamed"})
        for _,mId in ipairs(mIds) do
          world.callScriptedEntity(mId, "creature.releasePheromone")
        end
        self.cooldown = 1
    end
  end
end

function onInteraction(args)
  if entity.animationState("switchState") == "off" then
    entity.setAnimationState("switchState", "on")
    entity.playSound("onSounds");
    entity.setAllOutboundNodes(true)
  else
    entity.setAnimationState("switchState", "off")
    entity.playSound("offSounds");
    entity.setAllOutboundNodes(false)
  end
end
