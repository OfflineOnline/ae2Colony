local bridge = peripheral.find("me_bridge") or error("me_bridge not found")

-- Safe recursive deep-copy (serializable types only)
local function deepCopyFlat(value)
  if type(value) == "table" then
    local result = {}
    for k, v in pairs(value) do
      if type(k) == "string" or type(k) == "number" then
        if type(v) == "table" or type(v) == "string" or type(v) == "number" or type(v) == "boolean" then
          result[k] = deepCopyFlat(v)
        end
      end
    end
    return result
  elseif type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
    return value
  else
    return nil -- skip functions, userdata, etc.
  end
end

-- Sanitize one item
local function sanitizeItem(item)
  local result = {}

  for k, v in pairs(item) do
    if type(v) ~= "table" and type(v) ~= "function" then
      result[k] = v
    elseif k == "tags" or k == "components" then
      result[k] = deepCopyFlat(v)
    end
    -- Skip other nested or function-based fields (like `nbt`)
  end

  return result
end

-- Get ME items and sanitize them
local ok, items = pcall(bridge.getItems)
if not ok then error("Failed to call getItems: " .. tostring(items)) end

local cleanItems = {}
for _, item in ipairs(items) do
  table.insert(cleanItems, sanitizeItem(item))
end

-- Write to file
local file = fs.open("sampleBridgeData.txt", "w")
file.write("return " .. textutils.serialize(cleanItems))
file.close()

print("Dumped ME items.")
