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

            -- Create lookup for game food groups
            local gameGroupsByTitle = {}
            for _, group in ipairs(gameAnimal.foodGroups) do
                gameGroupsByTitle[group.title] = group
            end

            -- Merge food groups preserving XML order
            -- First pass: Process all XML groups in XML order
            for _, xmlGroup in ipairs(xmlAnimal.foodGroups) do
                local gameGroup = gameGroupsByTitle[xmlGroup.title]

                if gameGroup then
                    -- Group exists in both XML and game - use XML values
                    table.insert(mergedAnimal.foodGroups, {
                        title = xmlGroup.title,
                        productionWeight = xmlGroup.productionWeight,
                        eatWeight = xmlGroup.eatWeight,
                        fillTypes = xmlGroup.fillTypes,
                        disabled = xmlGroup.disabled
                    })
                else
                    -- XML-only group (custom addition or disabled)
                    -- Preserve based on context: all XML-only at startup, only disabled at save
                    if preserveAllXmlOnly or xmlGroup.disabled then
                        table.insert(mergedAnimal.foodGroups, {
                            title = xmlGroup.title,
                            productionWeight = xmlGroup.productionWeight,
                            eatWeight = xmlGroup.eatWeight,
                            fillTypes = xmlGroup.fillTypes,
                            disabled = xmlGroup.disabled
                        })
                        if xmlGroup.disabled then
                            RmLogging.logDebug("Preserving disabled food group: %s / %s", gameAnimal.animalType, xmlGroup.title)
                        else
                            RmLogging.logDebug("Preserving custom food group: %s / %s", gameAnimal.animalType, xmlGroup.title)
                        end
                    end
                end
            end

            -- Second pass: Add NEW game groups not in XML (from mods/updates)
            for _, gameGroup in ipairs(gameAnimal.foodGroups) do
                local foundInXml = false
                for _, xmlGroup in ipairs(xmlAnimal.foodGroups) do
                    if xmlGroup.title == gameGroup.title then
                        foundInXml = true
                        break
                    end
                end

                if not foundInXml then
                    -- New group from game - add with game defaults at end
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
---Note: Mixtures cannot be disabled, only modified
---@param xmlMixtures table XML mixture configurations
---@param gameMixtures table Game mixture configurations
---@param preserveAllXmlOnly boolean If true, preserve all XML-only items
---@return table merged Merged mixture configurations
local function mergeMixtures(xmlMixtures, gameMixtures, preserveAllXmlOnly)
    local merged = {}

    -- Create lookup table for game mixtures
    local gameMixturesByKey = {}
    for _, mixture in ipairs(gameMixtures) do
        local key = mixture.fillType .. "_" .. mixture.animalType
        gameMixturesByKey[key] = mixture
    end

    -- Merge preserving XML order
    -- First pass: Process all XML mixtures in XML order
    for _, xmlMixture in ipairs(xmlMixtures) do
        local key = xmlMixture.fillType .. "_" .. xmlMixture.animalType
        local gameMixture = gameMixturesByKey[key]

        if gameMixture then
            -- Mixture exists in both - use XML
            table.insert(merged, xmlMixture)
        else
            -- XML-only mixture (custom addition)
            if preserveAllXmlOnly then
                table.insert(merged, xmlMixture)
                RmLogging.logDebug("Preserving XML-only mixture: %s for %s",
                    xmlMixture.fillType, xmlMixture.animalType)
            end
        end
    end

    -- Second pass: Add NEW game mixtures not in XML (from mods/updates)
    for _, gameMixture in ipairs(gameMixtures) do
        local key = gameMixture.fillType .. "_" .. gameMixture.animalType
        local foundInXml = false
        for _, xmlMixture in ipairs(xmlMixtures) do
            local xmlKey = xmlMixture.fillType .. "_" .. xmlMixture.animalType
            if xmlKey == key then
                foundInXml = true
                break
            end
        end

        if not foundInXml then
            table.insert(merged, gameMixture)
            RmLogging.logDebug("New mixture added: %s for %s", gameMixture.fillType, gameMixture.animalType)
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

    -- Create lookup table for game recipes
    local gameRecipesByFillType = {}
    for _, recipe in ipairs(gameRecipes) do
        gameRecipesByFillType[recipe.fillType] = recipe
    end

    -- Merge preserving XML order
    -- First pass: Process all XML recipes in XML order
    for _, xmlRecipe in ipairs(xmlRecipes) do
        local gameRecipe = gameRecipesByFillType[xmlRecipe.fillType]

        if gameRecipe then
            -- Recipe exists in both - use XML
            table.insert(merged, xmlRecipe)
        else
            -- XML-only recipe (custom addition)
            if preserveAllXmlOnly then
                table.insert(merged, xmlRecipe)
                RmLogging.logDebug("Preserving XML-only recipe: %s", xmlRecipe.fillType)
            end
        end
    end

    -- Second pass: Add NEW game recipes not in XML (from mods/updates)
    for _, gameRecipe in ipairs(gameRecipes) do
        local foundInXml = false
        for _, xmlRecipe in ipairs(xmlRecipes) do
            if xmlRecipe.fillType == gameRecipe.fillType then
                foundInXml = true
                break
            end
        end

        if not foundInXml then
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

    -- Merge consumption multiplier settings (XML takes precedence, or use defaults)
    if xmlData.consumptionMultiplier then
        merged.consumptionMultiplier = {
            multiplier = xmlData.consumptionMultiplier.multiplier or 1.0,
            disabled = xmlData.consumptionMultiplier.disabled
        }
        -- Handle nil disabled (treat as true/disabled by default)
        if merged.consumptionMultiplier.disabled == nil then
            merged.consumptionMultiplier.disabled = true
        end
    else
        -- No consumption multiplier in XML - use defaults (disabled)
        merged.consumptionMultiplier = {
            multiplier = 1.0,
            disabled = true
        }
    end

    RmLogging.logInfo("Merged to %d animals, %d mixtures, %d recipes",
        #merged.animals, #merged.mixtures, #merged.recipes)

    return merged
end
