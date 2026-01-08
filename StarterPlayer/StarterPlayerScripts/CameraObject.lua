-- @ScriptType: LocalScript
--[[
═══════════════════════════════════════════════════════════════
	CUSTOM CAMERA SYSTEM
	Created by: Novus, omni_novus
	Date: 11/29/25
═══════════════════════════════════════════════════════════════
]]

--// Services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

--// Dependencies
local CamShaker = require(script:WaitForChild("CameraShaker"))
local Tweens = require(script.TweenManager)

--// Player Setup
repeat task.wait() until Players.LocalPlayer
local player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")

--[[
═══════════════════════════════════════════════════════════════
	CONFIGURATION
	Edit these values to customize camera behavior
═══════════════════════════════════════════════════════════════
]]

local CONFIG = {
	--// ZOOM SETTINGS
	Zoom = {
		Default = 10,              -- Starting zoom distance
		Target = 5,                -- Target zoom distance (lerps to this)
		Min = 5,                   -- Minimum zoom distance
		Max = 40,                  -- Maximum zoom distance
		ScrollSensitivity = 0.2,   -- How much scroll wheel affects zoom
		PinchSensitivity = 0.3,    -- How much pinch affects zoom (mobile)
	},

	--// CAMERA MOVEMENT SMOOTHING
	Smoothing = {
		Input = 0.36,              -- How fast camera rotates to input (lower = smoother)
		Zoom = 0.3,                -- How fast zoom changes (lower = smoother)
		Offset = 0.12,             -- How fast camera offset changes (lower = smoother)
		VelocityTracking = 0.23,   -- How fast camera tracks velocity (lower = smoother)
		FOV = 0.3,                 -- How fast FOV changes (lower = smoother)
		FineTune = 0.4,           -- How fast torso tilt applies (lower = smoother)
		LockOn = 0.5,              -- How fast camera tracks locked target (lower = smoother)
		LockOffset = 0.1,          -- How fast lock-on offset adjusts (lower = smoother)
		Cutscene = 0.3,            -- How fast cutscene camera moves (lower = smoother)
	},

	--// INPUT SETTINGS
	Input = {
		BaseSensitivity = 0.45 * 1/0.8,  -- Base mouse sensitivity
		MobileSensitivity = 2.1,         -- Mobile sensitivity multiplier
		GamepadSensitivity = 4.4,        -- Gamepad sensitivity multiplier
		MaxVerticalAngle = 0.9,          -- Maximum up/down look angle (0-1)
		MinVerticalAngle = -0.9,         -- Minimum up/down look angle (0-1, usually negative)
	},

	--// VELOCITY TRACKING
	Velocity = {
		Enabled = true,            -- Whether to track player velocity for camera movement
		Divider = 40,               -- Divides velocity for smoother tracking (higher = less movement)
		Limit = .6,                 -- Maximum velocity offset (multiplied by zoom)
		XYLimit = true,            -- Whether to limit X/Y velocity separately
		ZLimitMultiplier = 2,    -- Z-axis gets this much more range than X/Y
	},

	--// CAMERA OFFSETS
	Offsets = {
		Default = CFrame.new(0.5, 1, 0),                  -- Base camera offset
		ShiftLock = CFrame.new(1.5, 0.4, -1),            -- Offset when shift-locked
		Mode = CFrame.new(),                              -- Special mode offset (overrides all)
	},

	--// LOCK-ON TARGETING
	LockOn = {
		Enabled = true,                                   -- Whether lock-on system is enabled
		Offset = CFrame.new(5, 5, 25),                   -- Camera offset when locked on
		DistanceScaleMin = 0.6,                          -- Minimum distance scale
		DistanceScaleMax = 2,                            -- Maximum distance scale
		DistanceScaleDivider = 200,                      -- Divides target distance for scaling
	},

	--// FOV (FIELD OF VIEW)
	FOV = {
		Base = 70,                 -- Base field of view
		MaxSpeedBonus = 50,        -- Maximum FOV increase from speed
		SpeedDivider = 4,          -- Divides velocity for FOV calculation (higher = less FOV change)
	},

	--// FINE TUNING (Torso Tilt)
	FineTune = {
		Enabled = true,            -- Whether to apply subtle torso-based camera tilt
		Divider = 2,               -- Divides torso rotation for subtle effect (higher = less tilt)
		Multiplier = 0.02,         -- Further multiplies the effect (lower = less tilt)
	},

	--// SHIFT LOCK
	ShiftLock = {
		Enabled = true,            -- Whether shift lock is available
		Keybinds = {
			Flight = {},           -- Keybinds for shift lock during flight (empty = disabled)
			Default = {},          -- Keybinds for shift lock normally (empty = disabled)
		},
	},

	--// CUTSCENE
	Cutscene = {
		DefaultPoint = CFrame.new(0, 0, -5) * CFrame.Angles(0, math.pi, 0),
		LerpTime = 0.08,           -- Base lerp speed for cutscene transitions
	},
}

