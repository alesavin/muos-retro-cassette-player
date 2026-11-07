-- The handheld's battery, shown as a short coloured line in the key row,
-- between STOP/EJECT and PLAY on both screens: its length is the charge,
-- green, yellow below HALF and red below LOW. While charging, a bright
-- segment runs along it. The charge is read from sysfs: the files muOS names
-- for the device (passed in by mux_launch.sh), else the first battery under
-- /sys/class/power_supply.
local Battery = {}

Battery.POLL = 30 -- seconds between reads
Battery.LOW = 20 -- percent: below this the line is red
Battery.HALF = 45 -- percent: below this it is yellow
Battery.STEP = 0.2 -- seconds between moves of the charging segment
Battery.STEPS = 8 -- positions along the line per sweep
Battery.SYSFS = "/sys/class/power_supply"

-- Where the line sits: its centre, in canvas pixels, and its size.
Battery.X, Battery.Y = 445, 462
Battery.W, Battery.H = 50, 6

local capacityPath, chargerPath, statusPath
local lastRead, lastStep = -math.huge, -math.huge

Battery.level = nil -- 0..100, nil when there is no battery (a desktop)
Battery.charging = false
Battery.phase = 0 -- 0 .. STEPS-1: where the charging segment is

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
	lastRead, lastStep = -math.huge, -math.huge
	return capacityPath ~= nil
end

-- Reads the battery every POLL seconds and, while charging, moves the
-- segment every STEP seconds. Returns true when what's shown changed.
function Battery.update(now)
	if not capacityPath then
		return false
	end
	local changed = false
	if now - lastRead >= Battery.POLL then
		lastRead = now
		local level = tonumber(readLine(capacityPath))
		level = level and math.max(0, math.min(100, level)) or nil
		local charging
		if readLine(chargerPath) then
			charging = readLine(chargerPath) == "1"
		else
			charging = readLine(statusPath) == "Charging"
		end
		changed = level ~= Battery.level or charging ~= Battery.charging
		Battery.level, Battery.charging = level, charging
	end
	if Battery.charging and Battery.level and now - lastStep >= Battery.STEP then
		lastStep = now
		Battery.phase = (Battery.phase + 1) % Battery.STEPS
		changed = true
	end
	return changed
end

function Battery.color(level)
	if level < Battery.LOW then
		return 0.95, 0.22, 0.15
	elseif level < Battery.HALF then
		return 1.0, 0.78, 0.15
	end
	return 0.35, 0.85, 0.30
end

function Battery.draw()
	if not Battery.level then
		return
	end
	local lg = love.graphics
	local w, h = Battery.W, Battery.H
	local x, y = Battery.X - w / 2, Battery.Y - h / 2
	local r, g, b = Battery.color(Battery.level)
	lg.setColor(0, 0, 0, 0.45)
	lg.rectangle("fill", x - 1, y - 1, w + 2, h + 2, 3, 3)
	lg.setColor(r, g, b, 0.18)
	lg.rectangle("fill", x, y, w, h, 3, 3)
	local filled = math.max(h, w * Battery.level / 100)
	lg.setColor(r, g, b)
	lg.rectangle("fill", x, y, filled, h, 3, 3)
	if Battery.charging then
		local seg = math.min(10, filled)
		local sx = x + (filled - seg) * Battery.phase / (Battery.STEPS - 1)
		lg.setColor(1, 1, 1, 0.75)
		lg.rectangle("fill", sx, y, seg, h, 3, 3)
	end
end

return Battery
