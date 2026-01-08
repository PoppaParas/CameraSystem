-- @ScriptType: ModuleScript

local GlobalTableStore = {}

local Tables = {}


function GlobalTableStore:SetIndex(Name:string,Val)
	Tables[Name] = Val
end

function GlobalTableStore:GetIndex(Name:string)
	return Tables[Name]
end


return GlobalTableStore
