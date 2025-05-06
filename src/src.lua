local Players = game:GetService("Players")

local UniqueCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890"
local StateMachineFolder = game.path.to.StateMachines

local EntityManager = {
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
				self.CurrentState.Exit(entity, ...)
			end

			self.CurrentState = state
			entity.Player:SetAttribute("CurrentState", newState)
			entity.Character:SetAttribute("CurrentState", newState)

			if state.Enter then
				state.Enter(entity, ...)
			end
		end,

		Trigger = function(self, action, ...)
			if not self.CurrentState then
				return
			end
			if not self.CurrentState[action] then
				return
			end

			self.CurrentState[action](entity, ...)

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

function EntityManager:CreateEntity(source, isPlayer, behaviorModule, data)
	if not source:FindFirstChild("Humanoid") and not source:IsA("Player") then
		return
	end

	local Character = source

	if source:IsA("Player") then
		Character = source.Character
	end

	local entityId = CreateUniqueID()
	local entity = {
		Id = entityId,
		Player = source,
		Character = Character,
		StateMachine = nil,
		Data = data or {},
	}

	entity.StateMachine = CreateStateMachine(entity, StateMachineFolder:FindFirstChild(behaviorModule))
	self.Entities[entityId] = entity

	if isPlayer then
		source:SetAttribute("EntityID", entityId)
	end
	entity.Character:SetAttribute("EntityID", entityId)

	for attrName, attrValue in pairs(self.Attributes) do
		entity.Character:SetAttribute(attrName, attrValue)
	end

	if data.Weapon then
		entity.Character:SetAttribute("Weapon", data.Weapon)
	end

	if entity.Character:FindFirstChildOfClass("Humanoid") then
		entity.Character.Humanoid.Died:Connect(function()
			self:DestroyEntity(entityId)
		end)
	end

	return entity
end

function EntityManager:DestroyEntity(entityId)
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

function EntityManager:SetState(entityId, newState, ...)
	local entity = self.Entities[entityId]
	if entity and entity.StateMachine then
		entity.StateMachine:SetState(newState, ...)
	end
end

function EntityManager:TriggerAction(entityId, action, ...)
	local entity = self.Entities[entityId]
	if entity and entity.StateMachine then
		entity.StateMachine:Trigger(action, ...)
	end
end

function EntityManager:GetEntity(entityId)
	return self.Entities[entityId]
end

function EntityManager:GetEntityByCharacter(character)
	for _, entity in pairs(self.Entities) do
		if entity.Character == character then
			return entity
		end
	end
end

function EntityManager:GetEntityByPlayer(player)
	for _, entity in pairs(self.Entities) do
		if entity.Player == player then
			return entity
		end
	end
end

return EntityManager
