--[[
    RmAafDataConverters.lua

    Data type conversion utilities for RmAdjustAnimalFood mod.
    Provides pure utility functions for converting between game data types
    and string representations, plus normalization helpers.

    Module: RmAafDataConverters
    Dependencies: None (pure utilities)

    Author: Ritter
]]

RmAafDataConverters = {}

-- ============================================================================
-- TYPE CONVERSION FUNCTIONS
-- ============================================================================

---Converts animal type index to name
---@param animalTypeIndex number Animal type index
---@return string|nil animalName Animal type name or nil
function RmAafDataConverters.getAnimalNameFromIndex(animalTypeIndex)
    if not g_currentMission or not g_currentMission.animalSystem then
        return nil
    end

    return g_currentMission.animalSystem.typeIndexToName[animalTypeIndex]
end

---Converts consumption type number to string
---@param consumptionType number Consumption type (1=SERIAL, 2=PARALLEL)
---@return string consumptionTypeName "SERIAL" or "PARALLEL"
function RmAafDataConverters.getConsumptionTypeName(consumptionType)
    if consumptionType == AnimalFoodSystem.FOOD_CONSUME_TYPE_PARALLEL then
        return "PARALLEL"
    end
    return "SERIAL"
end

---Converts fill type indices array to space-separated string of names
---@param fillTypes table Array of fill type indices
---@return string fillTypeNames Space-separated fill type names
function RmAafDataConverters.getFillTypeNamesString(fillTypes)
    local names = {}
    for _, fillTypeIndex in ipairs(fillTypes) do
        local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex)
        if fillTypeName then
            table.insert(names, fillTypeName)
        end
    end
    return table.concat(names, " ")
end

---Parses space-separated fillType names and converts to indices array
---@param fillTypeString string Space-separated fillType names (e.g. "WHEAT BARLEY OAT")
---@param context string Context description for logging (e.g. "COW / forage")
---@return table|nil fillTypeIndices Array of fillType indices, or nil if none valid
function RmAafDataConverters.parseFillTypesFromString(fillTypeString, context)
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

-- ============================================================================
-- NORMALIZATION FUNCTIONS
-- ============================================================================

---Normalizes ingredient weights to sum to 1.0
---@param ingredients table Array of ingredients with weight field
---@return boolean success True if normalization was performed
function RmAafDataConverters.normalizeWeights(ingredients)
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
function RmAafDataConverters.normalizeRatios(ingredients)
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
