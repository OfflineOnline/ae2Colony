local scriptName = "AE2 Colony - Item Exporter"
local scriptVersion = 0.2
--[[-------------------------------------------------------------------------------------------------------------------
author: toastonrye
https://github.com/toastonrye/ae2Colony/blob/main/README.md

Setup
Please see the Github for more detailed information!

Errors
For errors please see the Github, maybe I can help... There is a list of known errors!
---------------------------------------------------------------------------------------------------------------------]]

-- [USER CONFIG] ------------------------------------------------------------------------------------------------------
local exportSide = "front"
local logFolder = "ae2Colony_logs"
local maxLogs = 10
local craftMaxStack = false -- when ae2 autocrafts, make the exact request or make an entire stack. ie 3 logs vs 64 logs
local scanInterval = 30  -- seconds

-- [BLACKLIST & WHITELIST LOOKUPS] --------------------------------------------------------------------------------------------------------
-- blacklistedTags: all items matching the given tags are skipped, they do not export.
local blacklistedTags = {
  ["c:foods"] = true,
}

-- whitelistItemName: specific item names can be whitelisted.
-- If c:foods is blacklisted, whitelist minecraft:beef so colonists can cook into steaks!
-- QUESTION: Maybe no food should be whitelisted, the resturant seems to over-request food to cook up, filling warehouse??
local whitelistItemName = {
  --["minecraft:cod"] = true,
  --["minecraft:beef"] = true,
  ["minecraft:carrot"] = true,
}

-- [TOOLS & ARMOUR LOOKUPS]----------------------------------------------------------------------------------------------------
-- NOTE: I had plans to have different tiers, but because of the script crash from colonists missing tools...
-- It's difficult to implement until a new AP version is releasted. Newer than version 0.7.51b for Advanced Peripherals
-- See https://github.com/IntelligenceModding/AdvancedPeripherals/issues/748 for more context.
local fallback = {
  chestplate = "minecraft:leather_chestplate",
  boots      = "minecraft:leather_boots",
  leggings   = "minecraft:leather_leggings",
  helmet     = "minecraft:leather_helmet",
  sword      = "minecraft:wooden_sword",
  pickaxe    = "minecraft:wooden_pickaxe",
  axe        = "minecraft:wooden_axe",
  shovel     = "minecraft:wooden_shovel",
  hoe        = "minecraft:wooden_hoe"
}

-- If getRequests() fails, we try to send a "care package" of tools, seems to fix colonist complaints. It's crude.
-- Tool tier level should all be lowest, ie wooden to make sure all colonists can use. Only tested with wooden.
-- If you upgrade a guard tower to level 2 or 3, manually give them a better tier weapon. Or pickaxe for builders.
local carePackage = {
  chestplate = "minecraft:leather_chestplate",
  boots      = "minecraft:leather_boots",
  leggings   = "minecraft:leather_leggings",
  helmet     = "minecraft:leather_helmet",
  sword      = "minecraft:wooden_sword",
  pickaxe    = "minecraft:wooden_pickaxe",
  axe        = "minecraft:wooden_axe",
  shovel     = "minecraft:wooden_shovel",
  hoe        = "minecraft:wooden_hoe"
}

-- [LOGGING] ----------------------------------------------------------------------------------------------------------
if not fs.exists(logFolder) then fs.makeDir(logFolder) end

local function getLocalTime(offsetHours)
  local utc = os.epoch("utc")
  return utc + (offsetHours * 3600 * 1000)
end

local function getDateStamp()
  local t = os.date("*t", getLocalTime(0) / 1000)
  return string.format("%04d-%02d-%02d", t.year, t.month, t.day)
end

local function logLine(line)
  local timestamp = os.date("%H:%M:%S", getLocalTime(0) / 1000)
  local path = string.format("%s/%s.log", logFolder, getDateStamp())
  local f = fs.open(path, "a")
  if f then
    f.writeLine(string.format("[%s] %s", timestamp, line))
    f.close()
  end
end

local function cleanupOldLogs()
  local files = fs.list(logFolder)
  table.sort(files)
  while #files > maxLogs do
    fs.delete(logFolder .. "/" .. table.remove(files, 1))
  end
end

-- [MONITOR] ----------------------------------------------------------------------------------------------------------
local monitorLines = {} 
local function setupMonitor()
  local monitor = peripheral.find("monitor")
  if not monitor then return nil end
  monitor.setTextScale(0.5)
  monitor.clear()
  monitor.setCursorPos(1, 1)
  --monitor.write("AE2 Exporter Ready")
  return monitor
end

local function drawProgressBar(monitor, secondsLeft, totalSeconds)
  if not monitor then return end
  local width, _ = monitor.getSize()
  local filled = math.floor((secondsLeft / totalSeconds) * width)
  monitor.setCursorPos(1, 1)
  monitor.setTextColor(colors.gray)
  monitor.write(string.rep("-", width))
  monitor.setCursorPos(1, 1)
  monitor.setTextColor(colors.green)
  monitor.write(string.rep("#", filled))
