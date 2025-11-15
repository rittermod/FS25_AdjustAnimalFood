--[[
    main.lua

    Main loader for RmAdjustAnimalFood mod.
    Loads all dependencies in the correct order.

    Author: Ritter
]]

local modDirectory = g_currentModDirectory

-- Load logging utility first (required by all other files)
source(modDirectory .. "scripts/RmLogging.lua")

-- Load event classes (required before main mod logic)
source(modDirectory .. "scripts/events/RmAnimalFoodSyncEvent.lua")

-- Load modules in dependency order
-- DataConverters has no dependencies
source(modDirectory .. "scripts/modules/RmAafDataConverters.lua")

-- XmlOperations, DataMerger are independent
source(modDirectory .. "scripts/modules/RmAafXmlOperations.lua")
source(modDirectory .. "scripts/modules/RmAafDataMerger.lua")

-- GameDataReader and GameApplicator depend on DataConverters
source(modDirectory .. "scripts/modules/RmAafGameDataReader.lua")
source(modDirectory .. "scripts/modules/RmAafGameApplicator.lua")

-- Load main mod logic last (depends on all modules)
source(modDirectory .. "scripts/RmAdjustAnimalFood.lua")