--[[
═══════════════════════════════════════════════════════════════
	CAMERA STATE
	Internal state - don't edit unless you know what you're doing
═══════════════════════════════════════════════════════════════
]]

local CameraObject = {
	--// Runtime State
	Events = {},
	Enabled = true,
	Running = false,
	Cam = nil,

	--// Zoom
	Zoom = CONFIG.Zoom.Default,
	TargZoom = CONFIG.Zoom.Target,
	MaxZoom = NumberRange.new(CONFIG.Zoom.Min, CONFIG.Zoom.Max),

	--// Offsets
	Offset = CONFIG.Offsets.Default,
	OffsetConfigs = {
		Default = CFrame.new(),
		ShiftLock = CONFIG.Offsets.ShiftLock,
		Mode = CONFIG.Offsets.Mode,
	},
	Offsets = {},
	CurrentOffset = CFrame.new(),
	OffsetType = "Default",

	--// Input Tracking
	TargetInput = Vector3.zero,
	CurrentInput = Vector3.zero,
	HoldingDown = false,

	--// Velocity Tracking
	VelocityDivide = CONFIG.Velocity.Divider,
	VelocityLimit = CONFIG.Velocity.Limit,
	CurrentVelTrack = Vector3.zero,
	TargetVelTrack = Vector3.zero,

	--// FOV
	CurrentFOV = CONFIG.FOV.Base,

	--// Lock-On
	LockedOn = nil,
	LockOffset = CONFIG.LockOn.Offset,
	LockCF = nil,

	--// Shift Lock
	ShiftLock = false,
	ShiftLockKeybinds = CONFIG.ShiftLock.Keybinds,
	BaseSensitivity = CONFIG.Input.BaseSensitivity,

	--// Fine Tuning
	FinePartTuneDivider = CONFIG.FineTune.Divider,
	FineTuneMulti = CONFIG.FineTune.Multiplier,
	UseFineTuning = CONFIG.FineTune.Enabled,

	--// Cutscene
	Cutscene = {
		Type = "Character",
		Enabled = false,
		Offsets = {},
		Target = nil,
	},
	CutscenePoint = CONFIG.Cutscene.DefaultPoint,

	--// Shake
	ShakeOffset = CFrame.new(),
	ShakeObject = nil,

	--// Settings
	Settings = nil,
	GameSettings = nil,
}

--[[
═══════════════════════════════════════════════════════════════
	HELPER FUNCTIONS
═══════════════════════════════════════════════════════════════
]]

--// Get user settings
local function SetGameSettings()
	if CameraObject.GameSettings then return CameraObject.GameSettings end
	CameraObject.Settings = UserSettings()
	CameraObject.GameSettings = CameraObject.Settings.GameSettings
	return CameraObject.GameSettings
end

--// Check if shift lock is enabled in settings
local function GetShiftLockEnabled()
	if not CONFIG.ShiftLock.Enabled then return false end
	local GameSettings: UserGameSettings = CameraObject.GameSettings
	return true -- Simplified - always allow shift lock if config enables it
end

--// Determine shift lock type based on character state
local function GetShiftlockType()
	-- Add your character state checking here
	-- Example: if flying, return "Flight", else return "Default"
	return "Default"
end

--// Safely get part from humanoid
local function GetPartFromSubject(Subject: Humanoid): BasePart
	return Subject and Subject.Parent and Subject.Parent:FindFirstChild("HumanoidRootPart")
end

--// Calculate velocity-based camera offset
local function GetVelocityOffset(primaryPart: BasePart, cameraCFrame: CFrame): Vector3
	-- Convert world-space velocity to camera's local space
	local localVel = cameraCFrame:VectorToObjectSpace(
		primaryPart.AssemblyLinearVelocity / CONFIG.Velocity.Divider
	)

	-- Apply axis-specific limits
	local xyLimit = math.abs(CONFIG.Velocity.Limit * CameraObject.Zoom)
	local zLimit = xyLimit * CONFIG.Velocity.ZLimitMultiplier

	localVel = Vector3.new(
		math.clamp(localVel.X, -xyLimit, xyLimit),
		math.clamp(localVel.Y, -xyLimit, xyLimit),
		-math.abs(math.clamp(localVel.Z, -zLimit, zLimit))
	)

	return -localVel
