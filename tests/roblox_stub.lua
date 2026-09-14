--[[
	Minimal Roblox runtime stubs so the pure modules can be exercised by a
	plain Lua interpreter. Only what the tested code paths actually touch is
	implemented -- this is a test fixture, not an emulator.
]]

-- Color3 -------------------------------------------------------------------

local Color3 = {}
Color3.__index = Color3

function Color3.fromRGB(r, g, b)
	return setmetatable({ R = r / 255, G = g / 255, B = b / 255 }, Color3)
end

function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3)
end

function Color3:Lerp(other, alpha)
	return Color3.new(
		self.R + (other.R - self.R) * alpha,
		self.G + (other.G - self.G) * alpha,
		self.B + (other.B - self.B) * alpha
	)
end

_G.Color3 = Color3

-- Vector3 ------------------------------------------------------------------

local Vector3 = {}
Vector3.__index = Vector3

function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end

function Vector3.__sub(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end

function Vector3.__add(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end

function Vector3.__index(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
	end
	return rawget(Vector3, key)
end

_G.Vector3 = Vector3

-- UDim / UDim2 --------------------------------------------------------------

_G.UDim = {
	new = function(scale, offset)
		return { Scale = scale, Offset = offset }
	end,
}

_G.UDim2 = {
	new = function(sx, ox, sy, oy)
		return { X = { Scale = sx, Offset = ox }, Y = { Scale = sy, Offset = oy } }
	end,
}

-- Enum ----------------------------------------------------------------------

local function enumFamily(names)
	local family = {}
	for _, name in ipairs(names) do
		family[name] = { Name = name }
	end
	return family
end

_G.Enum = {
	FillDirection = enumFamily({ "Horizontal", "Vertical" }),
	SortOrder = enumFamily({ "LayoutOrder", "Name" }),
	AutomaticSize = enumFamily({ "X", "Y", "XY", "None" }),
	TextXAlignment = enumFamily({ "Left", "Center", "Right" }),
	TextTruncate = enumFamily({ "AtEnd", "None" }),
	Font = enumFamily({ "Gotham", "GothamBold", "GothamBlack" }),
	UserInputType = enumFamily({ "MouseButton1", "MouseMovement", "Touch" }),
	UserInputState = enumFamily({ "Begin", "End" }),
	ZIndexBehavior = enumFamily({ "Sibling", "Global" }),
}

-- task ----------------------------------------------------------------------

_G.task = {
	spawn = function(fn, ...)
		-- Run synchronously but never let a background loop block the tests.
		return fn
	end,
	defer = function(fn)
		return fn
	end,
	delay = function(_, fn)
		return fn
	end,
	wait = function()
		return 0
	end,
}

-- misc ----------------------------------------------------------------------

_G.warn = function(...)
	io.stderr:write("[warn] ", table.concat({ ... }, " "), "\n")
end

if not table.clear then
	function table.clear(t)
		for key in pairs(t) do
			t[key] = nil
		end
	end
end

-- `game` is deliberately absent: Env must degrade gracefully without it.
