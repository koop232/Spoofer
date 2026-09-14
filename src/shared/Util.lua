--[[
	Util
	----
	Small dependency-free helpers. Pure functions only: everything in here is
	directly unit tested by the offline harness.
]]

local Util = {}

--- Wraps `fn` so it can never throw into the caller. Returns ok, result...
function Util.try(fn, ...)
	if type(fn) ~= "function" then
		return false, "not a function"
	end
	return pcall(fn, ...)
end

--- pcall that logs nothing and returns `default` on failure.
function Util.attempt(default, fn, ...)
	local ok, result = pcall(fn, ...)
	if ok and result ~= nil then
		return result
	end
	return default
end

--- Formats a per-second income figure using short SI-ish suffixes.
function Util.formatGeneration(value)
	value = tonumber(value) or 0
	local negative = value < 0
	local n = math.abs(value)

	local text
	if n >= 1e15 then
		text = string.format("%.1fQ", n / 1e15)
	elseif n >= 1e12 then
		text = string.format("%.1fT", n / 1e12)
	elseif n >= 1e9 then
		text = string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		text = string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then
		text = string.format("%.1fK", n / 1e3)
	else
		text = tostring(math.floor(n))
	end

	-- Trim a trailing ".0" so "$1.0M/s" renders as "$1M/s".
	text = text:gsub("%.0(%a)$", "%1")

	return string.format("$%s%s/s", negative and "-" or "", text)
end

--- Truncates `text` to `limit` characters, appending an ellipsis.
function Util.truncate(text, limit)
	text = tostring(text or "")
	limit = limit or 15
	if #text <= limit then
		return text
	end
	if limit <= 1 then
		return text:sub(1, limit)
	end
	return text:sub(1, limit - 1) .. "…"
end

--- Case-insensitive subsequence match used by the search box.
--- "dgc" matches "Dragon Cannelloni"; a plain substring also matches.
function Util.fuzzyMatch(haystack, needle)
	if needle == nil or needle == "" then
		return true
	end
	haystack = tostring(haystack):lower()
	needle = tostring(needle):lower()

	if haystack:find(needle, 1, true) then
		return true
	end

	local cursor = 1
	for index = 1, #needle do
		local char = needle:sub(index, index)
		if char ~= " " then
			local found = haystack:find(char, cursor, true)
			if not found then
				return false
			end
			cursor = found + 1
		end
	end
	return true
end

--- Ranks matches so exact / prefix hits float to the top of the list.
function Util.matchScore(haystack, needle)
	if needle == nil or needle == "" then
		return 0
	end
	local lowerHay = tostring(haystack):lower()
	local lowerNeedle = tostring(needle):lower()

	if lowerHay == lowerNeedle then
		return 100
	end
	if lowerHay:sub(1, #lowerNeedle) == lowerNeedle then
		return 75
	end
	local at = lowerHay:find(lowerNeedle, 1, true)
	if at then
		return 50 - math.min(at, 25)
	end
	if Util.fuzzyMatch(lowerHay, lowerNeedle) then
		return 10
	end
	return -1
end

--- Filters + ranks a list of names against a query.
function Util.searchNames(names, query)
	local results = {}
	for _, name in ipairs(names) do
		local score = Util.matchScore(name, query)
		if score >= 0 then
			results[#results + 1] = { name = name, score = score }
		end
	end
	table.sort(results, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.name < b.name
	end)

	local names2 = {}
	for index, entry in ipairs(results) do
		names2[index] = entry.name
	end
	return names2
end

--- Shallow copy; used so callers cannot mutate module level tables.
function Util.shallowCopy(source)
	local out = {}
	for key, value in pairs(source) do
		out[key] = value
	end
	return out
end

--- Returns true when `value` is one of the entries in `list`.
function Util.contains(list, value)
	for _, entry in ipairs(list) do
		if entry == value then
			return true
		end
	end
	return false
end

--- Clamps a number into a range.
function Util.clamp(value, min, max)
	if value < min then
		return min
	elseif value > max then
		return max
	end
	return value
end

return Util