end

--// Calculate FOV based on velocity
local function GetFOV(primaryPart: BasePart): number
	local speedBonus = math.clamp(
		primaryPart.AssemblyLinearVelocity.Magnitude / CONFIG.FOV.SpeedDivider - CONFIG.FOV.Base,
		0,
		CONFIG.FOV.MaxSpeedBonus
	)
	return CONFIG.FOV.Base + speedBonus
end

--// Clean up NaN values
local function SanitizeValue(value, default)
	if typeof(value) == "number" then
		return value == value and value or (default or 0)
	elseif typeof(value) == "Vector3" then
		return value == value and value or (default or Vector3.zero)
	elseif typeof(value) == "CFrame" then
		return value == value and value or (default or CFrame.new())
	end
	return value
end

--[[
═══════════════════════════════════════════════════════════════
	CAMERA CUTSCENE CONTROL
═══════════════════════════════════════════════════════════════
]]

local CamTask: thread

function CameraObject:LerpCutscene(targetCF: CFrame, duration: number)
	if CamTask then
		coroutine.close(CamTask)
	end

	CamTask = task.spawn(function()
		local startTime = os.clock()
		local endTime = startTime + duration
		local lastTime = startTime

		while os.clock() < endTime do
			if not CameraObject.Cutscene.Enabled then return end

			local deltaTime = os.clock() - lastTime
			lastTime = os.clock()

			local alpha = (CONFIG.Cutscene.LerpTime / duration) ^ (1 - deltaTime)
			CameraObject.CutscenePoint = CameraObject.CutscenePoint:Lerp(targetCF, alpha)

			task.wait()
		end

		CameraObject.CutscenePoint = targetCF
	end)
end

--[[
═══════════════════════════════════════════════════════════════
	INPUT HANDLING
═══════════════════════════════════════════════════════════════
]]

