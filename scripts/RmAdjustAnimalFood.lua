--[[
    RmAdjustAnimalFood.lua

    Animal food system modification for Farming Simulator 2025
    Main orchestrator module - coordinates initialization, lifecycle hooks, and network sync.

    Author: Ritter
    Version: 0.9.0.0

    OVERVIEW:
    This mod provides control over the animal food system using the game's
    built-in AnimalFoodSystem with schema-validated XML. It allows modification of:
    - Animal food groups (productionWeight, eatWeight, fillTypes)
    - Mixture recipes (ingredient weights and fillTypes)
    - TMR/Forage recipes (ingredient percentages and fillTypes)

    ARCHITECTURE:
    The main file orchestrates 5 specialized modules:
    - RmAafDataConverters: Type conversion utilities
    - RmAafXmlOperations: XML serialization/deserialization
    - RmAafGameDataReader: Read current state from game
    - RmAafDataMerger: Merge XML with game defaults
    - RmAafGameApplicator: Apply merged config to game

    WORKFLOW:
    1. Read current game configuration (RmAafGameDataReader)
    2. Load user XML customizations (RmAafXmlOperations)
    3. Merge XML overrides with game defaults (RmAafDataMerger)
    4. Apply merged configuration to game (RmAafGameApplicator)
    5. Save configuration for next session (RmAafXmlOperations)

    KNOWN LIMITATIONS:
    - XML uses translated text for titles instead of $l10n_ keys. If users want
      language-independent XML, they must manually edit titles to use $l10n_ keys.
]]

-- Module declaration
-- Note: Dependencies (RmLogging, events, submodules) are loaded via scripts/main.lua
RmAdjustAnimalFood = {}
RmAdjustAnimalFood.modDirectory = g_currentModDirectory
RmAdjustAnimalFood.modName = g_currentModName
RmAdjustAnimalFood.XML_FILENAME = "aaf_AnimalFood.xml"
RmAdjustAnimalFood.configData = nil -- Stores merged config for network sync

-- ============================================================================
-- CONSUMPTION MULTIPLIER: Configuration and state
-- ============================================================================

-- Mods that also modify consumption behavior - feature disabled when detected
-- Add mod folder names here to disable consumption multiplier when they're active
local INCOMPATIBLE_MODS = {
    "FS25_RealisticLivestock",
    "FS25_EnhancedAnimalSystem",
}

-- Consumption multiplier state
RmAdjustAnimalFood.consumptionMultiplier = 1.0
RmAdjustAnimalFood.consumptionMultiplierEnabled = false
RmAdjustAnimalFood.consumptionMultiplierHookApplied = false

-- Multiplier bounds
local MULTIPLIER_MIN = 0.01
local MULTIPLIER_MAX = 100

-- Configure logging
RmLogging.setLogPrefix("[RmAdjustAnimalFood]")
-- RmLogging.setLogLevel(RmLogging.LOG_LEVEL.DEBUG) -- Change to INFO or WARNING for less verbosity

-- ============================================================================
-- INITIALIZATION: Context detection and setup
-- ============================================================================

---Detects server/client context and updates logging prefix accordingly
---Called during initialization to distinguish between dedicated server, listen server, and client
---in log output. This helps with multiplayer debugging.
local function setLoggingContext()
    local prefix = "[RmAdjustAnimalFood"
    local contextName = ""

    if g_dedicatedServer ~= nil then
        prefix = prefix .. "|SERVER-DEDICATED]"
        contextName = "Dedicated Server"
    elseif g_server ~= nil and g_client ~= nil then
        prefix = prefix .. "|SERVER-LISTEN]"
        contextName = "Listen Server (Host)"
    elseif g_client ~= nil and g_server == nil then
        prefix = prefix .. "|CLIENT]"
        contextName = "Pure Client"
    else
        prefix = prefix .. "|UNKNOWN]"
        contextName = "Unknown (no g_server or g_client)"
    end

    RmLogging.setLogPrefix(prefix)
    RmLogging.logInfo("Context detected: %s", contextName)

    -- Debug: Log all detection variables for analysis
    RmLogging.logDebug(
        "g_server=%s g_client=%s g_dedicatedServer=%s g_dedicatedServerInfo=%s getUserProfileAppPath=%s getIsClient=%s getIsServer=%s isMasterUser=%s",
        tostring(g_server),
        tostring(g_client),
        tostring(g_dedicatedServer),
        tostring(g_dedicatedServerInfo),
        tostring(getUserProfileAppPath()),
        tostring(g_currentMission:getIsClient()),
        tostring(g_currentMission:getIsServer()),
        tostring(g_currentMission.isMasterUser)
    )
end

-- ============================================================================
-- CONSUMPTION MULTIPLIER: Hook implementation
-- ============================================================================

