-- The handheld's battery, drawn as a status-bar icon in the top-right corner
-- like muOS's own (on the player it sits on the cassette's top edge). The
-- charge is read from sysfs: the files muOS names for the device (passed in
-- by mux_launch.sh), else the first battery under /sys/class/power_supply.
local Battery = {}

Battery.POLL = 30 -- seconds between reads
Battery.LOW = 20 -- percent: below this the fill turns red
Battery.SYSFS = "/sys/class/power_supply"

local capacityPath, chargerPath, statusPath
local lastRead = -math.huge

Battery.level = nil -- 0..100, nil when there is no battery (a desktop)
Battery.charging = false

local function readLine(path)
	local f = path and path ~= "" and io.open(path, "r")
	if not f then
		return nil
	end
	local s = f:read("*l")
	f:close()
	return s
end

-- Finds the files to read. env: a function like os.getenv.
function Battery.find(env)
	env = env or os.getenv
	capacityPath = env("RC_BATTERY_CAPACITY")
	chargerPath = env("RC_BATTERY_CHARGER")
	statusPath = nil
	Battery.level, Battery.charging = nil, false
	if not readLine(capacityPath) then
		capacityPath = nil
		local p = io.popen("ls '" .. Battery.SYSFS .. "' 2>/dev/null")
		local names = p and p:read("*a") or ""
		if p then
			p:close()
		end
		for name in names:gmatch("[^\n]+") do
			local dir = Battery.SYSFS .. "/" .. name
			if readLine(dir .. "/type") == "Battery" and readLine(dir .. "/capacity") then
				capacityPath = dir .. "/capacity"
				statusPath = dir .. "/status"
				break
			end
		end
	elseif capacityPath:match("/capacity$") then
		statusPath = capacityPath:gsub("/capacity$", "/status")
	end
	lastRead = -math.huge
	return capacityPath ~= nil
end

-- Reads the battery every POLL seconds. Returns true when what's shown changed.
function Battery.update(now)
	if not capacityPath or now - lastRead < Battery.POLL then
		return false
	end
	lastRead = now
	local level = tonumber(readLine(capacityPath))
	level = level and math.max(0, math.min(100, level)) or nil
	local charging
	if readLine(chargerPath) then
		charging = readLine(chargerPath) == "1"
	else
		local status = readLine(statusPath)
		charging = status == "Charging" or status == "Full"
	end
	local changed = level ~= Battery.level or charging ~= Battery.charging
	Battery.level, Battery.charging = level, charging
	return changed
end

-- Draws the icon centred on (cx, cy), s times its normal size (34x17 plus the nub).
function Battery.draw(cx, cy, s)
	if not Battery.level then
		return
	end
	local lg = love.graphics
	s = s or 1
	lg.push()
	lg.translate(cx, cy)
	lg.scale(s)
	local w, h = 34, 17
	local x, y = -w / 2 - 2, -h / 2
	lg.setColor(0, 0, 0, 0.35)
	lg.rectangle("fill", x + 1, y + 2, w + 4, h, 3, 3)
	lg.setColor(0.93, 0.93, 0.93)
	lg.setLineWidth(2)
	lg.rectangle("line", x, y, w, h, 3, 3)
	lg.rectangle("fill", x + w + 1, y + 5, 3, h - 10, 1, 1)
	lg.setLineWidth(1)
	if Battery.charging then
		lg.setColor(0.35, 0.85, 0.35)
	elseif Battery.level < Battery.LOW then
		lg.setColor(0.95, 0.20, 0.15)
	end
	lg.rectangle("fill", x + 3, y + 3, (w - 6) * math.max(0.06, Battery.level / 100), h - 6, 1, 1)
	if Battery.charging then
		-- A lightning bolt: two triangles (LÖVE fills only convex polygons).
		local c = x + w / 2
		lg.setColor(0.10, 0.10, 0.10, 0.6)
		lg.polygon("fill", c + 4, y + 1, c - 7, 2, c + 2, 2)
		lg.polygon("fill", c - 4, y + h - 1, c + 7, -2, c - 2, -2)
		lg.setColor(1, 0.9, 0.2)
		lg.polygon("fill", c + 3, y + 3, c - 5, 1, c + 1, 1)
		lg.polygon("fill", c - 3, y + h - 3, c + 5, -1, c - 1, -1)
	end
	lg.pop()
end

return Battery