local function SetupInputHandling()
	local GameSettings = SetGameSettings()
	local touchGui: ScreenGui
	local IgnoreInput: InputObject
	local XBTask: thread
	local lastTime = os.clock()

	--// Handle gamepad thumbstick input
	local function SetXBTask(vector: Vector2?)
		if XBTask then
			task.cancel(XBTask)
		end
		if not vector then return end

		XBTask = task.spawn(function()
			local lastUpdate = os.clock()
			while true do
				local deltaTime = os.clock() - lastUpdate
				lastUpdate = os.clock()

				local adjustment = Vector3.new(vector.X, vector.Y, 0) 
					* deltaTime 
					* CONFIG.Input.BaseSensitivity 
					* Vector3.new(-1, -1, 1) 
					* 2

				local newInput = CameraObject.TargetInput + adjustment
				newInput = Vector3.new(
					newInput.X,
					math.clamp(newInput.Y, CONFIG.Input.MinVerticalAngle, CONFIG.Input.MaxVerticalAngle),
					newInput.Z
				)
				CameraObject.TargetInput = newInput

				task.wait()
			end
		end)
	end

	--// Update shift lock state
	local function UpdateShiftLock()
		if not GetShiftLockEnabled() then return end

		if CameraObject.ShiftLock then
			if CameraObject.OffsetType ~= "Mode" then
				CameraObject.OffsetType = "ShiftLock"
			end
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		else
			CameraObject.OffsetType = "Default"
			if not CameraObject.HoldingDown then
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end
		end
	end

	--// Input Began
	table.insert(CameraObject.Events, UserInputService.InputBegan:Connect(function(input, focused)
		GameSettings = SetGameSettings()
		local shiftLockType = GetShiftlockType()

		if focused then
			if input.UserInputType == Enum.UserInputType.Touch then
				IgnoreInput = input
			end
			return
		end

		-- Right click or touch to rotate camera
		if input.UserInputType == Enum.UserInputType.MouseButton2 
			or input.UserInputType == Enum.UserInputType.Touch then
			CameraObject.HoldingDown = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition

			-- Shift lock keybinds
		elseif table.find(CameraObject.ShiftLockKeybinds[shiftLockType], input.KeyCode) then
			CameraObject.ShiftLock = not CameraObject.ShiftLock
			UpdateShiftLock()
		end
	end))

	--// Touch Pinch (Mobile Zoom)
	table.insert(CameraObject.Events, UserInputService.TouchPinch:Connect(function(positions, scale, velocity, state, focused)
		if focused then return end

		CameraObject.TargZoom += (scale - 1) * -CONFIG.Zoom.PinchSensitivity
		CameraObject.TargZoom = math.clamp(CameraObject.TargZoom, CONFIG.Zoom.Min, CONFIG.Zoom.Max)
	end))

	--// Input Ended
	table.insert(CameraObject.Events, UserInputService.InputEnded:Connect(function(input)
		GameSettings = SetGameSettings()
		UpdateShiftLock()

		if input.UserInputType == Enum.UserInputType.MouseButton2 
			or input.UserInputType == Enum.UserInputType.Touch then
			CameraObject.HoldingDown = false
			if not CameraObject.ShiftLock then
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end
		end

		if input.KeyCode == Enum.KeyCode.Thumbstick2 then
			SetXBTask()
		end
	end))

	--// Input Changed
	table.insert(CameraObject.Events, UserInputService.InputChanged:Connect(function(input, focused)
		GameSettings = SetGameSettings()
		UpdateShiftLock()

		-- Mouse/Touch Camera Rotation
		if (input.UserInputType == Enum.UserInputType.MouseMovement 
			or input.UserInputType == Enum.UserInputType.Touch)
			and (CameraObject.HoldingDown or CameraObject.ShiftLock)
			and not focused then

			-- Ignore touch input on thumbstick
			touchGui = playerGui:FindFirstChild("TouchGui")
			if touchGui then
				local TouchControlFrame = touchGui:FindFirstChild("TouchControlFrame")
				if TouchControlFrame then
					TouchControlFrame = TouchControlFrame:FindFirstChild("ThumbstickFrame")
					if TouchControlFrame then
						local touchPos = Vector2.new(input.Position.X, input.Position.Y)
						local distance = (touchPos - TouchControlFrame.AbsolutePosition).Magnitude
						if distance < (TouchControlFrame.AbsoluteSize.Magnitude * 1.1) then
							return
						end
					end
				end
			end

			if input == IgnoreInput then return end

			-- Platform-specific sensitivity
			local platformMultiplier = 1
			if UserInputService.TouchEnabled then
				platformMultiplier = CONFIG.Input.MobileSensitivity
			elseif UserInputService.GamepadEnabled then
				platformMultiplier = CONFIG.Input.GamepadSensitivity
			end

			-- Calculate new input
			local deltaTime = os.clock() - lastTime
			local adjustment = input.Delta 
				* deltaTime 
				* CONFIG.Input.BaseSensitivity 
				* Vector3.new(-1, 1, 1) 
				* platformMultiplier

			local newInput = CameraObject.TargetInput + adjustment
			newInput = Vector3.new(
				newInput.X,
				math.clamp(newInput.Y, CONFIG.Input.MinVerticalAngle, CONFIG.Input.MaxVerticalAngle),
				newInput.Z
			)
			CameraObject.TargetInput = newInput
			lastTime = os.clock()

			-- Mouse Wheel Zoom
		elseif not focused and input.UserInputType == Enum.UserInputType.MouseWheel then
			local zoomChange = input.Position.Z 
				* (CONFIG.Zoom.Min + CONFIG.Zoom.Max) / 2 
				* CONFIG.Zoom.ScrollSensitivity

			CameraObject.TargZoom -= zoomChange
			CameraObject.TargZoom = math.clamp(CameraObject.TargZoom, CONFIG.Zoom.Min, CONFIG.Zoom.Max)

			-- Gamepad Thumbstick
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			local pos = input.Position
			if pos.Magnitude < 0.4 then
				SetXBTask()
			else
				SetXBTask(Vector2.new(pos.X, pos.Y))
			end
		end
	end))
end

--[[
═══════════════════════════════════════════════════════════════
	CAMERA UPDATE LOOP
═══════════════════════════════════════════════════════════════
]]

