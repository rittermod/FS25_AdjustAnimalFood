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

        -- Register readme element (written but ignored on load)
        schema:register(XMLValueType.STRING, "animalFood.readme", "Brief usage guide pointer")
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

    -- Write brief readme pointer
    local readmeText = "Configuration guide and examples available in 'documentation' section at end of this file. Full documentation: https://github.com/rittermod/FS25_AdjustAnimalFood"
    setXMLString(xmlFile, "animalFood.readme", readmeText)

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

    -- Write comprehensive documentation at end of file
    local docText = [[

========================================
ADJUST ANIMAL FOOD - Configuration Guide
========================================

⚠️ CRITICAL WARNINGS
--------------------
• 5-ENTRY LIMIT: Keep total ACTIVE (non-disabled) items to 5 or fewer per animal/mixture/recipe.
  The game UI may not display or handle more than 5 correctly. If adding custom entries, disable existing ones first.

• NEVER DISABLE GRASS: Do NOT disable the Grass food group. The game's Meadow system depends on it
  and disabling will cause game hang. Other food groups may have hidden dependencies - disable with caution.

• BACKUP FIRST: Always back up your savegame before making major changes.


QUICK START
-----------
Common tasks with minimal examples:

1. ADJUST FOOD EFFECTIVENESS
   Change productionWeight (0.0-1.0, higher = better productivity):

    foodGroup title="Hay" productionWeight="1.0" eatWeight="1.0" fillTypes="DRYGRASS_WINDROW"

2. ADD CROPS TO FOOD GROUP
   Add space-separated crop names to fillTypes:

    foodGroup title="Grain" fillTypes="WHEAT BARLEY SORGHUM OAT"

3. DISABLE UNWANTED ITEMS
   Add disabled="true" to remove from game (preserved in file):

    foodGroup title="Straw" productionWeight="0.2" eatWeight="1.0" fillTypes="STRAW" disabled="true"

4. CHANGE FEEDING BEHAVIOR
   Modify consumptionType (SERIAL = sequential, PARALLEL = simultaneous):

    animal animalType="COW" consumptionType="PARALLEL"


ANIMALS SECTION REFERENCE
--------------------------
Attributes you can modify:

• productionWeight (0.0-1.0): Food effectiveness for productivity. Higher = better.
• eatWeight (0.0-1.0): Consumption proportion (PARALLEL mode only, ignored in SERIAL).
• consumptionType ("SERIAL" or "PARALLEL"): How animals consume multiple foods.
  - SERIAL: Eat one food completely before moving to next (default: COW, SHEEP, CHICKEN, HORSE)
           eatWeight is IGNORED, only productionWeight affects productivity
  - PARALLEL: Eat all foods simultaneously based on eatWeight (default: PIG)
             eatWeight determines consumption proportions
• fillTypes: Space-separated crop names (e.g., "WHEAT BARLEY OAT").
• disabled ("true"): Remove this food group from game (cannot disable Grass!).

Attributes you CANNOT modify:
• animalType: Used for matching only
• title: Used for matching only


MIXTURES SECTION REFERENCE
---------------------------
Controls mixed feed recipes like PIGFOOD.

Attributes you can modify:

• weight: Ingredient proportion (any positive number, auto-normalized to 1.0).
          Example: weights 50, 25, 20, 5 become 0.5, 0.25, 0.2, 0.05
• fillTypes: Space-separated crop names for this ingredient slot.
• disabled ("true" on ingredient): Remove this ingredient from mixture.

Notes:
- Weights are automatically normalized to sum to 100%
- When you disable an ingredient, remaining ingredients are auto-normalized
- Ingredient order must match game's order
- You cannot disable entire mixtures, only individual ingredients


RECIPES SECTION REFERENCE
--------------------------
Controls TMR/Forage recipes for mixing wagons.

Attributes you can modify:

• minPercentage (0-100): Minimum percentage for this ingredient in TMR mixer UI.
• maxPercentage (0-100): Maximum percentage for this ingredient in TMR mixer UI.
• fillTypes: Space-separated crop names for this ingredient.
• disabled ("true" on ingredient): Remove this ingredient from recipe completely.

Attributes you CANNOT modify:
• name: Internal identifier
• title: Display name

Notes:
- Percentages define valid range in TMR mixer UI
- Ratios are automatically normalized based on your min/max ranges
- When you disable an ingredient, it's removed from TMR mixer UI
- You cannot disable entire recipes, only individual ingredients


PRACTICAL EXAMPLES
-------------------
Copy-paste ready examples for common tasks:


EXAMPLE: Make Hay More Effective for Cows
------------------------------------------
Increase productionWeight from 0.8 to 1.0:

    foodGroup title="Hay" productionWeight="1.0" eatWeight="1.0" fillTypes="DRYGRASS_WINDROW"

Result: Hay is now fully effective (100%) for cow productivity.


EXAMPLE: Add Oat to Chicken Feed
---------------------------------
Find the Grain food group for CHICKEN and add OAT:

    foodGroup title="Grain" productionWeight="1.0" eatWeight="1.0" fillTypes="WHEAT BARLEY SORGHUM OAT"

Result: Chickens can now eat oat along with other grains.


EXAMPLE: Disable Hay for Cows
------------------------------
Add disabled="true" to the Hay food group:

    foodGroup title="Hay" productionWeight="0.8" eatWeight="1.0" fillTypes="DRYGRASS_WINDROW" disabled="true"

Result: Cows no longer accept hay. Food group removed from game but stays in XML.


EXAMPLE: Change COW to Parallel Feeding (Mixed Ration)
-------------------------------------------------------
Simulate realistic mixed ration where cows eat all foods simultaneously:

    animal animalType="COW" consumptionType="PARALLEL"
        foodGroup title="Hay" productionWeight="0.8" eatWeight="0.3" fillTypes="DRYGRASS_WINDROW"
        foodGroup title="Silage" productionWeight="1.0" eatWeight="0.5" fillTypes="SILAGE"
        foodGroup title="Grass" productionWeight="0.7" eatWeight="0.2" fillTypes="GRASS_WINDROW"

Result: Cows consume 50% silage, 30% hay, 20% grass simultaneously (based on eatWeight).
In PARALLEL mode, eatWeight controls consumption proportions.


EXAMPLE: Change PIG to Serial Feeding (One at a Time)
------------------------------------------------------
Force pigs to eat one food completely before moving to next:

    animal animalType="PIG" consumptionType="SERIAL"
        foodGroup title="Mixed Feed" productionWeight="1.0" eatWeight="1.0" fillTypes="PIGFOOD"
        foodGroup title="Grain" productionWeight="0.8" eatWeight="1.0" fillTypes="WHEAT BARLEY"
        foodGroup title="Roots" productionWeight="0.6" eatWeight="1.0" fillTypes="POTATO SUGARBEET"

Result: Pigs eat Mixed Feed first, then Grain when depleted, then Roots.
In SERIAL mode, eatWeight values are ignored.


EXAMPLE: Adjust Pig Feed Mixture Proportions
---------------------------------------------
Change PIGFOOD to use more grain, less roots:

    mixture fillType="PIGFOOD" animalType="PIG"
        ingredient weight="0.60" fillTypes="MAIZE TRITICALE"
        ingredient weight="0.30" fillTypes="SOYBEAN CANOLA"
        ingredient weight="0.10" fillTypes="POTATO"

Result: New proportions are 60% base, 30% protein, 10% roots (auto-normalized).


EXAMPLE: Allow More Silage in TMR
----------------------------------
Increase maximum silage percentage from 75% to 85%:

    ingredient name="silage" title="Silage" minPercentage="0" maxPercentage="85" fillTypes="SILAGE"

Result: TMR mixer now accepts up to 85% silage instead of default 75%.


EXAMPLE: Remove Grain from Pig Feed Mix
----------------------------------------
Disable the grain ingredient in PIGFOOD mixture:

    mixture fillType="PIGFOOD" animalType="PIG"
        ingredient weight="0.50" fillTypes="MAIZE TRITICALE"
        ingredient weight="0.25" fillTypes="WHEAT BARLEY" disabled="true"
        ingredient weight="0.20" fillTypes="SOYBEAN CANOLA"
        ingredient weight="0.05" fillTypes="POTATO SUGARBEET_CUT"

Result: Grain excluded. Remaining ingredients auto-adjust: Base 66.6%, Protein 26.6%, Roots 6.6%.


EXAMPLE: Add Custom Food Group (Respecting 5-Entry Limit)
----------------------------------------------------------
COW has 4 vanilla food groups, so you can add 1 custom (total = 5):

    animal animalType="COW" consumptionType="SERIAL"
        foodGroup title="Total Mixed Ration" productionWeight="1.0" eatWeight="1.0" fillTypes="FORAGE"
        foodGroup title="Hay" productionWeight="0.8" eatWeight="1.0" fillTypes="DRYGRASS_WINDROW"
        foodGroup title="Silage" productionWeight="0.8" eatWeight="1.0" fillTypes="SILAGE"
        foodGroup title="Grass" productionWeight="0.4" eatWeight="1.0" fillTypes="GRASS_WINDROW"
        foodGroup title="Oat" productionWeight="1.0" eatWeight="1.0" fillTypes="OAT"

Result: Added custom Oat food group. Total active entries = 5 (within limit).

WARNING: Don't exceed 5 active entries or game UI may malfunction!


TROUBLESHOOTING
---------------
Changes don't take effect:
• Save XML file after editing
• Verify file is in correct savegame folder
• Check game log for warnings about unknown fillTypes

Unknown fillType warnings:
• Check spelling of crop names (case-sensitive)
• Crop may not exist in your game/mods
• Remove invalid fillType names from config

Game crashes or hangs:
• Did you disable Grass? Re-enable it immediately!
• Too many active entries (>5)? Disable some items
• Restore backup if problems persist

Reset to defaults:
• Delete aaf_AnimalFood.xml from savegame folder
• Load savegame to regenerate fresh default file


Full documentation: https://github.com/rittermod/FS25_AdjustAnimalFood
Generated by FS25_AdjustAnimalFood mod
]]
    setXMLString(xmlFile, "animalFood.documentation", docText)

    saveXMLFile(xmlFile)
    delete(xmlFile)

    RmLogging.logInfo("Successfully saved %d animals, %d mixtures, %d recipes to XML",
        #data.animals, #data.mixtures, #data.recipes)

    return true
end
