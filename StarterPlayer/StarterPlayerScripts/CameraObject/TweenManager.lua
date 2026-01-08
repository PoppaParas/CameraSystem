-- @ScriptType: ModuleScript
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Core = script

local Operations = require(Core:WaitForChild("Operations"))
local List = require(Core:WaitForChild("List"))

local GlobalTableStore = require(Core:WaitForChild("GlobalTableStore"))

local TweenManager = {}
local CurrentTweens = List.new()
GlobalTableStore:SetIndex("TweenList",CurrentTweens)




export type TweenValues<T1> = {
	Values:{T1},
	ChangeFunc:(T1)->any|nil,
	Time:number,
	Attribute:boolean?,
	Property:string
}

function smoothDampAdvanced(current, target, currentVelocity, smoothTime, maxSpeed, dt)
	smoothTime = math.max(0.0001, smoothTime)
	local omega = 2 / smoothTime

	local x = omega * dt
	local exp = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)

	local change = current - target
	local originalTo = target

	--local maxChange = maxSpeed * smoothTime
	--change = math.clamp(change, -maxChange, maxChange)
	target = current - change

	local temp = (currentVelocity + omega * change) * dt
	currentVelocity = (currentVelocity - omega * temp) * exp
	local output = target + (change + temp) * exp

	-- Prevent overshooting
	if (originalTo - current > 0) == (output > originalTo) then
		output = originalTo
		currentVelocity = (output - originalTo) / dt
	end

	return output, currentVelocity
end

function TweenSmoothLerp<T1>(Current:T1,Target:T1,SmoothTime:number, Delta:number)
	SmoothTime = math.max(0.0001, SmoothTime)
	local Omega = 2 / SmoothTime

	local x = Omega * Delta
	local exp = 1 / (1 + x + 0.6 * x^2 + 0.235 * x^3)

	local Power = (.2/SmoothTime)^(1-Delta)
	return Operations:Operate(Current,Target,function(Num1,Num2)
		return Num1 + (Num2 - Num1) * Power
	end)


end



function TweenManager:Tween<T1,T2>(Object:T2,Config:TweenValues<T1>)
	local ObjectType = typeof(Object)
	assert(ObjectType == "table" or ObjectType == "Instance",`Unsupported Type. Object Type: {ObjectType}`)
	assert(type(Config) == "table",`Config doesn't exist or is an unsupported type`)
	assert(Config.Values and Config.Time, `Config is messed up in one argument.\n Config: {Config}`)
	local NewList : List.ListObjectType<string,thread> = CurrentTweens:Find(Object)
	if not NewList then
		NewList = List.new()
		NewList:SetReplacementFunc(function(Index,Value,OldValue:thread)
			if typeof(OldValue) ~= "thread" then return end
			task.cancel(OldValue)
		end)
		CurrentTweens:Set(Object,NewList)
	end
	--print("\n\n\n\n\n\n\n\n\n\n\n\n NEWPROP")
	NewList:Set(Config.Property,task.spawn(function()
		local Start = os.clock()
		local TimePerEach = Config.Time/#(Config.Values)
		local LastRan = Start
		local Delta = 0
		local Pos,Vel
		task.wait()
		while os.clock() - Start < Config.Time do
			Delta = os.clock() - LastRan
			LastRan = os.clock()
			local Index = math.ceil((os.clock() - Start)/TimePerEach)
			Index = math.min(Index,#(Config.Values))
			local IndexVal:T1 = Config.Values[Index]
			local Current:T1 = Config.Attribute and Object:GetAttribute(Config.Property) or Object[Config.Property]

			Pos = TweenSmoothLerp(Current,IndexVal,TimePerEach,Delta)
			--print(Pos)
			if Config.Attribute then
				Object:SetAttribute(Config.Property,Pos)
			else
				Object[Config.Property] = Pos
			end
			task.wait()

		end
	end))



end

return TweenManager