end

local function updateMonitorGrouped(monitor)
  if not monitor then return end

  monitor.setTextScale(0.8)
  monitor.clear()
  local colorsMap = {
    CRAFT = colors.green,
    SENT = colors.lime,
    ERROR = colors.red,
    MISSING = colors.orange,
    MANUAL = colors.cyan,
    INFO = colors.yellow,
  }


  local groups = {
    ["CRAFT"] = {},
    ["SENT"] = {},
    ["ERROR"] = {},
    ["MISSING"] = {},
    ["MANUAL"] = {},
    ["INFO"] = {},
  }

  for _, line in ipairs(monitorLines) do
    for label in pairs(groups) do
      if line:find("%[" .. label .. "%]") then
        table.insert(groups[label], line)
        break
      end
    end
  end

  local _, yMax = monitor.getSize()
  local y = 2  -- leave line 1 for progress bar
  for label, entries in pairs(groups) do
    if #entries > 0 then
      if y > yMax then return end
      monitor.setCursorPos(1, y)
      monitor.setTextColor(colors.white)
      monitor.write("== " .. label .. " ==")
      y = y + 1
      for _, entry in ipairs(entries) do
        if y > yMax then return end
        monitor.setCursorPos(1, y)
        monitor.setTextColor(colorsMap[label] or colors.white)
        monitor.write(entry:sub(1, monitor.getSize()))
        y = y + 1
      end
    end
  end
end

local function logAndDisplay(msg)
  logLine(msg)
  table.insert(monitorLines, msg)
end

-- [AP PERIPHERAL SETUP] ----------------------------------------------------------------------------------------------
local function setupPeripherals()
  term.clear()
  term.setCursorPos(1, 1)

  local bridge = peripheral.find("me_bridge") or error("me_bridge missing")
  local colony = peripheral.find("colony_integrator") or error("colony_integrator missing")
  if colony and not colony.isInColony then error("colony_integrator not in a colony") end
  return bridge, colony, setupMonitor()
end

local function confirmConnection(bridge)
  if bridge.isOnline() then
    return
  else
      error("ae2 bridge offline")
  end
end

-- [UTILS] ------------------------------------------------------------------------------------------------------------


-- Not using hasEnchantments because we use exact fingerprints or send name with components = {}, empty tag.
local function hasEnchantments(item)
  if not item or not item.components then return false end
  for k, _ in pairs(item.components) do
    if string.lower(k):find("ench") then return true end
  end
  return false
end

local exportBuffer = {}
local function queueExport(fingerprint, count, name, target)
  table.insert(exportBuffer, {
    name = name,
    fingerprint = fingerprint,
    count = count,
    target = target
  })
end

local function processExportBuffer(bridge)
  for _, item in ipairs(exportBuffer) do
    local ok, result = pcall(function()
      return bridge.exportItem({
        fingerprint = item.fingerprint,
        name = item.name,
        count = item.count,
        components = {}
      }, exportSide)
    end)

    if not ok or not result then
      logAndDisplay(string.format("[ERROR] x%d - %s -> %s", item.count, item.name, item.target))
    else
      logAndDisplay(string.format("[SENT] x%d - %s -> %s", item.count, item.name, item.target))
    end
  end
end

-- [HANDLERS] ---------------------------------------------------------------------------------------------------------
local function bridgeDataHandler(bridge)
  local indexFingerprint = {}
  local ok, result = pcall(function()
    return bridge.getItems()
  end)
  if ok then
    for i = 1, #result do
      if result[i].fingerprint then indexFingerprint[result[i].fingerprint] = result[i] end
    end
  else
    logAndDisplay(string.format("[ERROR] ME Bridge Issues"))
  end
  return indexFingerprint
end

-- A crude solution to send tools to try and stop a weird bug.
local function carePackageHandler(bridge)
  local craftable
  local ok, result
  for _, tool in pairs(carePackage) do
    ok,  result = pcall(function() return bridge.exportItem({
      name = tool,
      count = 1,
      components = {}
      }, exportSide)
    end)
    if not ok then
      craftable = bridge.isCraftable({name = tool, components = {}})
      if craftable then
        ok, result = pcall(function() return bridge.craftItem({name = tool, count = 1, components = {}}) end)
        os.sleep(3)
      end
    end
    if not ok then
      local msg = string.format("[ERROR] Care package failed, unknown.") -- player needs to investigate why...
      print(msg)
      logLine(msg)
      return false
    else
      local msg = string.format("[INFO] Care package: %s", tool)
      print(msg)
      logLine(msg)
    end
  end
  return true
end