---Checks if any incompatible mods are active
---@return boolean compatible True if no incompatible mods detected
---@return string|nil incompatibleMod Name of first incompatible mod found, or nil
local function checkModCompatibility()
    for _, modName in ipairs(INCOMPATIBLE_MODS) do
        if g_modIsLoaded[modName] then
            return false, modName
        end
    end
    return true, nil
end

---Applies consumption multiplier to animal food consumption calculation
---This function replaces the vanilla onHusbandryAnimalsUpdate calculation
---@param self table PlaceableHusbandryFood instance
---@param superFunc function Original function (not called - we replace entirely)
---@param clusters table Animal clusters in the husbandry
local function applyConsumptionMultiplier(self, superFunc, clusters)
    local spec = self.spec_husbandryFood
    local multiplier = RmAdjustAnimalFood.consumptionMultiplier

    -- Replicate vanilla calculation with multiplier applied
    spec.litersPerHour = 0
    for _, cluster in ipairs(clusters) do
        local subType = g_currentMission.animalSystem:getSubTypeByIndex(cluster.subTypeIndex)
        if subType ~= nil then
            local food = subType.input.food
            if food ~= nil then
                local age = cluster:getAge()
                local litersPerAnimal = food:get(age)
                local litersPerDay = litersPerAnimal * cluster:getNumAnimals()

                -- Apply multiplier to consumption rate
                spec.litersPerHour = spec.litersPerHour + ((litersPerDay / 24) * multiplier)
            end
        end
    end
end

---Applies the consumption multiplier hook if conditions are met
---Conditions: server context, feature enabled, no incompatible mods
local function applyConsumptionMultiplierHook()
    -- Only apply on server (consumption calculation is server-side)
    if g_server == nil then
        RmLogging.logDebug("Consumption multiplier: Skipping hook (client context)")
        return
    end

    -- Check if already applied
    if RmAdjustAnimalFood.consumptionMultiplierHookApplied then
        RmLogging.logDebug("Consumption multiplier: Hook already applied")
        return
    end

    -- Check if feature is enabled
    if not RmAdjustAnimalFood.consumptionMultiplierEnabled then
        RmLogging.logDebug("Consumption multiplier: Feature disabled in config")
        return
    end

    -- Check for incompatible mods
    local compatible, incompatibleMod = checkModCompatibility()
    if not compatible then
        RmLogging.logWarning(
            "Consumption multiplier disabled: Incompatible mod detected (%s). " ..
            "This mod also modifies animal food consumption. " ..
            "Other features of AdjustAnimalFood remain active.",
            incompatibleMod
        )
        return
    end

    -- Check if multiplier is effectively 1.0 (no change needed)
    if math.abs(RmAdjustAnimalFood.consumptionMultiplier - 1.0) < 0.001 then
        RmLogging.logDebug("Consumption multiplier: Value is 1.0, no hook needed")
        return
    end

    -- Apply the hook
    if PlaceableHusbandryFood and PlaceableHusbandryFood.onHusbandryAnimalsUpdate then
        PlaceableHusbandryFood.onHusbandryAnimalsUpdate = Utils.overwrittenFunction(
            PlaceableHusbandryFood.onHusbandryAnimalsUpdate,
            applyConsumptionMultiplier
        )
        RmAdjustAnimalFood.consumptionMultiplierHookApplied = true
        RmLogging.logInfo("Consumption multiplier hook applied (%.2fx)", RmAdjustAnimalFood.consumptionMultiplier)
    else
        RmLogging.logError(
            "Failed to apply consumption multiplier: PlaceableHusbandryFood.onHusbandryAnimalsUpdate not found")
    end
end

-- ============================================================================
-- LIFECYCLE INTEGRATION: Game hooks and initialization
-- These functions hook into the game's lifecycle to load/save configuration
-- ============================================================================