local function SetupCameraLoop()
	local Cam = CameraObject.Cam
	local PrimPart: BasePart
	local Torso: BasePart
	local CurrFine = CFrame.new()
	local CurrPoint = CameraObject.CutscenePoint
	local BaseZoom = 1
	local TargZoom = BaseZoom
	local NewLockOffset = CameraObject.LockOffset

	table.insert(CameraObject.Events, RunService.PreRender:Connect(function(deltaTime)
		-- Lerp cutscene point
		CurrPoint = CurrPoint:Lerp(CameraObject.CutscenePoint, CONFIG.Smoothing.Cutscene ^ (1 - deltaTime))

		CameraObject.Cam = workspace.CurrentCamera
		Cam = CameraObject.Cam
		if not Cam or not CameraObject.Enabled then return end

		-- Sanitize all numeric values to prevent NaN
		for key, value in CameraObject do
			CameraObject[key] = SanitizeValue(value, value)
		end

		-- Calculate total offset from all offset sources
		local TotalOffset = CFrame.new()
		for name, offset in CameraObject.Offsets do
			if name == "Mode" then continue end
			TotalOffset *= offset
		end
		if CameraObject.Offsets.Mode then
			TotalOffset = CFrame.new()
		end

		-- Smooth zoom
		BaseZoom += (TargZoom - BaseZoom) * CONFIG.Smoothing.Zoom ^ (1 - deltaTime)

		-- Get player's primary part
		PrimPart = GetPartFromSubject(Cam.CameraSubject)
		if not PrimPart or not PrimPart.Parent then return end

		Torso = PrimPart.Parent:FindFirstChild("UpperTorso") or PrimPart.Parent:FindFirstChild("Torso")
		Cam.CameraType = Enum.CameraType.Scriptable

		local primPartCF = PrimPart.CFrame
		local Hum: Humanoid = Cam.CameraSubject

		-- Apply shift lock rotation to character
		if CameraObject.ShiftLock then
			local lookVector = Cam.CFrame.LookVector
			PrimPart.CFrame = CFrame.new(PrimPart.Position) 
				* CFrame.Angles(0, math.atan2(-lookVector.X, -lookVector.Z), 0)
		end

		-- Calculate velocity tracking
		if CONFIG.Velocity.Enabled then
			CameraObject.TargetVelTrack = GetVelocityOffset(PrimPart, workspace.CurrentCamera.CFrame)
			CameraObject.TargetVelTrack = SanitizeValue(CameraObject.TargetVelTrack, Vector3.zero)

			-- Clamp velocity magnitude
			local maxVel = math.abs(CONFIG.Velocity.Limit * CameraObject.Zoom)
			if CameraObject.TargetVelTrack.Magnitude > maxVel then
				CameraObject.TargetVelTrack = CameraObject.TargetVelTrack.Unit * maxVel
			end
		else
			CameraObject.TargetVelTrack = Vector3.zero
		end

		-- Update FOV
		CameraObject.CurrentFOV += (GetFOV(PrimPart) - CameraObject.CurrentFOV) 
			* CONFIG.Smoothing.FOV ^ (1 - deltaTime)

		-- Smooth velocity tracking
		CameraObject.CurrentVelTrack += (CameraObject.TargetVelTrack - CameraObject.CurrentVelTrack) 
			* CONFIG.Smoothing.VelocityTracking ^ (1 - deltaTime)
		CameraObject.CurrentVelTrack = SanitizeValue(CameraObject.CurrentVelTrack, Vector3.zero)

		-- Smooth input
		CameraObject.CurrentInput += (CameraObject.TargetInput - CameraObject.CurrentInput) 
			* CONFIG.Smoothing.Input ^ (1 - deltaTime / 1.1)

		-- Smooth zoom
		CameraObject.Zoom += (CameraObject.TargZoom - CameraObject.Zoom) 
			* CONFIG.Smoothing.Zoom ^ (1 - deltaTime)

		-- Calculate camera position from input
		local currentPos = Vector3.new(
			math.sin(CameraObject.CurrentInput.X),
			CameraObject.CurrentInput.Y,
			math.cos(CameraObject.CurrentInput.X)
		) * Vector3.new(
			math.cos(CameraObject.CurrentInput.Y),
			1,
			math.cos(CameraObject.CurrentInput.Y)
		) * CameraObject.Zoom

		-- Smooth offset
		local targetOffset = CameraObject.Offset 
			* CameraObject.OffsetConfigs[CameraObject.OffsetType] 
			* TotalOffset
		CameraObject.CurrentOffset = CameraObject.CurrentOffset:Lerp(
			targetOffset,
			CONFIG.Smoothing.Offset ^ (1 - deltaTime * 1.3)
		)
		CameraObject.CurrentOffset = SanitizeValue(CameraObject.CurrentOffset, targetOffset)

		-- Calculate torso fine-tuning
		local TorsCF = CFrame.new()
		if Torso and CONFIG.FineTune.Enabled then
			local mod:Model = PrimPart.Parent
			local cf = mod:GetBoundingBox()
			TorsCF = Torso.CFrame:ToObjectSpace(cf)
			local X, Y, Z = TorsCF:ToEulerAngles(Enum.RotationOrder.XYZ)
			local divider = CONFIG.FineTune.Divider / CONFIG.FineTune.Multiplier

			X, Y, Z = X / divider, Y / divider, Z / divider
			local Pos = TorsCF.Position / divider

			local targetFine = CFrame.new(Pos) * CFrame.Angles(X, Y, Z)
			CurrFine = CurrFine:Lerp(targetFine, CONFIG.Smoothing.FineTune ^ (1 - deltaTime))
			TorsCF = CurrFine
		end

		local currentHumPos = primPartCF.Position
		currentHumPos = SanitizeValue(currentHumPos, Vector3.zero)

		Cam.FieldOfView = CameraObject.CurrentFOV

		-- CUTSCENE MODE
		if CameraObject.Cutscene.Enabled then
			local targetPos = CameraObject.Cutscene.Target and CameraObject.Cutscene.Target:GetPivot() or CFrame.new()
			Cam.CFrame = targetPos * CameraObject.CutscenePoint * CameraObject.ShakeOffset

			-- LOCK-ON MODE
		elseif CameraObject.LockedOn and CameraObject.LockedOn:FindFirstChild("HumanoidRootPart") then
			local LockPart: BasePart = CameraObject.LockedOn:FindFirstChild("HumanoidRootPart")

			-- Initialize lock position
			if not CameraObject.LockCF then
				local distance = (LockPart.Position - Cam.CFrame.Position).Magnitude
				CameraObject.LockCF = Cam.CFrame * CFrame.new(0, 0, -distance)
			end

			-- Smooth lock-on tracking
			local distance = (primPartCF.Position - CameraObject.LockCF.Position).Magnitude
			CameraObject.LockCF = CameraObject.LockCF:Lerp(
				LockPart.CFrame,
				CONFIG.Smoothing.LockOn ^ (1 - deltaTime)
			)

			-- Scale offset based on distance
			local scale = math.clamp(
				distance / CONFIG.LockOn.DistanceScaleDivider,
				CONFIG.LockOn.DistanceScaleMin,
				CONFIG.LockOn.DistanceScaleMax
			)
			local targetLockOffset = CFrame.new(CameraObject.LockOffset.Position * scale)
			NewLockOffset = NewLockOffset:Lerp(
				targetLockOffset,
				CONFIG.Smoothing.LockOffset ^ (1 - deltaTime)
			)

			Cam.CFrame = CFrame.new(CameraObject.LockCF.Position, CameraObject.LockCF.Position)
				* CameraObject.CurrentOffset
				* NewLockOffset
				* CFrame.new(CameraObject.CurrentVelTrack)
				* CameraObject.ShakeOffset
				* TorsCF

			-- NORMAL MODE
		else
			CameraObject.LockCF = nil
			Cam.CFrame = CFrame.new(currentHumPos + currentPos, currentHumPos)
				* CameraObject.CurrentOffset
				* CFrame.new(CameraObject.CurrentVelTrack)
				* CameraObject.ShakeOffset
				* TorsCF
		end
	end))
end

--[[
═══════════════════════════════════════════════════════════════
	INITIALIZATION
═══════════════════════════════════════════════════════════════
]]

function CameraObject:Start()
	CameraObject.Running = true
	CameraObject.CurrentOffset = CameraObject.Offset

	repeat task.wait() until player.Character

	SetGameSettings()
	SetupInputHandling()
	SetupCameraLoop()

	-- Setup camera shake
	CameraObject.ShakeObject = CamShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCF: CFrame)
		CameraObject.ShakeOffset = shakeCF
	end)
	CameraObject.ShakeObject:Start()
	CameraObject.Instances = CamShaker.CameraShakeInstance
	CameraObject.Presets = CamShaker.Presets

	-- Expose shake methods
	for name, func in CamShaker do
		if typeof(func) == "function" then
			CameraObject[name] = function(...)
				local args = {...}
				if args[1] == CameraObject then
					table.remove(args, 1)
				end
				return CameraObject.ShakeObject[name](CameraObject.ShakeObject, unpack(args))
			end
		end
	end

	_G.Cam = CameraObject
end

task.spawn(function()
	CameraObject:Start()
end)

return CameraObject