--[[
    RmAafGameApplicator.lua

    Applies merged animal food configuration to game systems.
    Modifies the active game state with configuration data.
    Includes automatic normalization of weights and ratios.

    Module: RmAafGameApplicator
    Dependencies: RmAafDataConverters (for parseFillTypesFromString and normalization)

    Author: Ritter
]]

RmAafGameApplicator = {}

-- ============================================================================
-- INTERNAL HELPERS: Applying specific data sections
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
                            local newFillTypes = RmAafDataConverters.parseFillTypesFromString(configGroup.fillTypes,
                                context)

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
                            local newFillTypes = RmAafDataConverters.parseFillTypesFromString(configIngredient.fillTypes,
                                context)

                            if newFillTypes then
                                gameIngredient.fillTypes = newFillTypes
                            end
                        end

                        mixturesApplied = mixturesApplied + 1
                    end
                end

                -- Normalize weights for this mixture
                RmAafDataConverters.normalizeWeights(gameMixture.ingredients)

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
                            local newFillTypes = RmAafDataConverters.parseFillTypesFromString(configIngredient.fillTypes,
                                context)

                            if newFillTypes then
                                gameIngredient.fillTypes = newFillTypes
                            end
                        end

                        recipesApplied = recipesApplied + 1
                    end
                end

                -- Normalize ratios for this recipe
                RmAafDataConverters.normalizeRatios(gameRecipe.ingredients)

                RmLogging.logDebug("Applied recipe %s with %d ingredients",
                    recipeData.fillType, #recipeData.ingredients)
            end
        end
    end

    return recipesApplied
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

---Applies complete configuration data to game
---Coordinates application of animals, mixtures, and recipes
---@param data table Configuration to apply (with animals, mixtures, recipes tables)
---@return boolean success True if any configuration was successfully applied
function RmAafGameApplicator:applyToGame(data)
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