---Loads configuration from XML and applies to game
---This is the main entry point called after map loading completes
---Workflow: Load XML → Read game data → Merge → Save merged → Apply to game
function RmAdjustAnimalFood.loadAndApply()
    -- Detect and log server/client context for multiplayer support
    setLoggingContext()

    -- Pure clients should wait for server sync, not load XML
    if g_client ~= nil and g_server == nil then
        RmLogging.logInfo("Waiting for server configuration sync")
        return
    end

    if not g_currentMission or not g_currentMission.missionInfo then
        RmLogging.logWarning("Mission information not available")
        return
    end

    local savegameDir = g_currentMission.missionInfo.savegameDirectory
    if not savegameDir then
        RmLogging.logWarning("Savegame directory not available")
        return
    end

    local xmlFilePath = savegameDir .. "/" .. RmAdjustAnimalFood.XML_FILENAME

    if fileExists(xmlFilePath) then
        RmLogging.logDebug("Configuration file exists, loading...")

        local xmlData = RmAafXmlOperations:loadFromXML(xmlFilePath)
        if xmlData then
            local gameData = RmAafGameDataReader:readGameData()
            -- Preserve all XML-only items at startup (for custom additions in Part 2)
            local merged = RmAafDataMerger:mergeData(xmlData, gameData, true)

            -- Store config for network sync
            RmAdjustAnimalFood.configData = merged

            -- Save merged result
            -- RmAafXmlOperations:saveToXML(merged, xmlFilePath)

            -- Apply to game
            RmAafGameApplicator:applyToGame(merged)

            -- Set up consumption multiplier from config
            if merged.consumptionMultiplier then
                local cm = merged.consumptionMultiplier
                RmAdjustAnimalFood.consumptionMultiplierEnabled = not cm.disabled
                RmAdjustAnimalFood.consumptionMultiplier = cm.multiplier or 1.0
            end
        end
    else
        RmLogging.logDebug("No configuration file found, creating default")

        local gameData = RmAafGameDataReader:readGameData()

        -- Add default consumption multiplier config (disabled by default)
        gameData.consumptionMultiplier = {
            multiplier = 1.0,
            disabled = true
        }

        -- Store config for network sync
        RmAdjustAnimalFood.configData = gameData

        -- RmAafXmlOperations:saveToXML(gameData, xmlFilePath)
    end

    -- Apply consumption multiplier hook if enabled (server only)
    applyConsumptionMultiplierHook()

    -- Broadcast config sync to all connected clients (edge case: early joiners)
    -- Most clients join after this, handled by FSBaseMission.sendInitialClientState
    if g_server ~= nil and RmAdjustAnimalFood.configData ~= nil then
        g_server:broadcastEvent(RmAnimalFoodSyncEvent.new(
            RmAdjustAnimalFood.configData.animals,
            RmAdjustAnimalFood.configData.mixtures,
            RmAdjustAnimalFood.configData.recipes
        ))
        RmLogging.logInfo("Config sync broadcasted to all clients")
    end

    RmLogging.logInfo("RmAdjustAnimalFood initialization complete")
end

---Saves current game configuration to XML
function RmAdjustAnimalFood.saveToFile()
    RmLogging.logInfo("Saving animal food configuration...")

    if not g_currentMission or not g_currentMission.missionInfo then
        RmLogging.logWarning("Mission information not available, skipping save")
        return
    end

    local savegameDir = g_currentMission.missionInfo.savegameDirectory
    if not savegameDir then
        RmLogging.logWarning("Savegame directory not available, skipping save")
        return
    end

    local xmlFilePath = savegameDir .. "/" .. RmAdjustAnimalFood.XML_FILENAME
    local gameData = RmAafGameDataReader:readGameData()

    local dataToSave
    if RmAdjustAnimalFood.configData then
        -- Normal case: merge with stored config, preserving only disabled items (not game-removed)
        dataToSave = RmAafDataMerger:mergeData(RmAdjustAnimalFood.configData, gameData, false)
    else
        -- First save before configData was initialized (new game, savegame folder didn't exist during loadAndApply)
        RmLogging.logInfo("No config data available, saving current game data")
        dataToSave = gameData
        RmAdjustAnimalFood.configData = gameData
    end

    RmAafXmlOperations:saveToXML(dataToSave, xmlFilePath)
end

---Called when map finishes loading
---This is the entry point for the mod
local function onLoadMapFinished()
    RmLogging.logInfo("Map loading finished, initializing RmAdjustAnimalFood")

    -- Hook into savegame save
    FSBaseMission.saveSavegame = Utils.appendedFunction(
        FSBaseMission.saveSavegame,
        RmAdjustAnimalFood.saveToFile
    )

    -- Load and apply configuration
    RmAdjustAnimalFood.loadAndApply()
end

-- Hook into map loading completion
BaseMission.loadMapFinished = Utils.appendedFunction(
    BaseMission.loadMapFinished,
    onLoadMapFinished
)

-- ============================================================================
-- INITIALIZATION: Late-join client synchronization
-- ============================================================================

---Sends initial state to newly connected clients
---Called by FSBaseMission when a client finishes connecting to the server.
---This ensures clients that join after server initialization receive the configuration.
---@param connection table Connection object for the connecting client
---@param user table User information (may be nil)
---@param farm table Farm information (may be nil)
function RmAdjustAnimalFood:sendInitialClientState(connection, user, farm)
    if g_server ~= nil and connection ~= nil and RmAdjustAnimalFood.configData ~= nil then
        connection:sendEvent(RmAnimalFoodSyncEvent.new(
            RmAdjustAnimalFood.configData.animals,
            RmAdjustAnimalFood.configData.mixtures,
            RmAdjustAnimalFood.configData.recipes
        ))
        RmLogging.logInfo("Sent config sync to newly connected client")
    end
end

-- Hook into client connection to send initial state
FSBaseMission.sendInitialClientState = Utils.appendedFunction(
    FSBaseMission.sendInitialClientState,
    RmAdjustAnimalFood.sendInitialClientState
)

RmLogging.logInfo("RmAdjustAnimalFood mod initialized")
