local scriptName = "AE2 Colony"
local scriptVersion = 0.3
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
local craftMaxStack = false -- autocraft exact or a stack. ie 3 logs vs 64 logs.
local fallbackEnable = true -- fallback currently not working, leave false
local scanInterval = 30

-- [BLACKLIST & WHITELIST LOOKUPS] --------------------------------------------------------------------------------------------------------
-- blacklistedTags: all items matching the given tags are skipped, they do not export.
local blacklistedTags = {
  ["c:foods"] = true,
  ["c:tools"] = true,
}

-- whitelistItemName: specific item names can be whitelisted.
-- If c:foods is blacklisted, whitelist minecraft:beef so colonists can cook into steaks!
-- QUESTION: Maybe no food should be whitelisted, the resturant seems to over-request food to cook up, filling warehouse??
local whitelistItemName = {
  --["minecraft:cod"] = true,
  --["minecraft:beef"] = true,
  ["minecraft:carrot"] = true,
  ["minecraft:potato"] = true,
  ["minecolonies:apple_pie"] = true,
}

-- [TOOLS & ARMOUR LOOKUPS]----------------------------------------------------------------------------------------------------
-- Future scripts might have tiers for tools/armours, but for now c:tools is blacklisted.
-- QUESTION: It maybe better to just have colonists make tools and armour?
local fallback = {
  chestplate = "minecraft:leather_chestplate",
  boots      = "minecraft:leather_boots",
  leggings   = "minecraft:leather_leggings",
  helmet     = "minecraft:leather_helmet",
  --sword      = "minecraft:wooden_sword",  guard seems to insist on gold sword, so it's filling warehouse with wooden_sword
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
  return monitor
end

local function drawProgressBar(monitor, secondsLeft, totalSeconds, paused)
  if not monitor then return end
  local width, _ = monitor.getSize()
  local filled = math.floor((secondsLeft / totalSeconds) * width)
  if paused then
    monitor.setCursorPos(1, 2)
    monitor.setTextColor(colors.red)
    monitor.write(string.rep("#", width))
  else
    monitor.setCursorPos(1, 2)
    monitor.setTextColor(colors.gray)
    monitor.write(string.rep("-", width))
    monitor.setCursorPos(1, 2)
    monitor.setTextColor(colors.green)
    monitor.write(string.rep("#", filled))
  end
end

local function updateMonitorGrouped(monitor)
  if not monitor then return end
  
  monitor.setTextScale(0.5)
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
  local y = 3
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
    return true
  end
  return false
end

-- [UTILS] ------------------------------------------------------------------------------------------------------------
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
-- AP fingerprints are amazing. Use "/advancedperipehrals getHashItem" in-game
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

local function updateHeader(monitor, bridge, tick)
  if not monitor then return end

  local width = monitor.getSize()
  local headerText = string.format("%s v%s", scriptName, scriptVersion)
  local statusText = "AE2 Status"
  local statusX = width - #statusText + 1

  monitor.setCursorPos(1, 1)
  monitor.setTextColor(colors.orange)
  monitor.write(headerText)

  local status = confirmConnection(bridge)
  monitor.setCursorPos(statusX, 1)
  monitor.setTextColor(status and colors.lime or colors.red)
  monitor.write(statusText)

  drawProgressBar(monitor, tick, scanInterval, not status)
end

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
    -- Reported to Advanced Peripherals Github, should be fixed in newer versions.
    -- https://github.com/IntelligenceModding/AdvancedPeripherals/issues/748
    -- In v0.7.51b colony.getRequests() can fail because colonists are missing basic tools, some issue with enchantment data.
    -- Put a few basic wooden swords/hoes/shovel/pickaxe/axes in your warehouse.
    -- Also do leather armour as well, I've seen a failure from enchantment "feather falling".
    local msg = string.format("[ERROR] Critical failure for colony_integrator getRequests().")
    print(msg)
    logLine(msg)
    os.sleep(1)
    error(result)
  end
end

-- QUESTION: If desc mentions max/min tiers for gear, more complex fallback list?
local function keywordHandler(request)
  local keywords = {"chestplate", "boots", "leggings", "helmet", "sword", "shovel", "pickaxe", "axe", "hoe"}
    local label = string.lower(request.name or "")
    --local desc = request.desc or "
    for _, word in ipairs(keywords) do
      local pattern = "%f[%a]" .. word .. "%f[%A]"
      if string.find(label, pattern) then
        return fallback[word]
      end
    end
    return nil
end

-- See blacklisted tags and whitelisted items table at top of script.
-- Basically blacklist an entire tag like c:foods then whitelist food for colonists to cook, like raw beef. Or carrots/potatoes for hospitals.
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

-- Domum Ornamentum adds the Architect's Cutter, the player has to manually craft these special blocks.
-- QUESTION: Apparently colonists can also make them?
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

-- QUESTION: handle prints to terminal, monitor, log, chatbox, rednet?
local function messageHandler()
  -- todo
end

-- QUESTION: Make this handle ae2 crafts better? If craft started or if it's missing ingredients?
-- https://docs.advanced-peripherals.de/latest/guides/storage_system_functions/#objects
local function craftHandler(request, bridgeItem, bridge)
  local craftable = nil
  local payload = {}
  local ok, object = nil, nil
  local fingerprintBridge = bridgeItem and bridgeItem.fingerprint
  local fingerprintRequest = request.items[1].fingerprint
  local name = request.items[1].name
  local maxStackSize = request.items[1].maxStackSize
  local stackSize = (craftMaxStack and maxStackSize) or request.count

  if stackSize == 0 then stackSize = 1 end
  if fingerprintBridge then
    craftable = bridge.isCraftable({fingerprint = fingerprintBridge, count = stackSize})
    payload = {fingerprint = fingerprintBridge, count = stackSize}
  elseif name then
    craftable = bridge.isCraftable({name = name, components = {}, count = stackSize})
    payload = {name = name, count = stackSize, components = {}}
  end
  if craftable then
    ok, object = pcall(function() return bridge.craftItem(payload) end)
    if ok then
      logAndDisplay(string.format("[CRAFT] x%d - %s [%s]", stackSize, name, fingerprintRequest))
    else
      logAndDisplay(string.format("[ERROR] Failed crafting: x%d - %s [%s]", stackSize, name, fingerprintBridge or fingerprintRequest or "Not Available"))
    end
  else
    logAndDisplay(string.format("[MISSING] No recipe x%d - %s [%s]", stackSize, name, fingerprintBridge or fingerprintRequest or "Not Available"))
  end
  return object
end

-- [MAIN HANDLER] -----------------------------------------------------------------------------------------------------
-- This is the main item exporting logic, decision making.
-- 1: First check for blacklisted tags like c:foods, then if specific food items are whitelisted before skipping export.
-- 2: Check for tool/armour request, then substitue. ie Mekanism boots get requested, replace with leather boots.
-- 3. Exact fingerprint match, export full requested item count.
-- 4. Exact fingerprint match, not enough items. Try to autocraft if an AE2 pattern exists.
-- 5. No fingerprint match, try to autocraft by item name. Crafting patterns with item count 0 return no fingerprint, fyi.
-- 6. If step 4/5 can't autocraft items, the player must manually do it.
local function mainHandler(bridge, colony)
  local colonyRequests = colonyRequestHandler(colony, bridge)
  local fallbackCache = {}
  local indexFingerprint = bridgeDataHandler(bridge)
  if not colonyRequests then
    logAndDisplay(string.format("[INFO] No colony requests detected!"))
    return
  end
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
        if fallbackEnable then
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
            -- Dirty swapping of request data, it contains both fallbackItem data as well as the original requested item.
            request.items[1].name = fallbackItem
            request.items[1].fingerprint = inStock.fingerprint or nil
            request.count = requestCount
            local craftObject = craftHandler(request, nil, bridge)
          end
        else
          logAndDisplay(string.format("[MANUAL] Fallback logic disabled for: %s", requestName))
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
          -- QUESTION: Watch for craft events maybe? https://docs.advanced-peripherals.de/latest/guides/storage_system_functions/#crafting-job
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

local function main()
  while true do
    exportBuffer = {}
    monitorLines = {}
    mainHandler(bridge, colony)
    processExportBuffer(bridge)
    updateMonitorGrouped(monitor)

    for i = scanInterval, 1, -1 do
      updateHeader(monitor, bridge, i)
      os.sleep(1)
    end
  end
end

parallel.waitForAll(
  main
  --function() return updateHeader(monitor, bridge) end
)
