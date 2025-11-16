--[[
    RmAafDataMerger.lua

    Merges XML configuration with game defaults.
    Merge strategy: XML values override user customizations,
    game can add new content from mods/updates.

    Module: RmAafDataMerger
    Dependencies: None (pure data manipulation)

    Author: Ritter
]]

RmAafDataMerger = {}

-- ============================================================================
-- INTERNAL HELPERS: Merging specific data sections
-- ============================================================================

---Merges animal data (XML overrides, game adds new content)
---@param xmlAnimals table XML animal configurations
---@param gameAnimals table Game animal configurations
---@param preserveAllXmlOnly boolean If true, preserve all XML-only items. If false, only disabled
---@return table merged Merged animal configurations
local function mergeAnimals(xmlAnimals, gameAnimals, preserveAllXmlOnly)
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
                        fillTypes = xmlGroup.fillTypes,
                        disabled = xmlGroup.disabled
                    })
                else
                    -- New group from game - add with game defaults
                    table.insert(mergedAnimal.foodGroups, gameGroup)
                    RmLogging.logDebug("New food group added: %s / %s", gameAnimal.animalType, gameGroup.title)
                end
            end

            -- Add disabled XML-only groups (user disabled, not in game anymore)
            for _, xmlGroup in ipairs(xmlAnimal.foodGroups) do
                local foundInGame = false
                for _, gameGroup in ipairs(gameAnimal.foodGroups) do
                    if gameGroup.title == xmlGroup.title then
                        foundInGame = true
                        break
                    end
                end

                -- Preserve based on context: all XML-only at startup, only disabled at save
                if not foundInGame and (preserveAllXmlOnly or xmlGroup.disabled) then
                    table.insert(mergedAnimal.foodGroups, {
                        title = xmlGroup.title,
                        productionWeight = xmlGroup.productionWeight,
                        eatWeight = xmlGroup.eatWeight,
                        fillTypes = xmlGroup.fillTypes,
                        disabled = xmlGroup.disabled
                    })
                    RmLogging.logDebug("Preserving disabled food group: %s / %s", gameAnimal.animalType, xmlGroup.title)
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
---Note: Mixtures cannot be disabled, only modified
---@param xmlMixtures table XML mixture configurations
---@param gameMixtures table Game mixture configurations
---@param preserveAllXmlOnly boolean If true, preserve all XML-only items
---@return table merged Merged mixture configurations
local function mergeMixtures(xmlMixtures, gameMixtures, preserveAllXmlOnly)
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

    -- Add XML-only mixtures (for Part 2 custom additions)
    if preserveAllXmlOnly then
        for _, xmlMixture in ipairs(xmlMixtures) do
            local key = xmlMixture.fillType .. "_" .. xmlMixture.animalType
            local foundInGame = false
            for _, gameMixture in ipairs(gameMixtures) do
                local gameKey = gameMixture.fillType .. "_" .. gameMixture.animalType
                if gameKey == key then
                    foundInGame = true
                    break
                end
            end

            if not foundInGame then
                table.insert(merged, xmlMixture)
                RmLogging.logDebug("Preserving XML-only mixture: %s for %s",
                    xmlMixture.fillType, xmlMixture.animalType)
            end
        end
    end

    return merged
end

---Merges recipe data (XML overrides, game adds new content)
---Note: Recipes cannot be disabled, only modified
---@param xmlRecipes table XML recipe configurations
---@param gameRecipes table Game recipe configurations
---@param preserveAllXmlOnly boolean If true, preserve all XML-only items
---@return table merged Merged recipe configurations
local function mergeRecipes(xmlRecipes, gameRecipes, preserveAllXmlOnly)
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

    -- Add XML-only recipes (for Part 2 custom additions)
    if preserveAllXmlOnly then
        for _, xmlRecipe in ipairs(xmlRecipes) do
            local foundInGame = false
            for _, gameRecipe in ipairs(gameRecipes) do
                if gameRecipe.fillType == xmlRecipe.fillType then
                    foundInGame = true
                    break
                end
            end

            if not foundInGame then
                table.insert(merged, xmlRecipe)
                RmLogging.logDebug("Preserving XML-only recipe: %s", xmlRecipe.fillType)
            end
        end
    end

    return merged
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

---Merges complete XML and game data
---Coordinates merging of animals, mixtures, and recipes (XML overrides, game adds new content)
---@param xmlData table Data loaded from XML (with animals, mixtures, recipes tables)
---@param gameData table Current game data (with animals, mixtures, recipes tables)
---@param preserveAllXmlOnly boolean If true, preserve all XML-only items (startup). If false, only preserve disabled items (save). Default: false
---@return table merged Merged configuration (with animals, mixtures, recipes tables)
function RmAafDataMerger:mergeData(xmlData, gameData, preserveAllXmlOnly)
    RmLogging.logInfo("Merging XML data with game data")

    local merged = {
        animals = {},
        mixtures = {},
        recipes = {}
    }

    -- Merge each section using focused functions
    preserveAllXmlOnly = preserveAllXmlOnly or false
    merged.animals = mergeAnimals(xmlData.animals, gameData.animals, preserveAllXmlOnly)
    merged.mixtures = mergeMixtures(xmlData.mixtures, gameData.mixtures, preserveAllXmlOnly)
    merged.recipes = mergeRecipes(xmlData.recipes, gameData.recipes, preserveAllXmlOnly)

    RmLogging.logInfo("Merged to %d animals, %d mixtures, %d recipes",
        #merged.animals, #merged.mixtures, #merged.recipes)

    return merged
end
