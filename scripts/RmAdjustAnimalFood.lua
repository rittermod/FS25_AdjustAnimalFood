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
            RmAafXmlOperations:saveToXML(merged, xmlFilePath)

            -- Apply to game
            RmAafGameApplicator:applyToGame(merged)
        end
    else
        RmLogging.logDebug("No configuration file found, creating default")

        local gameData = RmAafGameDataReader:readGameData()

        -- Store config for network sync
        RmAdjustAnimalFood.configData = gameData

        RmAafXmlOperations:saveToXML(gameData, xmlFilePath)
    end

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
