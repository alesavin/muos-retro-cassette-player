function love.conf(t)
	t.identity = "retrocassette"
	t.version = "11.4"
	t.window.title = "Retro Cassette"
	t.window.width = 720
	t.window.height = 480
	t.window.resizable = true
	-- The launcher sets RC_FULLSCREEN on the device; on a desktop the app opens in a window.
	t.window.fullscreen = os.getenv("RC_FULLSCREEN") == "1"
	t.window.vsync = 1

	t.modules.physics = false
	t.modules.video = false
	t.modules.touch = false
end
