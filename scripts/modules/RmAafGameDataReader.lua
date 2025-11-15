--[[
    RmAafGameDataReader.lua

    Reads current animal food configuration from game systems.
    Extracts animals, mixtures, and recipes from the active AnimalFoodSystem.

    Module: RmAafGameDataReader
    Dependencies: RmAafDataConverters (for type conversion utilities)

    Author: Ritter
]]

RmAafGameDataReader = {}

-- ============================================================================
-- INTERNAL HELPERS: Reading specific data sections
-- ============================================================================

---Reads animal food data from game
---@param foodSystem table AnimalFoodSystem instance
---@return table animals Array of animal configurations
local function readAnimalsFromGame(foodSystem)
    local animals = {}

    for _, animalFood in ipairs(foodSystem.animalFood) do
        local animalName = RmAafDataConverters.getAnimalNameFromIndex(animalFood.animalTypeIndex)
        if animalName then
            local animal = {
                animalType = animalName,
                consumptionType = RmAafDataConverters.getConsumptionTypeName(animalFood.consumptionType),
                foodGroups = {}
            }

            -- Read food groups for this animal
            for _, group in ipairs(animalFood.groups) do
                local foodGroup = {
                    title = group.title,
                    productionWeight = group.productionWeight,
                    eatWeight = group.eatWeight,
                    fillTypes = RmAafDataConverters.getFillTypeNamesString(group.fillTypes)
                }
                table.insert(animal.foodGroups, foodGroup)
            end

            table.insert(animals, animal)
            RmLogging.logDebug("Read animal %s with %d food groups", animalName, #animal.foodGroups)
        end
    end

    return animals
end

---Reads mixture data from game
---@param foodSystem table AnimalFoodSystem instance
---@return table mixtures Array of mixture configurations
local function readMixturesFromGame(foodSystem)
    local mixtures = {}

    for fillTypeIndex, mixture in pairs(foodSystem.mixtureFillTypeIndexToMixture) do
        local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex)
        local animalTypeIndex = nil

        -- Find animal type for this mixture by searching animalMixtures mapping
        for animalIdx, mixtureFillTypes in pairs(foodSystem.animalMixtures) do
            for _, mixFillType in ipairs(mixtureFillTypes) do
                if mixFillType == fillTypeIndex then
                    animalTypeIndex = animalIdx
                    break
                end
            end
            if animalTypeIndex then break end
        end

        local animalName = RmAafDataConverters.getAnimalNameFromIndex(animalTypeIndex)

        if fillTypeName and animalName then
            local mixtureData = {
                fillType = fillTypeName,
                animalType = animalName,
                ingredients = {}
            }

            -- Read ingredients for this mixture
            for _, ingredient in ipairs(mixture.ingredients) do
                local ingredientData = {
                    weight = ingredient.weight,
                    fillTypes = RmAafDataConverters.getFillTypeNamesString(ingredient.fillTypes)
                }
                table.insert(mixtureData.ingredients, ingredientData)
            end

            table.insert(mixtures, mixtureData)
            RmLogging.logDebug("Read mixture %s for %s", fillTypeName, animalName)
        end
    end

    return mixtures
end

---Reads recipe data from game
---@param foodSystem table AnimalFoodSystem instance
---@return table recipes Array of recipe configurations
local function readRecipesFromGame(foodSystem)
    local recipes = {}

    for fillTypeIndex, recipe in pairs(foodSystem.recipeFillTypeIndexToRecipe) do
        local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex)

        if fillTypeName then
            local recipeData = {
                fillType = fillTypeName,
                ingredients = {}
            }

            -- Read ingredients for this recipe (convert percentages from 0-1 to 0-100)
            for _, ingredient in ipairs(recipe.ingredients) do
                local ingredientData = {
                    name = ingredient.name,
                    title = ingredient.title,
                    minPercentage = math.floor(ingredient.minPercentage * 100),
                    maxPercentage = math.floor(ingredient.maxPercentage * 100),
                    fillTypes = RmAafDataConverters.getFillTypeNamesString(ingredient.fillTypes)
                }
                table.insert(recipeData.ingredients, ingredientData)
            end

            table.insert(recipes, recipeData)
            RmLogging.logDebug("Read recipe %s with %d ingredients", fillTypeName, #recipeData.ingredients)
        end
    end

    return recipes
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

---Reads complete animal food data from game
---Coordinates reading of animals, mixtures, and recipes
---@return table data Current game configuration (with animals, mixtures, recipes tables)
function RmAafGameDataReader:readGameData()
    RmLogging.logInfo("Reading current game animal food data")

    local data = {
        animals = {},
        mixtures = {},
        recipes = {}
    }

    if not g_currentMission or not g_currentMission.animalFoodSystem then
        RmLogging.logError("AnimalFoodSystem not available")
        return data
    end

    local foodSystem = g_currentMission.animalFoodSystem

    -- Read each section using focused functions
    data.animals = readAnimalsFromGame(foodSystem)
    data.mixtures = readMixturesFromGame(foodSystem)
    data.recipes = readRecipesFromGame(foodSystem)

    RmLogging.logInfo("Read %d animals, %d mixtures, %d recipes from game",
        #data.animals, #data.mixtures, #data.recipes)

    return data
end
