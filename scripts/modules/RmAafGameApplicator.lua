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
                -- Apply consumptionType if specified in config
                if animalData.consumptionType then
                    local consumptionTypeValue = RmAafDataConverters.getConsumptionTypeValue(animalData.consumptionType)
                    animalFood.consumptionType = consumptionTypeValue
                    RmLogging.logInfo("Applied consumptionType for %s: %s (%d)",
                        animalData.animalType, animalData.consumptionType, consumptionTypeValue)
                end

                -- Create lookup for food groups by title
                local groupsByTitle = {}
                for _, group in ipairs(animalFood.groups) do
                    groupsByTitle[group.title] = group
                end

                -- First loop: UPDATE existing food groups
                for _, configGroup in ipairs(animalData.foodGroups) do
                    if not configGroup.disabled then
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
                        -- gameGroup is nil = custom addition, handled in next loop
                    end
                end

                -- Build lookup of disabled titles for insertion logic
                local disabledTitles = {}
                for _, cfg in ipairs(animalData.foodGroups) do
                    if cfg.disabled then
                        disabledTitles[cfg.title] = true
                    end
                end

                RmLogging.logDebug("DEBUG: Animal %s - Game array before insertions:", animalData.animalType)
                for idx, grp in ipairs(animalFood.groups) do
                    RmLogging.logDebug("  [%d] %s (disabled=%s)", idx, grp.title,
                        tostring(disabledTitles[grp.title] or false))
                end

                -- Second loop: INSERT custom food groups
                for i, configGroup in ipairs(animalData.foodGroups) do
                    if not configGroup.disabled then
                        local gameGroup = groupsByTitle[configGroup.title]

                        if not gameGroup then
                            -- This is a custom addition, not in game

                            -- Validate fillTypes before insertion
                            local context = animalData.animalType .. " / " .. configGroup.title
                            local fillTypeIndices = RmAafDataConverters.parseFillTypesFromString(
                                configGroup.fillTypes, context)

                            if fillTypeIndices then
                                -- Create new food group
                                local newGroup = {
                                    title = configGroup.title,
                                    productionWeight = configGroup.productionWeight,
                                    eatWeight = configGroup.eatWeight,
                                    fillTypes = fillTypeIndices
                                }

                                -- Calculate correct insertion position by counting non-disabled items before this one in XML
                                local activeItemsBefore = 0
                                for j = 1, i - 1 do
                                    if not animalData.foodGroups[j].disabled then
                                        activeItemsBefore = activeItemsBefore + 1
                                    end
                                end

                                RmLogging.logDebug("DEBUG: Inserting %s at XML position %d, activeItemsBefore=%d",
                                    configGroup.title, i, activeItemsBefore)

                                -- Find insertion position: after the Nth non-disabled item in game array
                                local insertPosition = 1 -- Default: insert at beginning
                                if activeItemsBefore > 0 then
                                    local activeCount = 0
                                    for pos, grp in ipairs(animalFood.groups) do
                                        RmLogging.logDebug(
                                            "DEBUG:   Checking pos=%d, title=%s, disabled=%s, activeCount=%d",
                                            pos, grp.title, tostring(disabledTitles[grp.title] or false), activeCount)
                                        if not disabledTitles[grp.title] then
                                            activeCount = activeCount + 1
                                            if activeCount == activeItemsBefore then
                                                insertPosition = pos + 1
                                                RmLogging.logDebug("DEBUG:   Found match! insertPosition=%d",
                                                    insertPosition)
                                                break
                                            end
                                        end
                                    end
                                    -- If we didn't find enough active items, append at end
                                    if activeCount < activeItemsBefore then
                                        insertPosition = #animalFood.groups + 1
                                        RmLogging.logDebug("DEBUG:   Not enough active items, appending at end: %d",
                                            insertPosition)
                                    end
                                end

                                table.insert(animalFood.groups, insertPosition, newGroup)

                                RmLogging.logDebug("DEBUG: After insertion, game array:")
                                for idx, grp in ipairs(animalFood.groups) do
                                    RmLogging.logDebug("  [%d] %s", idx, grp.title)
                                end

                                applied = applied + 1
                                RmLogging.logInfo("Added custom food group: %s / %s at position %d",
                                    animalData.animalType, configGroup.title, insertPosition)
                            else
                                RmLogging.logWarning("Cannot add custom food group %s / %s: all fillTypes invalid",
                                    animalData.animalType, configGroup.title)
                            end
                        end
                    end
                end

                -- Remove disabled food groups from game
                for _, configGroup in ipairs(animalData.foodGroups) do
                    if configGroup.disabled then
                        -- Find and remove from game's groups array
                        for i = #animalFood.groups, 1, -1 do
                            if animalFood.groups[i].title == configGroup.title then
                                table.remove(animalFood.groups, i)
                                RmLogging.logInfo("Removed disabled food group: %s / %s",
                                    animalData.animalType, configGroup.title)
                                break
                            end
                        end
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
                -- First loop: UPDATE existing ingredients
                for i, configIngredient in ipairs(mixtureData.ingredients) do
                    if not configIngredient.disabled then
                        local gameIngredient = gameMixture.ingredients[i]

                        if gameIngredient then
                            -- UPDATE existing ingredient
                            gameIngredient.weight = configIngredient.weight

                            if configIngredient.fillTypes then
                                local context = string.format("mixture %s ingredient %d",
                                    mixtureData.fillType, i)
                                local newFillTypes = RmAafDataConverters.parseFillTypesFromString(
                                    configIngredient.fillTypes, context)

                                if newFillTypes then
                                    gameIngredient.fillTypes = newFillTypes
                                end
                            end

                            RmLogging.logDebug("Applied ingredient %d for mixture %s: weight=%.3f",
                                i, mixtureData.fillType, configIngredient.weight)
                        end
                    end
                end

                -- Second loop: INSERT custom ingredients at correct positions
                for i, configIngredient in ipairs(mixtureData.ingredients) do
                    if not configIngredient.disabled then
                        local gameIngredient = gameMixture.ingredients[i]

                        if not gameIngredient then
                            -- INSERT new ingredient (custom addition)
                            local context = string.format("mixture %s ingredient %d",
                                mixtureData.fillType, i)
                            local fillTypeIndices = RmAafDataConverters.parseFillTypesFromString(
                                configIngredient.fillTypes, context)

                            if fillTypeIndices then
                                local newIngredient = {
                                    weight = configIngredient.weight,
                                    fillTypes = fillTypeIndices
                                }

                                -- Calculate correct insertion position by counting non-disabled items before this one in XML
                                local activeItemsBefore = 0
                                for j = 1, i - 1 do
                                    if not mixtureData.ingredients[j].disabled then
                                        activeItemsBefore = activeItemsBefore + 1
                                    end
                                end

                                -- For mixtures, insertion is simpler: just insert at position
                                -- (ingredients are always at end of array after updates)
                                local insertPosition = activeItemsBefore + 1
                                table.insert(gameMixture.ingredients, insertPosition, newIngredient)

                                RmLogging.logInfo("Added custom ingredient %d to mixture %s at position %d",
                                    i, mixtureData.fillType, insertPosition)
                            else
                                RmLogging.logWarning(
                                    "Cannot add custom ingredient %d to mixture %s: all fillTypes invalid",
                                    i, mixtureData.fillType)
                            end
                        end

                        mixturesApplied = mixturesApplied + 1
                    end
                end

                -- Remove disabled ingredients from game (reverse iteration to handle index shifts)
                for i = #mixtureData.ingredients, 1, -1 do
                    if mixtureData.ingredients[i].disabled and gameMixture.ingredients[i] then
                        table.remove(gameMixture.ingredients, i)
                        RmLogging.logInfo("Removed disabled ingredient %d from mixture %s",
                            i, mixtureData.fillType)
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
                -- First loop: UPDATE existing ingredients
                for i, configIngredient in ipairs(recipeData.ingredients) do
                    if not configIngredient.disabled then
                        local gameIngredient = gameRecipe.ingredients[i]

                        if gameIngredient then
                            -- UPDATE existing ingredient
                            gameIngredient.minPercentage = configIngredient.minPercentage / 100
                            gameIngredient.maxPercentage = configIngredient.maxPercentage / 100

                            -- Recalculate ratio
                            gameIngredient.ratio = gameIngredient.maxPercentage - gameIngredient.minPercentage

                            if configIngredient.fillTypes then
                                local context = string.format("recipe %s ingredient %d (%s)",
                                    recipeData.fillType, i, configIngredient.name)
                                local newFillTypes = RmAafDataConverters.parseFillTypesFromString(
                                    configIngredient.fillTypes, context)

                                if newFillTypes then
                                    gameIngredient.fillTypes = newFillTypes
                                end
                            end

                            RmLogging.logDebug("Applied ingredient %d (%s) for recipe %s",
                                i, configIngredient.name, recipeData.fillType)
                        end
                    end
                end

                -- Second loop: INSERT custom ingredients at correct positions
                for i, configIngredient in ipairs(recipeData.ingredients) do
                    if not configIngredient.disabled then
                        local gameIngredient = gameRecipe.ingredients[i]

                        if not gameIngredient then
                            -- INSERT new ingredient (custom addition)
                            local context = string.format("recipe %s ingredient %d (%s)",
                                recipeData.fillType, i, configIngredient.name)
                            local fillTypeIndices = RmAafDataConverters.parseFillTypesFromString(
                                configIngredient.fillTypes, context)

                            if fillTypeIndices then
                                local newIngredient = {
                                    name = configIngredient.name,
                                    title = configIngredient.title,
                                    minPercentage = configIngredient.minPercentage / 100,
                                    maxPercentage = configIngredient.maxPercentage / 100,
                                    fillTypes = fillTypeIndices
                                }

                                -- Calculate ratio for new ingredient
                                newIngredient.ratio = newIngredient.maxPercentage - newIngredient.minPercentage

                                -- Calculate correct insertion position by counting non-disabled items before this one in XML
                                local activeItemsBefore = 0
                                for j = 1, i - 1 do
                                    if not recipeData.ingredients[j].disabled then
                                        activeItemsBefore = activeItemsBefore + 1
                                    end
                                end

                                -- For recipes, insertion is simpler: just insert at position
                                -- (ingredients are always at end of array after updates)
                                local insertPosition = activeItemsBefore + 1
                                table.insert(gameRecipe.ingredients, insertPosition, newIngredient)

                                RmLogging.logInfo("Added custom ingredient %d (%s) to recipe %s at position %d",
                                    i, configIngredient.name, recipeData.fillType, insertPosition)
                            else
                                RmLogging.logWarning(
                                    "Cannot add custom ingredient %d (%s) to recipe %s: all fillTypes invalid",
                                    i, configIngredient.name, recipeData.fillType)
                            end
                        end

                        recipesApplied = recipesApplied + 1
                    end
                end

                -- Remove disabled ingredients from game (reverse iteration to handle index shifts)
                for i = #recipeData.ingredients, 1, -1 do
                    if recipeData.ingredients[i].disabled and gameRecipe.ingredients[i] then
                        table.remove(gameRecipe.ingredients, i)
                        RmLogging.logInfo("Removed disabled ingredient %d from recipe %s",
                            i, recipeData.fillType)
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
