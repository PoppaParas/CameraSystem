-- @ScriptType: ModuleScript
--!optimize 2
local Operations = {}

type TypeDef = {
	Convert: (any) -> { number },
	Constructor: (...any) -> any,
}

local TYPE_DEFINITIONS: { [string]: TypeDef } = {
	CFrame = {
		Convert = function(cf: CFrame)
			-- returns {posX, posY, posZ, rotX, rotY, rotZ}
			local rx, ry, rz = cf:ToEulerAnglesYXZ()
			return { cf.X, cf.Y, cf.Z, rx, ry, rz }
		end,
		Constructor = function(...)
			local args = { ... }
			-- position then rotation
			return CFrame.new(args[1], args[2], args[3]) * CFrame.Angles(args[4], args[5], args[6])
		end,
	},

	UDim2 = {
		Convert = function(u: UDim2)
			-- returns {xScale, xOffset, yScale, yOffset}
			return { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset }
		end,
		Constructor = UDim2.new,
	},

	Vector3 = {
		Convert = function(v: Vector3)
			return { v.X, v.Y, v.Z }
		end,
		Constructor = Vector3.new,
	},

	Vector2 = {
		Convert = function(v: Vector2)
			return { v.X, v.Y }
		end,
		Constructor = Vector2.new,
	},

	Color3 = {
		Convert = function(c: Color3)
			return { c.R, c.G, c.B }
		end,
		Constructor = Color3.new,
	},
}

-- GetValidTypeName: returns the typeof() string if supported (including "number"), otherwise nil
local function GetValidTypeName(value: any): string?
	local valueType = typeof(value)

	if valueType == "number" then
		return "number"
	end

	if TYPE_DEFINITIONS[valueType] then
		return valueType
	end

	return nil
end

-- Operate: perform element-wise numeric operation on two values of the same supported type.
-- Example: Operations:Operate(Vector3.new(1,2,3), Vector3.new(4,5,6), function(a,b) return a + b end)
function Operations:Operate<T>(LeftHand: T, RightHand: T,OperatorFunc: (number, number) -> number): T
	assert(typeof(LeftHand) == typeof(RightHand), `type mismatch: {typeof(LeftHand)} ~= {typeof(RightHand)}`)

	local TypeName = GetValidTypeName(LeftHand)
	assert(TypeName, `unsupported type: {typeof(LeftHand)}`)


	if TypeName == "number" then
		-- operatorFn should return a number
		return OperatorFunc(LeftHand :: number, RightHand :: number) :: any
	end

	local DefinedType = TYPE_DEFINITIONS[TypeName]
	assert(DefinedType,`internal error: missing type def for {TypeName}`)

	local LeftParts = DefinedType.Convert(LeftHand :: any)
	local RightParts = DefinedType.Convert(RightHand :: any)

	


	local ResultParts: { number } = {}
	for Index = 1, #LeftParts do
		ResultParts[Index] = OperatorFunc(LeftParts[Index], RightParts[Index])
	end

	local Constructor = DefinedType.Constructor
	return Constructor(table.unpack(ResultParts))
end

-- Compare: element-wise boolean comparison for two values of the same supported type.
-- Returns true only if comparatorFn returns true for every corresponding pair.
function Operations:Compare<T>(LeftHand: T, RightHand: T, CompareFunc: (number, number) -> boolean): boolean
	assert(typeof(LeftHand) == typeof(RightHand), `type mismatch: {typeof(LeftHand)} ~= {typeof(RightHand)}`)

	local TypeName = GetValidTypeName(LeftHand)
	assert(TypeName, `unsupported type: {typeof(LeftHand)}`)

	if TypeName == "number" then
		return CompareFunc(LeftHand :: number, RightHand :: number)
	end

	local DefinedType = TYPE_DEFINITIONS[TypeName]
	assert(DefinedType,`internal error: missing type def for {TypeName}`)

	local LeftParts = DefinedType.Convert(LeftHand :: any)
	local RightParts = DefinedType.Convert(RightHand :: any)

	for Index = 1, #LeftParts do
		if not CompareFunc(LeftParts[Index], RightParts[Index]) then
			return false
		end
	end

	return true
end

return Operations