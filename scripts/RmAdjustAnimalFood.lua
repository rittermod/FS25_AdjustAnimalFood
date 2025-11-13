--[[
    RmAdjustAnimalFood.lua

    Animal food system modification for Farming Simulator 2025

    Author: Ritter
    Version: 0.7.0.0

    OVERVIEW:
    This mod provides control over the animal food system using the game's
    built-in AnimalFoodSystem with schema-validated XML. It allows modification of:
    - Animal food groups (productionWeight, eatWeight, fillTypes)
    - Mixture recipes (ingredient weights and fillTypes)
    - TMR/Forage recipes (ingredient percentages and fillTypes)

    WORKFLOW:
    The system follows a clear read-merge-apply pattern:
    1. Read current game configuration (readGameData)
    2. Load user XML customizations (loadFromXML)
    3. Merge XML overrides with game defaults (mergeData)
    4. Apply merged configuration to game (applyToGame)
    5. Save configuration for next session (saveToXML)

    KNOWN LIMITATIONS:
    - XML uses translated text for titles instead of $l10n_ keys. If users want
      language-independent XML, they must manually edit titles to use $l10n_ keys.
]]

-- Load logging utility
source(g_currentModDirectory .. "scripts/RmLogging.lua")

-- Module declaration
RmAdjustAnimalFood = {}
RmAdjustAnimalFood.modDirectory = g_currentModDirectory
RmAdjustAnimalFood.modName = g_currentModName
RmAdjustAnimalFood.XML_FILENAME = "aaf_AnimalFood.xml"

-- Configure logging
RmLogging.setLogPrefix("[RmAdjustAnimalFood]")
-- RmLogging.setLogLevel(RmLogging.LOG_LEVEL.DEBUG) -- Change to INFO or WARNING for less verbosity

-- ============================================================================
-- UTILITY FUNCTIONS: Conversion helpers for game data types
-- ============================================================================

---Converts animal type index to name
---@param animalTypeIndex number Animal type index
---@return string|nil animalName Animal type name or nil
local function getAnimalNameFromIndex(animalTypeIndex)
    if not g_currentMission or not g_currentMission.animalSystem then
        return nil
    end

    return g_currentMission.animalSystem.typeIndexToName[animalTypeIndex]
end

---Converts consumption type number to string
---@param consumptionType number Consumption type (1=SERIAL, 2=PARALLEL)
---@return string consumptionTypeName "SERIAL" or "PARALLEL"
local function getConsumptionTypeName(consumptionType)
    if consumptionType == AnimalFoodSystem.FOOD_CONSUME_TYPE_PARALLEL then
        return "PARALLEL"
    end
    return "SERIAL"
end

---Converts fill type indices array to space-separated string of names
---@param fillTypes table Array of fill type indices
---@return string fillTypeNames Space-separated fill type names
local function getFillTypeNamesString(fillTypes)
    local names = {}
    for _, fillTypeIndex in ipairs(fillTypes) do
        local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex)
        if fillTypeName then
            table.insert(names, fillTypeName)
        end
    end
    return table.concat(names, " ")
end

-- ============================================================================
-- DATA OPERATIONS: XML loading and saving
-- ============================================================================

-- Note: We use translated text in XML instead of $l10n_ keys because:
-- 1. The game's convertText() has already translated titles when we read them
-- 2. Reverse lookup would require scanning all possible l10n keys
-- 3. Using translated text works - it's just language-specific
-- Users can manually edit to use $l10n_ keys if they want language-independence

