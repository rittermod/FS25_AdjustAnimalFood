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

-- ============================================================================
-- PUBLIC API
-- ============================================================================

---Merges complete XML and game data
---Coordinates merging of animals, mixtures, and recipes (XML overrides, game adds new content)
---@param xmlData table Data loaded from XML (with animals, mixtures, recipes tables)
---@param gameData table Current game data (with animals, mixtures, recipes tables)
---@return table merged Merged configuration (with animals, mixtures, recipes tables)
function RmAafDataMerger:mergeData(xmlData, gameData)
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
