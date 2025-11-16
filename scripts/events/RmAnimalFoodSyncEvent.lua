--[[
    RmAnimalFoodSyncEvent.lua

    Network event for synchronizing complete animal food configuration from server to clients.
    Serializes animals, mixtures, and recipes data over the network.

    Author: Ritter
]]

RmAnimalFoodSyncEvent = {}
local RmAnimalFoodSyncEvent_mt = Class(RmAnimalFoodSyncEvent, Event)

InitEventClass(RmAnimalFoodSyncEvent, "RmAnimalFoodSyncEvent")

---Creates empty event instance for deserialization
---@return table event The empty event instance
function RmAnimalFoodSyncEvent.emptyNew()
    return Event.new(RmAnimalFoodSyncEvent_mt)
end

---Creates new animal food sync event with configuration data
---@param animals table Array of animal configurations
---@param mixtures table Array of mixture configurations
---@param recipes table Array of recipe configurations
---@return table event The event instance
function RmAnimalFoodSyncEvent.new(animals, mixtures, recipes)
    local self = RmAnimalFoodSyncEvent.emptyNew()
    self.animals = animals or {}
    self.mixtures = mixtures or {}
    self.recipes = recipes or {}
    return self
end

---Writes event data to network stream (server side)
---@param streamId number Stream identifier
---@param connection table Connection object
function RmAnimalFoodSyncEvent:writeStream(streamId, connection)
    -- Serialize animals
    streamWriteInt32(streamId, #self.animals)
    for _, animal in ipairs(self.animals) do
        streamWriteString(streamId, animal.animalType)
        streamWriteString(streamId, animal.consumptionType)

        -- Serialize food groups for this animal
        streamWriteInt32(streamId, #animal.foodGroups)
        for _, group in ipairs(animal.foodGroups) do
            streamWriteString(streamId, group.title)
            streamWriteFloat32(streamId, group.productionWeight)
            streamWriteFloat32(streamId, group.eatWeight)
            streamWriteString(streamId, group.fillTypes)
            streamWriteBool(streamId, group.disabled or false)
        end
    end

    -- Serialize mixtures
    streamWriteInt32(streamId, #self.mixtures)
    for _, mixture in ipairs(self.mixtures) do
        streamWriteString(streamId, mixture.fillType)
        streamWriteString(streamId, mixture.animalType)

        -- Serialize ingredients for this mixture
        streamWriteInt32(streamId, #mixture.ingredients)
        for _, ingredient in ipairs(mixture.ingredients) do
            streamWriteFloat32(streamId, ingredient.weight)
            streamWriteString(streamId, ingredient.fillTypes)
            streamWriteBool(streamId, ingredient.disabled or false)
        end
    end

    -- Serialize recipes
    streamWriteInt32(streamId, #self.recipes)
    for _, recipe in ipairs(self.recipes) do
        streamWriteString(streamId, recipe.fillType)

        -- Serialize ingredients for this recipe
        streamWriteInt32(streamId, #recipe.ingredients)
        for _, ingredient in ipairs(recipe.ingredients) do
            streamWriteString(streamId, ingredient.name)
            streamWriteString(streamId, ingredient.title)
            streamWriteInt32(streamId, ingredient.minPercentage)
            streamWriteInt32(streamId, ingredient.maxPercentage)
            streamWriteString(streamId, ingredient.fillTypes)
            streamWriteBool(streamId, ingredient.disabled or false)
        end
    end
end

---Reads event data from network stream (client side)
---@param streamId number Stream identifier
---@param connection table Connection object
function RmAnimalFoodSyncEvent:readStream(streamId, connection)
    -- Deserialize animals
    local animalCount = streamReadInt32(streamId)
    self.animals = {}
    for i = 1, animalCount do
        local animal = {}
        animal.animalType = streamReadString(streamId)
        animal.consumptionType = streamReadString(streamId)

        -- Deserialize food groups for this animal
        local groupCount = streamReadInt32(streamId)
        animal.foodGroups = {}
        for j = 1, groupCount do
            table.insert(animal.foodGroups, {
                title = streamReadString(streamId),
                productionWeight = streamReadFloat32(streamId),
                eatWeight = streamReadFloat32(streamId),
                fillTypes = streamReadString(streamId),
                disabled = streamReadBool(streamId)
            })
        end

        table.insert(self.animals, animal)
    end

    -- Deserialize mixtures
    local mixtureCount = streamReadInt32(streamId)
    self.mixtures = {}
    for i = 1, mixtureCount do
        local mixture = {}
        mixture.fillType = streamReadString(streamId)
        mixture.animalType = streamReadString(streamId)

        -- Deserialize ingredients for this mixture
        local ingredientCount = streamReadInt32(streamId)
        mixture.ingredients = {}
        for j = 1, ingredientCount do
            table.insert(mixture.ingredients, {
                weight = streamReadFloat32(streamId),
                fillTypes = streamReadString(streamId),
                disabled = streamReadBool(streamId)
            })
        end

        table.insert(self.mixtures, mixture)
    end

    -- Deserialize recipes
    local recipeCount = streamReadInt32(streamId)
    self.recipes = {}
    for i = 1, recipeCount do
        local recipe = {}
        recipe.fillType = streamReadString(streamId)

        -- Deserialize ingredients for this recipe
        local ingredientCount = streamReadInt32(streamId)
        recipe.ingredients = {}
        for j = 1, ingredientCount do
            table.insert(recipe.ingredients, {
                name = streamReadString(streamId),
                title = streamReadString(streamId),
                minPercentage = streamReadInt32(streamId),
                maxPercentage = streamReadInt32(streamId),
                fillTypes = streamReadString(streamId),
                disabled = streamReadBool(streamId)
            })
        end

        table.insert(self.recipes, recipe)
    end

    self:run(connection)
end

---Executes event on client - applies received configuration to game
---@param connection table Connection object
function RmAnimalFoodSyncEvent:run(connection)
    RmLogging.logInfo("Received config sync from server: %d animals, %d mixtures, %d recipes",
        #self.animals, #self.mixtures, #self.recipes)

    -- Apply received configuration to game
    local configData = {
        animals = self.animals,
        mixtures = self.mixtures,
        recipes = self.recipes
    }

    RmAafGameApplicator:applyToGame(configData)
    RmLogging.logInfo("Client configuration applied successfully")
end
