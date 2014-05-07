eggstrashipper = {
  spawnTime = os.time(),
  purchaseDelay = 20,
  despawnDelay = 60,
  despawning = false,
  purchased = false
}

delegate.create("eggstrashipper")
--------------------------------------------------------------------------------
function merchantState.buildTradingConfig()
  if storage.priceVariance == nil then
    storage.priceVariance = entity.randomizeParameterRange("merchant.priceVarianceRange")
  end
  local tradingConfig = {
    config = "/interface/windowconfig/shop.config",
    recipes = {
      {
        input = { { name = "animalfibre", count = 1  } },
        output = { name = "money", count = 4 * storage.priceVariance }
      },
      {
        input = { { name = "money", count = 500 * storage.priceVariance } },
        output = { name = "egg", count = 1  }
      },
      {
        input = { { name = "money", count = 5000 * storage.priceVariance  } },
        output = { name = "eggstrafemalecowpod", count = 1,
          data = { projectileConfig = { speed = 70, level = 7,
              actionOnReap = { {
                action = "spawnmonster", offset = {0, 2}, type = "eggstrabovine",
                arguments = { damageTeamType = "friendly", persistent = true, seed = 313, level = 1, gender = 0 }
              } }
          } }
        }
      },
      {
        input = { { name = "money", count = 5000 * storage.priceVariance  } },
        output = { name = "eggstramalecowpod", count = 1,
          data = { projectileConfig = { speed = 70, level = 7,
              actionOnReap = { {
                action = "spawnmonster", offset = {0, 2}, type = "eggstrabovine",
                arguments = { damageTeamType = "friendly", persistent = true, seed = 313, level = 1, gender = 1 }
              } }
          } }
        }
      }
    }
  }
  return tradingConfig
end
--------------------------------------------------------------------------------
function eggstrashipper.main()
  local deltaTime = os.time() - eggstrashipper.spawnTime
  if deltaTime > eggstrashipper.despawnDelay and not isAttacking() then
    eggstrashipper.despawn()
  end
end
--------------------------------------------------------------------------------
function eggstrashipper.despawn()
  if eggstrashipper.despawning then return end
  eggstrashipper.despawning = true
  entity.setItemSlot("primary", {name = "advancedteleporter", count = 1})
  delegate.delayCallback("eggstrashipper", "activateEffect", nil, 0.5)
end
--------------------------------------------------------------------------------
function eggstrashipper.activateEffect()
  entity.beginPrimaryFire()
  delegate.delayCallback("eggstrashipper", "endEffect", nil, 0.1)
end
--------------------------------------------------------------------------------
function eggstrashipper.endEffect()
  entity.endPrimaryFire()
end