---Loads animal food configuration from XML using schema
---@param filePath string Path to XML file
---@return table|nil data Loaded configuration or nil on error
function RmAdjustAnimalFood:loadFromXML(filePath)
    RmLogging.logInfo("Loading animal food configuration from %s", filePath)

    if not AnimalFoodSystem.xmlSchema then
        RmLogging.logError("AnimalFoodSystem.xmlSchema not available")
        return nil
    end

    local xmlFile = XMLFile.load("animalFoodAdjust", filePath, AnimalFoodSystem.xmlSchema)
    if not xmlFile then
        RmLogging.logError("Failed to load XML file with schema")
        return nil
    end

    local data = {
        animals = {},
        mixtures = {},
        recipes = {}
    }

    -- Load animals
    xmlFile:iterate("animalFood.animals.animal", function(_, animalKey)
        local animalTypeName = xmlFile:getValue(animalKey .. "#animalType")
        local consumptionType = xmlFile:getValue(animalKey .. "#consumptionType", "SERIAL")

        if animalTypeName then
            local animal = {
                animalType = animalTypeName,
                consumptionType = consumptionType,
                foodGroups = {}
            }

            -- Load food groups
            xmlFile:iterate(animalKey .. ".foodGroup", function(_, groupKey)
                local foodGroup = {
                    title = xmlFile:getValue(groupKey .. "#title"),
                    productionWeight = xmlFile:getValue(groupKey .. "#productionWeight", 0),
                    eatWeight = xmlFile:getValue(groupKey .. "#eatWeight", 1),
                    fillTypes = xmlFile:getValue(groupKey .. "#fillTypes")
                }

                if foodGroup.title then
                    table.insert(animal.foodGroups, foodGroup)
                end
            end)

            table.insert(data.animals, animal)
            RmLogging.logDebug("Loaded animal %s with %d food groups", animalTypeName, #animal.foodGroups)
        end
    end)

    -- Load mixtures
    xmlFile:iterate("animalFood.mixtures.mixture", function(_, mixtureKey)
        local mixture = {
            fillType = xmlFile:getValue(mixtureKey .. "#fillType"),
            animalType = xmlFile:getValue(mixtureKey .. "#animalType"),
            ingredients = {}
        }

        xmlFile:iterate(mixtureKey .. ".ingredient", function(_, ingredientKey)
            local ingredient = {
                weight = xmlFile:getValue(ingredientKey .. "#weight", 0),
                fillTypes = xmlFile:getValue(ingredientKey .. "#fillTypes")
            }
            table.insert(mixture.ingredients, ingredient)
        end)

        if mixture.fillType and mixture.animalType then
            table.insert(data.mixtures, mixture)
            RmLogging.logDebug("Loaded mixture %s for %s", mixture.fillType, mixture.animalType)
        end
    end)

    -- Load recipes
    xmlFile:iterate("animalFood.recipes.recipe", function(_, recipeKey)
        local recipe = {
            fillType = xmlFile:getValue(recipeKey .. "#fillType"),
            ingredients = {}
        }

        xmlFile:iterate(recipeKey .. ".ingredient", function(_, ingredientKey)
            local ingredient = {
                name = xmlFile:getValue(ingredientKey .. "#name"),
                title = xmlFile:getValue(ingredientKey .. "#title"),
                minPercentage = xmlFile:getValue(ingredientKey .. "#minPercentage", 0),
                maxPercentage = xmlFile:getValue(ingredientKey .. "#maxPercentage", 75),
                fillTypes = xmlFile:getValue(ingredientKey .. "#fillTypes")
            }
            table.insert(recipe.ingredients, ingredient)
        end)

        if recipe.fillType then
            table.insert(data.recipes, recipe)
            RmLogging.logDebug("Loaded recipe %s with %d ingredients", recipe.fillType, #recipe.ingredients)
        end
    end)

    xmlFile:delete()

    RmLogging.logInfo("Loaded %d animals, %d mixtures, %d recipes from XML",
        #data.animals, #data.mixtures, #data.recipes)

    return data
end

---Saves animal food configuration to XML
---@param data table Configuration data to save
---@param filePath string Path to XML file
---@return boolean success True if save was successful
function RmAdjustAnimalFood:saveToXML(data, filePath)
    RmLogging.logInfo("Saving animal food configuration to %s", filePath)

    local xmlFile = createXMLFile("animalFoodAdjust", filePath, "animalFood")
    if xmlFile == nil then
        RmLogging.logError("Failed to create XML file")
        return false
    end

    -- Save animals
    for animalIndex, animal in ipairs(data.animals) do
        local animalKey = string.format("animalFood.animals.animal(%d)", animalIndex - 1)
        setXMLString(xmlFile, animalKey .. "#animalType", animal.animalType)
        setXMLString(xmlFile, animalKey .. "#consumptionType", animal.consumptionType)

        for groupIndex, foodGroup in ipairs(animal.foodGroups) do
            local groupKey = string.format("%s.foodGroup(%d)", animalKey, groupIndex - 1)
            setXMLString(xmlFile, groupKey .. "#title", foodGroup.title)
            setXMLFloat(xmlFile, groupKey .. "#productionWeight", foodGroup.productionWeight)
            setXMLFloat(xmlFile, groupKey .. "#eatWeight", foodGroup.eatWeight)
            setXMLString(xmlFile, groupKey .. "#fillTypes", foodGroup.fillTypes)
        end

        RmLogging.logDebug("Saved animal %s with %d food groups", animal.animalType, #animal.foodGroups)
    end

    -- Save mixtures
    for mixtureIndex, mixture in ipairs(data.mixtures) do
        local mixtureKey = string.format("animalFood.mixtures.mixture(%d)", mixtureIndex - 1)
        setXMLString(xmlFile, mixtureKey .. "#fillType", mixture.fillType)
        setXMLString(xmlFile, mixtureKey .. "#animalType", mixture.animalType)

        for ingredientIndex, ingredient in ipairs(mixture.ingredients) do
            local ingredientKey = string.format("%s.ingredient(%d)", mixtureKey, ingredientIndex - 1)
            setXMLFloat(xmlFile, ingredientKey .. "#weight", ingredient.weight)
            setXMLString(xmlFile, ingredientKey .. "#fillTypes", ingredient.fillTypes)
        end

        RmLogging.logDebug("Saved mixture %s for %s", mixture.fillType, mixture.animalType)
    end

    -- Save recipes
    for recipeIndex, recipe in ipairs(data.recipes) do
        local recipeKey = string.format("animalFood.recipes.recipe(%d)", recipeIndex - 1)
        setXMLString(xmlFile, recipeKey .. "#fillType", recipe.fillType)

        for ingredientIndex, ingredient in ipairs(recipe.ingredients) do
            local ingredientKey = string.format("%s.ingredient(%d)", recipeKey, ingredientIndex - 1)
            setXMLString(xmlFile, ingredientKey .. "#name", ingredient.name)
            setXMLString(xmlFile, ingredientKey .. "#title", ingredient.title)
            setXMLInt(xmlFile, ingredientKey .. "#minPercentage", ingredient.minPercentage)
            setXMLInt(xmlFile, ingredientKey .. "#maxPercentage", ingredient.maxPercentage)
            setXMLString(xmlFile, ingredientKey .. "#fillTypes", ingredient.fillTypes)
        end

        RmLogging.logDebug("Saved recipe %s with %d ingredients", recipe.fillType, #recipe.ingredients)
    end

    saveXMLFile(xmlFile)
    delete(xmlFile)

    RmLogging.logInfo("Successfully saved %d animals, %d mixtures, %d recipes to XML",
        #data.animals, #data.mixtures, #data.recipes)

    return true
end

-- ============================================================================
-- DATA OPERATIONS: Reading game data
-- ============================================================================

---Reads animal food data from game
---@param foodSystem table AnimalFoodSystem instance
---@return table animals Array of animal configurations
local function readAnimalsFromGame(foodSystem)
    local animals = {}

    for _, animalFood in ipairs(foodSystem.animalFood) do
        local animalName = getAnimalNameFromIndex(animalFood.animalTypeIndex)
        if animalName then
            local animal = {
                animalType = animalName,
                consumptionType = getConsumptionTypeName(animalFood.consumptionType),
                foodGroups = {}
            }

            -- Read food groups for this animal
            for _, group in ipairs(animalFood.groups) do
                local foodGroup = {
                    title = group.title,
                    productionWeight = group.productionWeight,
                    eatWeight = group.eatWeight,
                    fillTypes = getFillTypeNamesString(group.fillTypes)
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

        local animalName = getAnimalNameFromIndex(animalTypeIndex)

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
                    fillTypes = getFillTypeNamesString(ingredient.fillTypes)
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
                    fillTypes = getFillTypeNamesString(ingredient.fillTypes)
                }
                table.insert(recipeData.ingredients, ingredientData)
            end

            table.insert(recipes, recipeData)
            RmLogging.logDebug("Read recipe %s with %d ingredients", fillTypeName, #recipeData.ingredients)
        end
    end

    return recipes
end

---Reads complete animal food data from game
---Coordinates reading of animals, mixtures, and recipes
---@return table data Current game configuration (with animals, mixtures, recipes tables)
function RmAdjustAnimalFood:readGameData()
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

-- ============================================================================
-- DATA OPERATIONS: Merging XML with game data
-- Merge strategy: XML values override with user customizations,
-- game can add new content from mods/updates
-- ============================================================================

---Merges animal data (XML overrides, game add new content)
---@param xmlAnimals table XML animal configurations
---@param gameAnimals table Game animal configurations
---@return table merged Merged animal configurations
local function mergeAnimals(xmlAnimals, gameAnimals)
    local merged = {}

    -- Create lookup table for XML animals
    local xmlAnimalsByType = {}
    for _, animal in ipairs(xmlAnimals) do
        xmlAnimalsByType[animal.animalType] = animal
    end

    -- Merge each game animal
    for _, gameAnimal in ipairs(gameAnimals) do
        local xmlAnimal = xmlAnimalsByType[gameAnimal.animalType]

        if xmlAnimal then
            -- Animal exists in XML - use XML data as base
            local mergedAnimal = {
                animalType = gameAnimal.animalType,
                consumptionType = xmlAnimal.consumptionType,
                foodGroups = {}
            }

            -- Create lookup for XML food groups
            local xmlGroupsByTitle = {}
            for _, group in ipairs(xmlAnimal.foodGroups) do
                xmlGroupsByTitle[group.title] = group
            end

            -- Merge food groups (XML values override, new game groups added)
            for _, gameGroup in ipairs(gameAnimal.foodGroups) do
                local xmlGroup = xmlGroupsByTitle[gameGroup.title]

                if xmlGroup then
                    -- Group exists in XML - use XML values
                    table.insert(mergedAnimal.foodGroups, {
                        title = xmlGroup.title,
                        productionWeight = xmlGroup.productionWeight,
                        eatWeight = xmlGroup.eatWeight,
                        fillTypes = xmlGroup.fillTypes
                    })
                else
                    -- New group from game - add with game defaults
                    table.insert(mergedAnimal.foodGroups, gameGroup)
                    RmLogging.logDebug("New food group added: %s / %s", gameAnimal.animalType, gameGroup.title)
                end
            end

            table.insert(merged, mergedAnimal)
        else
            -- New animal from game - add with game defaults
            table.insert(merged, gameAnimal)
            RmLogging.logInfo("New animal type added: %s", gameAnimal.animalType)
        end
    end

    return merged
end

---Merges mixture data (XML overrides, game adds new content)
---@param xmlMixtures table XML mixture configurations
---@param gameMixtures table Game mixture configurations
---@return table merged Merged mixture configurations
local function mergeMixtures(xmlMixtures, gameMixtures)
    local merged = {}

    -- Create lookup table for XML mixtures
    local xmlMixturesByKey = {}
    for _, mixture in ipairs(xmlMixtures) do
        local key = mixture.fillType .. "_" .. mixture.animalType
        xmlMixturesByKey[key] = mixture
    end

    -- Merge each game mixture
    for _, gameMixture in ipairs(gameMixtures) do
        local key = gameMixture.fillType .. "_" .. gameMixture.animalType
        local xmlMixture = xmlMixturesByKey[key]

        if xmlMixture then
            table.insert(merged, xmlMixture)
        else
            table.insert(merged, gameMixture)
            RmLogging.logDebug("New mixture added: %s for %s", gameMixture.fillType, gameMixture.animalType)
        end
    end

    return merged
end

---Merges recipe data (XML overrides, game adds new content)
---@param xmlRecipes table XML recipe configurations
---@param gameRecipes table Game recipe configurations
---@return table merged Merged recipe configurations
local function mergeRecipes(xmlRecipes, gameRecipes)
    local merged = {}

    -- Create lookup table for XML recipes
    local xmlRecipesByFillType = {}
    for _, recipe in ipairs(xmlRecipes) do
        xmlRecipesByFillType[recipe.fillType] = recipe
    end

    -- Merge each game recipe
    for _, gameRecipe in ipairs(gameRecipes) do
        local xmlRecipe = xmlRecipesByFillType[gameRecipe.fillType]

        if xmlRecipe then
            table.insert(merged, xmlRecipe)
        else
            table.insert(merged, gameRecipe)
            RmLogging.logDebug("New recipe added: %s", gameRecipe.fillType)
        end
    end

    return merged
end

---Merges complete XML and game data
---Coordinates merging of animals, mixtures, and recipes (XML overrides, game adds new content)
---@param xmlData table Data loaded from XML (with animals, mixtures, recipes tables)
---@param gameData table Current game data (with animals, mixtures, recipes tables)
---@return table merged Merged configuration (with animals, mixtures, recipes tables)
function RmAdjustAnimalFood:mergeData(xmlData, gameData)
    RmLogging.logInfo("Merging XML data with game data")

    local merged = {
        animals = {},
        mixtures = {},
        recipes = {}
    }

    -- Merge each section using focused functions
    merged.animals = mergeAnimals(xmlData.animals, gameData.animals)
    merged.mixtures = mergeMixtures(xmlData.mixtures, gameData.mixtures)
    merged.recipes = mergeRecipes(xmlData.recipes, gameData.recipes)

    RmLogging.logInfo("Merged to %d animals, %d mixtures, %d recipes",
        #merged.animals, #merged.mixtures, #merged.recipes)

    return merged
end

-- ============================================================================
-- HELPER FUNCTIONS: Common operations for fillTypes and normalization
-- ============================================================================

---Parses space-separated fillType names and converts to indices array
---@param fillTypeString string Space-separated fillType names (e.g. "WHEAT BARLEY OAT")
---@param context string Context description for logging (e.g. "COW / forage")
---@return table|nil fillTypeIndices Array of fillType indices, or nil if none valid
local function parseFillTypesFromString(fillTypeString, context)
    if not fillTypeString or fillTypeString == "" then
        return nil
    end

    local fillTypeIndices = {}
    local fillTypeNames = string.split(fillTypeString, " ")

    for _, fillTypeName in ipairs(fillTypeNames) do
        local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)
        if fillTypeIndex then
            table.insert(fillTypeIndices, fillTypeIndex)
        else
            RmLogging.logWarning("Unknown fillType '%s' for %s", fillTypeName, context)
        end
    end

    return #fillTypeIndices > 0 and fillTypeIndices or nil
end

---Normalizes ingredient weights to sum to 1.0
---@param ingredients table Array of ingredients with weight field
---@return boolean success True if normalization was performed
local function normalizeWeights(ingredients)
    if not ingredients or #ingredients == 0 then
        return false
    end

    -- Calculate sum of weights
    local sumWeights = 0
    for _, ingredient in ipairs(ingredients) do
        sumWeights = sumWeights + ingredient.weight
    end

    -- Normalize if sum > 0
    if sumWeights > 0 then
        for _, ingredient in ipairs(ingredients) do
            ingredient.weight = ingredient.weight / sumWeights
        end
        return true
    end

    return false
end

---Normalizes recipe ingredient ratios to sum to 1.0
---@param ingredients table Array of recipe ingredients with ratio field
---@return boolean success True if normalization was performed
local function normalizeRatios(ingredients)
    if not ingredients or #ingredients == 0 then
        return false
    end

    -- Calculate sum of ratios
    local sumRatios = 0
    for _, ingredient in ipairs(ingredients) do
        sumRatios = sumRatios + ingredient.ratio
    end

    -- Normalize if sum > 0
    if sumRatios > 0 then
        for _, ingredient in ipairs(ingredients) do
            ingredient.ratio = ingredient.ratio / sumRatios
        end
        return true
    end

    return false
end

-- ============================================================================
-- APPLICATION LOGIC: Applying configuration to game
-- These functions modify the active game state with merged configuration
-- Includes automatic normalization of weights and ratios
-- ============================================================================

---Applies animal food configuration to game
---@param animals table Array of animal configurations
---@param foodSystem table AnimalFoodSystem instance
---@return number applied Number of food groups applied
local function applyAnimalsToGame(animals, foodSystem)
    local applied = 0

    for _, animalData in ipairs(animals) do
        local animalTypeIndex = g_currentMission.animalSystem:getTypeIndexByName(animalData.animalType)

        if animalTypeIndex then
            local animalFood = foodSystem:getAnimalFood(animalTypeIndex)

            if animalFood then
                -- Create lookup for food groups by title
                local groupsByTitle = {}
                for _, group in ipairs(animalFood.groups) do
                    groupsByTitle[group.title] = group
                end

                -- Apply values from configuration
                for _, configGroup in ipairs(animalData.foodGroups) do
                    local gameGroup = groupsByTitle[configGroup.title]

                    if gameGroup then
                        -- Apply production and eat weights
                        gameGroup.productionWeight = configGroup.productionWeight
                        gameGroup.eatWeight = configGroup.eatWeight

                        -- Apply fillTypes if changed
                        if configGroup.fillTypes then
                            local context = animalData.animalType .. " / " .. configGroup.title
                            local newFillTypes = parseFillTypesFromString(configGroup.fillTypes, context)

                            if newFillTypes then
                                gameGroup.fillTypes = newFillTypes
                                RmLogging.logDebug("Applied fillTypes for %s: %s", context, configGroup.fillTypes)
                            end
                        end

                        applied = applied + 1
                        RmLogging.logDebug("Applied %s / %s: prodWeight=%.3f, eatWeight=%.3f",
                            animalData.animalType, configGroup.title,
                            configGroup.productionWeight, configGroup.eatWeight)
                    end
                end
            end
        end
    end

    return applied
end

---Applies mixture configuration to game
---@param mixtures table Array of mixture configurations
---@param foodSystem table AnimalFoodSystem instance
---@return number applied Number of mixture ingredients applied
local function applyMixturesToGame(mixtures, foodSystem)
    local mixturesApplied = 0

    for _, mixtureData in ipairs(mixtures) do
        local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(mixtureData.fillType)

        if fillTypeIndex then
            local gameMixture = foodSystem:getMixtureByFillType(fillTypeIndex)

            if gameMixture then
                -- Apply ingredient weights and fillTypes
                for i, configIngredient in ipairs(mixtureData.ingredients) do
                    if gameMixture.ingredients[i] then
                        local gameIngredient = gameMixture.ingredients[i]

                        -- Apply weight
                        gameIngredient.weight = configIngredient.weight

                        -- Apply fillTypes
                        if configIngredient.fillTypes then
                            local context = string.format("mixture %s ingredient %d", mixtureData.fillType, i)
                            local newFillTypes = parseFillTypesFromString(configIngredient.fillTypes, context)

                            if newFillTypes then
                                gameIngredient.fillTypes = newFillTypes
                            end
                        end

                        mixturesApplied = mixturesApplied + 1
                    end
                end

                -- Normalize weights for this mixture
                normalizeWeights(gameMixture.ingredients)

                RmLogging.logDebug("Applied mixture %s with %d ingredients",
                    mixtureData.fillType, #mixtureData.ingredients)
            end
        end
    end

    return mixturesApplied
end

---Applies recipe configuration to game
---@param recipes table Array of recipe configurations
---@param foodSystem table AnimalFoodSystem instance
---@return number applied Number of recipe ingredients applied
local function applyRecipesToGame(recipes, foodSystem)
    local recipesApplied = 0

    for _, recipeData in ipairs(recipes) do
        local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(recipeData.fillType)

        if fillTypeIndex then
            local gameRecipe = foodSystem:getRecipeByFillTypeIndex(fillTypeIndex)

            if gameRecipe then
                -- Apply ingredient percentages and fillTypes
                for i, configIngredient in ipairs(recipeData.ingredients) do
                    if gameRecipe.ingredients[i] then
                        local gameIngredient = gameRecipe.ingredients[i]

                        -- Apply percentages (convert from 0-100 to 0-1)
                        gameIngredient.minPercentage = configIngredient.minPercentage / 100
                        gameIngredient.maxPercentage = configIngredient.maxPercentage / 100

                        -- Recalculate ratio
                        gameIngredient.ratio = gameIngredient.maxPercentage - gameIngredient.minPercentage

                        -- Apply fillTypes
                        if configIngredient.fillTypes then
                            local context = string.format("recipe %s ingredient %d", recipeData.fillType, i)
                            local newFillTypes = parseFillTypesFromString(configIngredient.fillTypes, context)

                            if newFillTypes then
                                gameIngredient.fillTypes = newFillTypes
                            end
                        end

                        recipesApplied = recipesApplied + 1
                    end
                end

                -- Normalize ratios for this recipe
                normalizeRatios(gameRecipe.ingredients)

                RmLogging.logDebug("Applied recipe %s with %d ingredients",
                    recipeData.fillType, #recipeData.ingredients)
            end
        end
    end

    return recipesApplied
end

---Applies complete configuration data to game
---Coordinates application of animals, mixtures, and recipes
---@param data table Configuration to apply (with animals, mixtures, recipes tables)
---@return boolean success True if any configuration was successfully applied
function RmAdjustAnimalFood:applyToGame(data)
    RmLogging.logInfo("Applying configuration to game")

    if not g_currentMission or not g_currentMission.animalFoodSystem then
        RmLogging.logError("AnimalFoodSystem not available")
        return false
    end

    local foodSystem = g_currentMission.animalFoodSystem

    -- Apply each section using focused functions
    local animalsApplied = applyAnimalsToGame(data.animals, foodSystem)
    local mixturesApplied = applyMixturesToGame(data.mixtures, foodSystem)
    local recipesApplied = applyRecipesToGame(data.recipes, foodSystem)

    RmLogging.logInfo("Applied %d food groups, %d mixture ingredients, %d recipe ingredients",
        animalsApplied, mixturesApplied, recipesApplied)

    return animalsApplied > 0 or mixturesApplied > 0 or recipesApplied > 0
end

-- ============================================================================
-- LIFECYCLE INTEGRATION: Game hooks and initialization
-- These functions hook into the game's lifecycle to load/save configuration
-- ============================================================================

---Loads configuration from XML and applies to game
---This is the main entry point called after map loading completes
---Workflow: Load XML → Read game data → Merge → Save merged → Apply to game
function RmAdjustAnimalFood.loadAndApply()
    if not g_currentMission or not g_currentMission.missionInfo then
        RmLogging.logWarning("Mission information not available")
        return
    end

    local savegameDir = g_currentMission.missionInfo.savegameDirectory
    if not savegameDir then
        RmLogging.logWarning("Savegame directory not available")
        return
    end

    local xmlFilePath = savegameDir .. "/" .. RmAdjustAnimalFood.XML_FILENAME

    if fileExists(xmlFilePath) then
        RmLogging.logInfo("Configuration file exists, loading...")

        local xmlData = RmAdjustAnimalFood:loadFromXML(xmlFilePath)
        if xmlData then
            local gameData = RmAdjustAnimalFood:readGameData()
            local merged = RmAdjustAnimalFood:mergeData(xmlData, gameData)

            -- Save merged result
            RmAdjustAnimalFood:saveToXML(merged, xmlFilePath)

            -- Apply to game
            RmAdjustAnimalFood:applyToGame(merged)
        end
    else
        RmLogging.logInfo("No configuration file found, creating default")

        local gameData = RmAdjustAnimalFood:readGameData()
        RmAdjustAnimalFood:saveToXML(gameData, xmlFilePath)
    end

    RmLogging.logInfo("RmAdjustAnimalFood initialization complete")
end

---Saves current game configuration to XML
function RmAdjustAnimalFood.saveToFile()
    RmLogging.logInfo("Saving animal food configuration...")

    if not g_currentMission or not g_currentMission.missionInfo then
        RmLogging.logWarning("Mission information not available, skipping save")
        return
    end

    local savegameDir = g_currentMission.missionInfo.savegameDirectory
    if not savegameDir then
        RmLogging.logWarning("Savegame directory not available, skipping save")
        return
    end

    local xmlFilePath = savegameDir .. "/" .. RmAdjustAnimalFood.XML_FILENAME
    local gameData = RmAdjustAnimalFood:readGameData()
    RmAdjustAnimalFood:saveToXML(gameData, xmlFilePath)
end

---Called when map finishes loading
---This is the entry point for the experimental script
local function onLoadMapFinished()
    RmLogging.logInfo("Map loading finished, initializing RmAdjustAnimalFood")

    -- Hook into savegame save
    FSBaseMission.saveSavegame = Utils.appendedFunction(
        FSBaseMission.saveSavegame,
        RmAdjustAnimalFood.saveToFile
    )

    -- Load and apply configuration
    RmAdjustAnimalFood.loadAndApply()
end

-- Hook into map loading completion
BaseMission.loadMapFinished = Utils.appendedFunction(
    BaseMission.loadMapFinished,
    onLoadMapFinished
)

RmLogging.logInfo("RmAdjustAnimalFood mod initialized")