local tries = 0
local function colonyRequestHandler(colony, bridge)
  local ok, result = pcall(function()
    return colony.getRequests()
  end)
  if ok then
    if not next(result) then
      logAndDisplay(string.format("No Colony Requests Detected"))
      return
    else
      return result
    end
  else
    -- In AP v0.7.51b colony.getRequests() can fail because colonists are missing basic tools, some issue with enchantment data.
    -- Put a few wooden swords/hoes/shovel/pickaxe/axes to your warehouses and the error clears. Reported to AP Github.
    if tries == 0 then
      tries = tries + 1
      carePackageHandler(bridge)
      local msg = string.format("[INFO] Waiting 10s for colonists to find gear.")
      term.setTextColor(colors.orange)
      print(msg)
      logLine(msg)
      os.sleep(10)
      colonyRequestHandler(colony, bridge)
    else
      local msg = string.format("[ERROR] Critical failure for colony_integrator getRequests().")
      print(msg)
      logLine(msg)
      os.sleep(1)
      error(result)
    end
  end
  local msg = string.format("[INFO] getRequests() error fixed!")
  term.setTextColor(colors.lime)
  print(msg)
  term.setTextColor(colors.white)
  logLine(msg)
  return result
end

-- FUTURE: if desc mentions max/min tiers for gear, more complex fallback list 
local function keywordHandler(request)
  local keywords = {"chestplate", "boots", "leggings", "helmet", "sword", "shovel", "pickaxe", "axe", "hoe"}
    local label = string.lower(request.name or "")
    --local desc = request.desc or "" 
    for _, word in ipairs(keywords) do
      local pattern = "%f[%a]" .. word .. "%f[%A]"
      if string.find(label, pattern) then
        return fallback[word]
      end
    end
    return nil
end

-- See blacklisted tags and whitelisted items table at top of script.
-- Basically blacklist an entire tag like c:foods then whitelist food for colonists to cook, like raw beef.
local function tagHandler(requestItem)
  if whitelistItemName[requestItem.name] then
    return true, true
  elseif requestItem.tags then
    for _, tag in pairs(requestItem.tags) do
      if type(tag) == "string" then
        for blocked in pairs(blacklistedTags) do
          if tag:find("c:foods") then
            return true, false
          end
        end
      end
    end
  end
  return false, nil
end

-- Domum Ornamentum adds the Architect's Cutter, the player has to manually craft these special blocks
-- Apparently colonists can also make them?
-- FUTURE make option to disable this handler so colonists can make blocks? 
local function domumHandler(request)
  local requestDisplayName = request.name
  local requestItem = request.items[1]
  local requestName = requestItem.name
  local requestFingerprint = requestItem.fingerprint
  local requestComponents = requestItem.components
  
  if requestName:find("domum_ornamentum") then
    local list, flip = {}, {}
    local textureData = requestComponents and requestComponents["domum_ornamentum:texture_data"]
    if textureData then
      for _, value in pairs(textureData) do
        table.insert(list, value)
      end
      for i = #list, 1, -1 do
        table.insert(flip, list[i])
      end
    end
    local blockState = requestComponents and requestComponents["minecraft:block_state"]
    if blockState then
      for _, value in pairs(blockState) do
        table.insert(flip, value)
      end
    end
    logAndDisplay(string.format("[MANUAL] %s - %s [%s]", requestDisplayName, requestName, requestFingerprint))
    for key, value in ipairs(flip) do
      logAndDisplay(string.format("[MANUAL] #%d %s", key, value))
    end
  end
end

local function messageHandler()
  --handle prints to terminal, monitor, log, chatbox, rednet?
end

local function craftHandler(request, bridgeItem, bridge)
  local craftable = nil
  local payload = {}
  local ok, object = nil, nil
  local fingerprint = bridgeItem and bridgeItem.fingerprint
  local name = request.items[1].name
  local maxStackSize = request.items[1].maxStackSize
  local stackSize = (craftMaxStack and maxStackSize) or request.count

  if stackSize == 0 then stackSize = 1 end
  if fingerprint then
    craftable = bridge.isCraftable({fingerprint = fingerprint, count = stackSize})
    payload = {fingerprint = fingerprint, count = stackSize}
  elseif name then
    craftable = bridge.isCraftable({name = name, components = {}, count = stackSize})
    payload = {name = name, count = stackSize, components = {}}
  end
  if craftable then
    ok, object = pcall(function() return bridge.craftItem(payload) end)
    if object.isCraftingStarted() then
      logAndDisplay(string.format("[CRAFT] x%d - %s", stackSize, name))
    else
      logAndDisplay(string.format("[ERROR] Crafting Recipe x%d - %s [%s]", stackSize, name, fingerprint))
    end
  else
    logAndDisplay(string.format("[MISSING] No Recipe x%d - %s [%s]", stackSize, name, request.items[1].fingerprint))
  end
  return object
