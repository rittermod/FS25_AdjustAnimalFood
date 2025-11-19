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

    -- Create extended schema with our custom 'disabled' attribute
    local schema = AnimalFoodSystem.xmlSchema
    if schema then
        -- Register disabled attribute for food groups
        schema:register(XMLValueType.BOOL, "animalFood.animals.animal(?).foodGroup(?)#disabled",
            "Disable this food group")

        -- Register disabled attribute for mixture and recipe ingredients
        -- Note: Entire mixtures/recipes cannot be disabled, but individual ingredients can be
        schema:register(XMLValueType.BOOL, "animalFood.mixtures.mixture(?).ingredient(?)#disabled",
            "Disable this ingredient")
        schema:register(XMLValueType.BOOL, "animalFood.recipes.recipe(?).ingredient(?)#disabled",
            "Disable this ingredient")

        -- Register documentation element (written but ignored on load)
        schema:register(XMLValueType.STRING, "animalFood.documentation", "User documentation")

        -- Register example elements for animals (written but ignored on load)
        schema:register(XMLValueType.STRING, "animalFood.animals.animal(?).example#description", "Example description")
        schema:register(XMLValueType.STRING, "animalFood.animals.animal(?).example.foodGroup#title",
            "Example food group title")
        schema:register(XMLValueType.FLOAT, "animalFood.animals.animal(?).example.foodGroup#productionWeight",
            "Example production weight")
        schema:register(XMLValueType.FLOAT, "animalFood.animals.animal(?).example.foodGroup#eatWeight",
            "Example eat weight")
        schema:register(XMLValueType.STRING, "animalFood.animals.animal(?).example.foodGroup#fillTypes",
            "Example fill types")
        schema:register(XMLValueType.BOOL, "animalFood.animals.animal(?).example.foodGroup#disabled",
            "Example disabled flag")

        -- Register example elements for mixtures (written but ignored on load)
        schema:register(XMLValueType.STRING, "animalFood.mixtures.mixture(?).example#description", "Example description")
        schema:register(XMLValueType.FLOAT, "animalFood.mixtures.mixture(?).example.ingredient#weight", "Example weight")
        schema:register(XMLValueType.STRING, "animalFood.mixtures.mixture(?).example.ingredient#fillTypes",
            "Example fill types")
        schema:register(XMLValueType.BOOL, "animalFood.mixtures.mixture(?).example.ingredient#disabled",
            "Example disabled flag")

        -- Register example elements for recipes (written but ignored on load)
        schema:register(XMLValueType.STRING, "animalFood.recipes.recipe(?).example#description", "Example description")
        schema:register(XMLValueType.STRING, "animalFood.recipes.recipe(?).example.ingredient#name", "Example name")
        schema:register(XMLValueType.STRING, "animalFood.recipes.recipe(?).example.ingredient#title", "Example title")
        schema:register(XMLValueType.INT, "animalFood.recipes.recipe(?).example.ingredient#minPercentage",
            "Example min percentage")
        schema:register(XMLValueType.INT, "animalFood.recipes.recipe(?).example.ingredient#maxPercentage",
            "Example max percentage")
        schema:register(XMLValueType.STRING, "animalFood.recipes.recipe(?).example.ingredient#fillTypes",
            "Example fill types")
        schema:register(XMLValueType.BOOL, "animalFood.recipes.recipe(?).example.ingredient#disabled",
            "Example disabled flag")
    end

    local xmlFile = XMLFile.load("animalFoodAdjust", filePath, schema)
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

                -- Read disabled attribute (only set if explicitly true)
                local disabled = xmlFile:getValue(groupKey .. "#disabled")
                if disabled == true then
                    foodGroup.disabled = true
                end

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

            -- Read disabled attribute (only set if explicitly true)
            local disabled = xmlFile:getValue(ingredientKey .. "#disabled")
            if disabled == true then
                ingredient.disabled = true
            end

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

            -- Read disabled attribute (only set if explicitly true)
            local disabled = xmlFile:getValue(ingredientKey .. "#disabled")
            if disabled == true then
                ingredient.disabled = true
            end

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

    -- Write documentation element (will be ignored during load)
    local docText = [[IMPORTANT: 5-ENTRY LIMIT
Keep total ACTIVE (non-disabled) food groups/ingredients to 5 or fewer per animal/mixture/recipe.
The game UI may not display or handle more than 5 correctly. If adding custom entries, consider disabling existing ones.

WARNING: NEVER DISABLE GRASS!
Do NOT disable the Grass food group - the game's Meadow system depends on it and disabling causes game hang.
Other food groups may have hidden dependencies. Disable with caution and test thoroughly.
Adjust weights/fillTypes instead of disabling when unsure.

SIMPLE USE CASES:

1. ADJUST FOOD EFFECTIVENESS (productionWeight):
   Change productionWeight to make food more/less effective (range: 0.0 to 1.0, higher = better)
   Example: foodGroup title="Hay" productionWeight="1.0" eatWeight="1.0" fillTypes="DRYGRASS_WINDROW"

2. ADD CROPS TO FOOD GROUP (fillTypes):
   Add space-separated crop names to existing food groups
   Example: foodGroup title="Grain" fillTypes="WHEAT BARLEY SORGHUM OAT"

3. DISABLE UNWANTED ITEMS:
   Add disabled="true" to any food group, mixture ingredient, or recipe ingredient
   Disabled items are removed from game but preserved in this file
   Remaining items automatically normalize their weights/percentages

4. CHANGE FEEDING BEHAVIOR (consumptionType):
   Control how animals consume multiple food types

   SERIAL (default for COW, SHEEP, CHICKEN, HORSE): Animals eat one food at a time in priority order
   - Example: Cows eat Hay until depleted, then Silage, then Grass
   - eatWeight is IGNORED (only productionWeight affects productivity)

   PARALLEL (default for PIG): Animals eat all available foods simultaneously
   - Example: Pigs consume Base (50%) + Grain (25%) + Protein (20%) + Roots (5%)
   - eatWeight MATTERS (determines consumption proportions)

   To change: <animal animalType="COW" consumptionType="PARALLEL">

   Note: When changing SERIAL→PARALLEL, configure eatWeight values appropriately.
   Equal eatWeights = equal consumption. Unequal eatWeights = proportional consumption.

See examples below for each section.
Full documentation: https://github.com/rittermod/FS25_AdjustAnimalFood]]
    setXMLString(xmlFile, "animalFood.documentation", docText)

    -- Save animals
    for animalIndex, animal in ipairs(data.animals) do
        local animalKey = string.format("animalFood.animals.animal(%d)", animalIndex - 1)
        setXMLString(xmlFile, animalKey .. "#animalType", animal.animalType)
        setXMLString(xmlFile, animalKey .. "#consumptionType", animal.consumptionType)

        -- Add example for first animal showing weight adjustment and fillTypes modification
        if animalIndex == 1 then
            local exampleKey = animalKey .. ".example"
            setXMLString(xmlFile, exampleKey .. "#description",
                "EXAMPLES: (1) Adjust productionWeight to change effectiveness (0.0-1.0, higher=better). (2) Add crops to fillTypes space-separated. (3) Add disabled=\"true\" to disable.")
            setXMLString(xmlFile, exampleKey .. ".foodGroup#title", "ExampleFoodGroup")
            setXMLFloat(xmlFile, exampleKey .. ".foodGroup#productionWeight", 0.9)
            setXMLFloat(xmlFile, exampleKey .. ".foodGroup#eatWeight", 1.0)
            setXMLString(xmlFile, exampleKey .. ".foodGroup#fillTypes", "EXAMPLE_FILLTYPE1 EXAMPLE_FILLTYPE2")
            setXMLBool(xmlFile, exampleKey .. ".foodGroup#disabled", true)
        end

        for groupIndex, foodGroup in ipairs(animal.foodGroups) do
            local groupKey = string.format("%s.foodGroup(%d)", animalKey, groupIndex - 1)
            setXMLString(xmlFile, groupKey .. "#title", foodGroup.title)
            setXMLFloat(xmlFile, groupKey .. "#productionWeight", foodGroup.productionWeight)
            setXMLFloat(xmlFile, groupKey .. "#eatWeight", foodGroup.eatWeight)
            setXMLString(xmlFile, groupKey .. "#fillTypes", foodGroup.fillTypes)

            -- Only write disabled="true" if item is disabled
            if foodGroup.disabled then
                setXMLBool(xmlFile, groupKey .. "#disabled", true)
            end
        end

        RmLogging.logDebug("Saved animal %s with %d food groups", animal.animalType, #animal.foodGroups)
    end

    -- Save mixtures
    for mixtureIndex, mixture in ipairs(data.mixtures) do
        local mixtureKey = string.format("animalFood.mixtures.mixture(%d)", mixtureIndex - 1)
        setXMLString(xmlFile, mixtureKey .. "#fillType", mixture.fillType)
        setXMLString(xmlFile, mixtureKey .. "#animalType", mixture.animalType)

        -- Add example for first mixture showing weight adjustment and fillTypes modification
        if mixtureIndex == 1 then
            local exampleKey = mixtureKey .. ".example"
            setXMLString(xmlFile, exampleKey .. "#description",
                "EXAMPLES: (1) Adjust weight to change proportions (auto-normalized to 100%). (2) Add crops to fillTypes space-separated. (3) Add disabled=\"true\" to disable.")
            setXMLFloat(xmlFile, exampleKey .. ".ingredient#weight", 0.3)
            setXMLString(xmlFile, exampleKey .. ".ingredient#fillTypes", "EXAMPLE_FILLTYPE1 EXAMPLE_FILLTYPE2")
            setXMLBool(xmlFile, exampleKey .. ".ingredient#disabled", true)
        end

        for ingredientIndex, ingredient in ipairs(mixture.ingredients) do
            local ingredientKey = string.format("%s.ingredient(%d)", mixtureKey, ingredientIndex - 1)
            setXMLFloat(xmlFile, ingredientKey .. "#weight", ingredient.weight)
            setXMLString(xmlFile, ingredientKey .. "#fillTypes", ingredient.fillTypes)

            -- Only write disabled="true" if ingredient is disabled
            if ingredient.disabled then
                setXMLBool(xmlFile, ingredientKey .. "#disabled", true)
            end
        end

        RmLogging.logDebug("Saved mixture %s for %s", mixture.fillType, mixture.animalType)
    end

    -- Save recipes
    for recipeIndex, recipe in ipairs(data.recipes) do
        local recipeKey = string.format("animalFood.recipes.recipe(%d)", recipeIndex - 1)
        setXMLString(xmlFile, recipeKey .. "#fillType", recipe.fillType)

        -- Add example for first recipe showing percentage adjustment and fillTypes modification
        if recipeIndex == 1 then
            local exampleKey = recipeKey .. ".example"
            setXMLString(xmlFile, exampleKey .. "#description",
                "EXAMPLES: (1) Adjust min/maxPercentage to change recipe flexibility (0-100, auto-normalized). (2) Add crops to fillTypes space-separated. (3) Add disabled=\"true\" to disable.")
            setXMLString(xmlFile, exampleKey .. ".ingredient#name", "exampleIngredient")
            setXMLString(xmlFile, exampleKey .. ".ingredient#title", "Example Ingredient")
            setXMLInt(xmlFile, exampleKey .. ".ingredient#minPercentage", 10)
            setXMLInt(xmlFile, exampleKey .. ".ingredient#maxPercentage", 50)
            setXMLString(xmlFile, exampleKey .. ".ingredient#fillTypes", "EXAMPLE_FILLTYPE1 EXAMPLE_FILLTYPE2")
            setXMLBool(xmlFile, exampleKey .. ".ingredient#disabled", true)
        end

        for ingredientIndex, ingredient in ipairs(recipe.ingredients) do
            local ingredientKey = string.format("%s.ingredient(%d)", recipeKey, ingredientIndex - 1)
            setXMLString(xmlFile, ingredientKey .. "#name", ingredient.name)
            setXMLString(xmlFile, ingredientKey .. "#title", ingredient.title)
            setXMLInt(xmlFile, ingredientKey .. "#minPercentage", ingredient.minPercentage)
            setXMLInt(xmlFile, ingredientKey .. "#maxPercentage", ingredient.maxPercentage)
            setXMLString(xmlFile, ingredientKey .. "#fillTypes", ingredient.fillTypes)

            -- Only write disabled="true" if ingredient is disabled
            if ingredient.disabled then
                setXMLBool(xmlFile, ingredientKey .. "#disabled", true)
            end
        end

        RmLogging.logDebug("Saved recipe %s with %d ingredients", recipe.fillType, #recipe.ingredients)
    end

    saveXMLFile(xmlFile)
    delete(xmlFile)

    RmLogging.logInfo("Successfully saved %d animals, %d mixtures, %d recipes to XML",
        #data.animals, #data.mixtures, #data.recipes)

    return true
end
