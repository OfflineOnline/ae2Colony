local colony = peripheral.find("colony_integrator") or error("colony_integrator not found")

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

-- Sanitize one work request
local function sanitizeRequest(req)
  local result = {}

  for k, v in pairs(req) do
    if type(v) ~= "table" and type(v) ~= "function" then
      result[k] = v
    elseif k == "items" and type(v[1]) == "table" then
      -- Only deep-copy the first item, as it is commonly used
      result.items = { deepCopyFlat(v[1]) }
    end
    -- Skip unrecognized nested fields or problematic tables like nbt
  end

  return result
end

-- Get colony requests and sanitize them
local ok, requests = pcall(colony.getRequests)
if not ok then error("Failed to call getRequests: " .. tostring(requests)) end

local cleanRequests = {}
for _, req in ipairs(requests) do
  table.insert(cleanRequests, sanitizeRequest(req))
end

-- Write to file
local file = fs.open("sampleColonyData.txt", "w")
file.write("return " .. textutils.serialize(cleanRequests))
file.close()

print("Dumped colony requests.")
