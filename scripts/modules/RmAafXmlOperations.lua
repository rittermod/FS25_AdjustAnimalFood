--[[
    RmAafXmlOperations.lua

    XML serialization and deserialization for animal food configuration.
    Uses AnimalFoodSystem.xmlSchema for validation on load,
    and Giants Engine XML API for saving.

    Module: RmAafXmlOperations
    Dependencies: None

    Note: We use translated text in XML instead of $l10n_ keys because:
    1. The game's convertText() has already translated titles when we read them
    2. Reverse lookup would require scanning all possible l10n keys
    3. Using translated text works - it's just language-specific
    Users can manually edit to use $l10n_ keys if they want language-independence

    Author: Ritter
]]

RmAafXmlOperations = {}

-- ============================================================================
-- XML LOADING
-- ============================================================================

---Loads animal food configuration from XML using schema
---@param filePath string Path to XML file
---@return table|nil data Loaded configuration or nil on error
function RmAafXmlOperations:loadFromXML(filePath)
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

-- ============================================================================
-- XML SAVING
-- ============================================================================

---Saves animal food configuration to XML
---@param data table Configuration data to save
---@param filePath string Path to XML file
---@return boolean success True if save was successful
function RmAafXmlOperations:saveToXML(data, filePath)
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
