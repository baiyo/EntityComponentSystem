local Players = game:GetService("Players")

local UniqueCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890"
local StateMachineFolder = game:GetService("ServerStorage").SS_Assets.Modules.Components.StateMachines

local EntityComponentManager = {
	Entities = {},
	Attributes = {},
}

local function CreateUniqueID()
	local id = ""
	for _ = 1, 8 do
		id = id .. UniqueCharacters:sub(math.random(1, #UniqueCharacters), math.random(1, #UniqueCharacters))
	end
	return id
end

local function CreateStateMachine(entity, stateModule)
	local machine = {}
	local states = require(stateModule)

	local prototype = {
		CurrentState = nil,
		States = states,
		StateHistory = {},

		SetState = function(self, newState, ...)
			local state = self.States[newState]
			if not state then
				return
			end

			if self.CurrentState and self.CurrentState.Exit then
				self.CurrentState.Exit(entity.Player or entity.Character, ...)
			end

			self.CurrentState = state
			if entity.Player then
				entity.Player:SetAttribute("CurrentState", newState)
			end
			entity.Character:SetAttribute("CurrentState", newState)

			if state.Enter then
				state.Enter(entity.Player or entity.Character, ...)
			end
		end,

		Trigger = function(self, action, ...)
			if not self.CurrentState then
				return
			end
			if not self.CurrentState[action] then
				return
			end

			self.CurrentState[action](entity.Player or entity.Character, ...)

			local nextState = self.CurrentState[action .. "NextState"]
			if nextState then
				self:SetState(nextState, ...)
			end
		end,
	}

	setmetatable(machine, {
		__index = prototype,
		__call = function(self, ...)
			return prototype.new(self, ...)
		end,
	})

	machine:SetState("Idle")
	return machine
end

function EntityComponentManager:CreateEntity(source, behaviorModule, data)
	if not source:FindFirstChild("Humanoid") and not source:IsA("Player") then
		return
	end

	local Character = source
	local IsPlayer = false

	if game.Players:GetPlayerFromCharacter(Character) then
		source = game.Players:GetPlayerFromCharacter(Character)
		IsPlayer = true
	end

	local entityId = CreateUniqueID()
	local entity = {
		Player = source,
		Character = Character,
		StateMachine = nil,
		Data = data,
	}

	entity.StateMachine = CreateStateMachine(entity, StateMachineFolder:FindFirstChild(behaviorModule))
	self.Entities[entityId] = entity

	if IsPlayer then
		source:SetAttribute("EntityID", entityId)
	end
	entity.Character:SetAttribute("EntityID", entityId)

	for attrName, attrValue in pairs(self.Attributes) do
		entity.Character:SetAttribute(attrName, attrValue)
	end

	if data.Weapon then
		entity.Character:SetAttribute("Weapon", data.Weapon.Value)
	end

	if entity.Character:FindFirstChildOfClass("Humanoid") then
		entity.Character.Humanoid.Died:Connect(function()
			self:DestroyEntity(entityId)
		end)
	end

	return entity
end

function EntityComponentManager:DestroyEntity(entityId)
	local entity = self.Entities[entityId]
	if not entity then
		return
	end

	if entity.Player then
		entity.Player:SetAttribute("EntityID", nil)
		entity.Player:SetAttribute("CurrentState", nil)
	end
	entity.Character:SetAttribute("EntityID", nil)
	entity.Character:SetAttribute("CurrentState", nil)

	self.Entities[entityId] = nil
end

function EntityComponentManager:SetState(entityId, newState, ...)
	local entity = self.Entities[entityId]
	if entity and entity.StateMachine then
		entity.StateMachine:SetState(newState, ...)
	end
end

function EntityComponentManager:TriggerAction(entityId, action, ...)
	local entity = self.Entities[entityId]
	if entity and entity.StateMachine then
		entity.StateMachine:Trigger(action, ...)
	end
end

function EntityComponentManager:GetEntity(entityId)
	return self.Entities[entityId]
end


return EntityComponentManager