end

-- [EVENT HANDLER] ----------------------------------------------------------------------------------------------------
-- THIS DOESN'T DO ANYTHING
local function eventHandler()
  local event, error, id, message = os.pullEvent("me_crafting")
  print(event, error, id, message)
end

-- [MAIN HANDLER] -----------------------------------------------------------------------------------------------------
-- This is the main item exporting logic, decision making.
-- 1: First check for blacklisted tags like c:foods, then if specific food items are whitelisted before skipped export.
-- 2: Check for tool/armour request, then substitue. ie Mekanism boots get requested, replace with leather boots.
-- 3. Exact fingerprint match, export full requested item count.
-- 4. Exact fingerprint match, not enough items. Try to autocraft if an AE2 pattern exists.
-- 5. No fingerprint match, try to autocraft by item name. Crafting patterns with item count 0 return no fingerprint, fyi.
-- 6. If step 4/5 can't autocraft items, the player must manually do it.
local function mainHandler(bridge, colony)
  local colonyRequests = colonyRequestHandler(colony, bridge)
  local fallbackCache = {}
  local indexFingerprint = bridgeDataHandler(bridge)
  for _, request in ipairs(colonyRequests) do
    local requestCount = request.count or 0
    local requestItem = request.items[1]
    local requestTarget = request.target or request.name or "Unknown Target"

    local isTagBlacklisted, whitelistException = tagHandler(requestItem)
    local fallbackItem = keywordHandler(request)

    if requestItem then
      local requestFingerprint = requestItem.fingerprint
      local requestName = requestItem.name
      local bridgeItem = indexFingerprint[requestFingerprint]

      -- [CASE 1] Skip tag c:foods by default.
      if isTagBlacklisted then
        if whitelistException then
          local bridgeCount = (bridgeItem and bridgeItem.count) or 0
          local countDelta = bridgeCount - requestCount
          if countDelta > 0 then
            queueExport(requestFingerprint, requestCount, requestName, requestTarget)
          elseif bridgeCount > 0 then
            queueExport(requestFingerprint, bridgeCount, requestName, requestTarget)
            local craftObject = craftHandler(request, bridgeItem, bridge)
          else
            local craftObject = craftHandler(request, bridgeItem, bridge)
          end
        end
      -- [CASE 2] Matched keyword for tool or armour
      elseif fallbackItem then
        local inStock = fallbackCache[fallbackItem]
        if not inStock then
          inStock = bridge.getItem({name = fallbackItem, count = requestCount, components = {}})
          fallbackCache[fallbackItem] = inStock
        end

        logAndDisplay(string.format("[INFO] %s instead of %s", fallbackItem, requestName))
        local hasNBT = inStock.components and next(inStock.components)
        if inStock and inStock.count >= requestCount and not hasNBT  then
          queueExport(nil, requestCount, fallbackItem, requestTarget)
        else
          request.items[1].name = fallbackItem
          local craftObject = craftHandler(request, bridgeItem, bridge)
        end
      -- [CASE 3] Bridge fingerprint match, and has enough items.
      -- [CASE 4] Bridge fingerprint match, but items equal or less. We craft if equal because fast fingerprints only work if items >0
      elseif bridgeItem then
        local bridgeCount = bridgeItem.count or 0
        local countDelta = bridgeCount - requestCount
        if countDelta > 0 then
          queueExport(requestFingerprint, requestCount, requestName, requestTarget)
        elseif bridgeCount > 0 then
          queueExport(requestFingerprint, bridgeCount, requestName, requestTarget)
          local craftObject = craftHandler(request, bridgeItem, bridge)
        else
          local craftObject = craftHandler(request, bridgeItem, bridge)
          -- watch for craft events maybe??
          -- https://docs.advanced-peripherals.de/latest/guides/storage_system_functions/#crafting-job
        end
      -- [CASE 5] No fingerprint match. Note items with a crafting pattern but count 0 also have no fingerprint.
      else
        local domum = domumHandler(request)
        local craftObject = craftHandler(request, bridgeItem, bridge)
      end
    end
    
  end
end

-- [MAIN LOOP] --------------------------------------------------------------------------------------------------------
cleanupOldLogs()
local bridge, colony, monitor = setupPeripherals()
local title = string.format("[INFO] %s v%.1f initialized", scriptName, scriptVersion)
print(title)
logLine(title)

function main()
  while true do
    exportBuffer = {}
    monitorLines = {}
    confirmConnection(bridge)
    mainHandler(bridge, colony)
    processExportBuffer(bridge)
    updateMonitorGrouped(monitor)

    for i = scanInterval, 1, -1 do
      drawProgressBar(monitor, i, scanInterval)
      os.sleep(1)
    end
  end
end

parallel.waitForAll(main)
