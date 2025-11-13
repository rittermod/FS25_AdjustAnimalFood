# FS25 Mod Development Code Style Guide

This code style guide is based on analysis of established FS25 mods and provides best practices for creating maintainable, professional mod code.

## Lua Version Compatibility

**Important**: Farming Simulator 25 uses **Lua 5.1** (via LuaJIT) for all mod scripting. This has significant implications for language features and syntax.

### Lua 5.1 Limitations

The following modern Lua features are **NOT available** in FS25:

```lua
-- ❌ NOT Available in Lua 5.1
goto label          -- goto statements (Lua 5.2+)
::label::           -- labels (Lua 5.2+)
local x = 10 // 3   -- integer division operator (Lua 5.3+)
local x = 5 & 3     -- bitwise operators (Lua 5.3+)
utf8.len(str)       -- utf8 library (Lua 5.3+)
```

### Lua 5.1 Compatible Patterns

Use these patterns instead:

```lua
-- ✅ Lua 5.1 Compatible Loop Control
for i, item in ipairs(items) do
    if not item.valid then
        -- Skip invalid items - no goto needed
    else
        processItem(item)
    end
end

-- ✅ Integer Division Alternative
local result = math.floor(10 / 3)  -- Instead of 10 // 3

-- ✅ Bitwise Operations (if needed)
-- Use bit library or manual implementations
local bit = require("bit")  -- If available
local result = bit.band(5, 3)  -- Instead of 5 & 3
```

### Available Lua 5.1 Features

You can safely use these Lua 5.1 features:

- Standard library: `string.*`, `table.*`, `math.*`, `io.*`
- Pattern matching with `string.find()`, `string.match()`, `string.gsub()`
- Coroutines with `coroutine.*`
- Metatables and metamethods
- Closures and upvalues
- Variable arguments with `...`

## Project Structure

```
FS25_ModName/
├── modDesc.xml                 # Mod descriptor (required)
├── icon_modName.dds           # Mod icon (required)
├── README.md                  # Documentation
├── scripts/                   # Main Lua source files
│   ├── main.lua              # Entry point
│   ├── ModName.lua           # Core mod class
│   ├── Settings.lua          # Settings management
│   ├── events/               # Network events
│   │   ├── SettingsEvent.lua
│   │   └── SyncEvent.lua
│   ├── gui/                  # GUI components
│   │   ├── MenuFrame.lua
│   │   └── Dialog.lua
│   ├── specializations/      # Vehicle specializations
│   └── utils/               # Utility functions
├── gui/                      # XML GUI definitions
│   ├── MenuFrame.xml
│   └── guiProfiles.xml
├── translations/ or languages/ # Localization files
│   ├── translation_en.xml
│   └── translation_de.xml
├── images/                   # Additional textures
├── config/                   # Configuration files
└── addons/                   # Optional addon files
```

## Lua Code Style

### Naming Conventions

#### Variables and Functions
- **Local variables**: camelCase
- **Global variables**: PascalCase
- **Constants**: UPPER_SNAKE_CASE
- **Private members**: prefix with underscore `_privateVar`
- **Functions**: camelCase with verb-noun pattern

```lua
-- Good
local playerHealth = 100
local MAX_SPEED = 50
local _internalCounter = 0

function calculateDistance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

-- Bad
local PlayerHealth = 100
local max_speed = 50
function CalcDist(x1, y1, x2, y2)
```

#### Classes and Modules
- **Class names**: PascalCase with optional prefix
- **Module names**: PascalCase matching filename
- **Module constants**: Should be scoped within the module namespace

```lua
-- Good
ContractBoost = {}
RealisticLivestock_AnimalCluster = {}
CpUtil = {}

-- Class instantiation
local Settings_mt = Class(Settings)
function Settings.new()
    local self = setmetatable({}, Settings_mt)
    return self
end
```

#### Module Constants Scoping

For FS25 mod modules, scope constants within the module namespace to avoid global pollution:

```lua
-- ✅ Good: Module-scoped constants
AnimalNameOverride = {}

-- Constants accessible but properly namespaced
AnimalNameOverride.GENETICS_MIN = 0.25
AnimalNameOverride.GENETICS_MAX = 1.75
AnimalNameOverride.DEFAULT_CONFIG = { debug = false }

-- Usage within module functions
local function validateGenetics(value)
    return value >= AnimalNameOverride.GENETICS_MIN and 
           value <= AnimalNameOverride.GENETICS_MAX
end

-- External access possible
local minValue = AnimalNameOverride.GENETICS_MIN
```

```lua
-- ❌ Bad: Local constants (not accessible outside)
local GENETICS_MIN = 0.25  -- Hidden from external code
local GENETICS_MAX = 1.75  -- Cannot be configured/tested

AnimalNameOverride = {}

-- ❌ Worse: Global constants (namespace pollution)
GENETICS_MIN = 0.25  -- Pollutes global namespace
GENETICS_MAX = 1.75  -- Risk of naming conflicts

AnimalNameOverride = {}
```

**Benefits of module-scoped constants:**
- Clear ownership and source identification
- No global namespace pollution
- Easy to find and modify configuration values
- Supports external configuration and testing
- Follows established FS25 modding conventions
- Maintains encapsulation while allowing controlled access

### Code Organization

#### File Structure
Each Lua file should follow this structure:

```lua
-- Header comment with file purpose
-- Author: ModAuthor
-- Description: Brief description of file purpose

-- Module declaration
ModuleName = {}

-- Constants
ModuleName.CONSTANT_VALUE = 42

-- Local variables
local modDirectory = g_currentModDirectory

-- Private functions (local)
local function privateFunction()
    -- implementation
end

-- Public functions
function ModuleName:publicMethod()
    -- implementation
end

-- Event listeners and hooks
function ModuleName:onLoad()
    -- initialization
end

-- Module initialization
function ModuleName:init()
    -- setup code
end
```

#### Class Definition Pattern

```lua
-- Class declaration
Settings = {}
local Settings_mt = Class(Settings)

-- Constructor
function Settings.new()
    local self = setmetatable({}, Settings_mt)
    
    -- Initialize properties
    self.debugMode = false
    self.version = "1.0.0"
    
    -- Call initialization
    self:initialize()
    
    return self
end

-- Methods
function Settings:initialize()
    -- setup code
end

function Settings:getValue(key)
    return self[key]
end
```

### Function Style

#### Function Documentation
Use LDoc-style annotations for important functions:

```lua
---Creates a new settings instance with default values
---@param config table|nil optional configuration table
---@return Settings the new settings instance
function Settings.new(config)
    -- implementation
end

---Retrieves a setting value by name
---@param settingName string the name of the setting
---@param defaultValue any default value if setting not found
---@return any the setting value or default
function Settings:getSetting(settingName, defaultValue)
    return self[settingName] or defaultValue
end
```

#### Error Handling
Use defensive programming and proper error handling (Lua 5.1 compatible):

```lua
function ModName:loadFromXML(xmlFile, key)
    if xmlFile == nil then
        CpUtil.error("Invalid XML file provided")
        return false
    end
    
    -- Lua 5.1 compatible pcall usage
    local success, result = pcall(function()
        -- XML loading code
        return xmlFile:getString(key .. "#value")
    end)
    
    if not success then
        CpUtil.error("Failed to load from XML: %s", result)
        return false
    end
    
    return true
end

-- ✅ Lua 5.1 Safe Global Access Pattern
local function safeGlobalAccess(globalName)
    local obj = _G[globalName]
    if not obj then
        logWarning("Global '" .. globalName .. "' not available")
        return nil
    end
    return obj
end

-- Usage:
local realisticLivestock = safeGlobalAccess("FS25_RealisticLivestock")
if realisticLivestock and realisticLivestock.Animal then
    -- Safe to use
end
```

### Formatting Guidelines

#### Indentation and Spacing
- Use 4 spaces for indentation (no tabs)
- Add blank lines to separate logical sections
- Use spaces around operators

```lua
-- Good (Lua 5.1 Compatible)
function calculateTotal(items)
    local total = 0
    
    for _, item in pairs(items) do
        if item.active then
            total = total + item.value
        end
    end
    
    return total
end

-- Bad
function calculateTotal(items)
local total=0
for _,item in pairs(items) do
if item.active then
total=total+item.value
end
end
return total
end
```

#### Lua 5.1 Specific Considerations

```lua
-- ✅ Good: Early exit pattern (Lua 5.1 compatible)
function processController(controllerName)
    local controller = _G[controllerName]
    if not controller then
        logWarning("Controller not found: " .. controllerName)
        return false
    end
    
    -- Process controller logic here
    return true
end

-- ❌ Bad: goto pattern (not available in Lua 5.1)
function processControllers(controllers)
    for _, name in ipairs(controllers) do
        local controller = _G[name]
        if not controller then
            goto continue  -- This will cause errors!
        end
        -- process...
        ::continue::
    end
end
```

#### Line Length
- Prefer lines under 120 characters
- Break long function calls across multiple lines

```lua
-- Good
g_client:getServerConnection():sendEvent(
    SettingsChangeEvent.new(settingName, newValue, farmId)
)

-- Acceptable for readability
local result = someVeryLongFunctionName(parameter1, parameter2, parameter3)
```

## File Organization Patterns

### Main Entry Point
The main entry file should handle mod initialization:

```lua
-- scripts/ContractBoost.lua
ContractBoost = {}
ContractBoost.modDirectory = g_currentModDirectory
local MOD_NAME = g_currentModName

function ContractBoost:init()
    -- Load settings
    self.settings = Settings.new()
    
    -- Setup event listeners
    self:initializeListeners()
    
    CpUtil.info("%s loaded successfully", MOD_NAME)
end

-- Initialize when map loads
function ContractBoost:loadMap()
    self:init()
end

addModEventListener(ContractBoost)
```

### Settings Management
Use a dedicated settings class for configuration:

```lua
-- scripts/Settings.lua
Settings = {}
local Settings_mt = Class(Settings)

function Settings.new()
    local self = setmetatable({}, Settings_mt)
    
    -- Default values
    self.debugMode = false
    self.rewardMultiplier = 1.5
    
    return self
end

function Settings:loadFromXML(xmlFile, key)
    if xmlFile == nil then return end
    
    self.debugMode = xmlFile:getBool(key .. "#debugMode", self.debugMode)
    self.rewardMultiplier = xmlFile:getFloat(key .. "#rewardMultiplier", self.rewardMultiplier)
end

function Settings:saveToXML(xmlFile, key)
    xmlFile:setBool(key .. "#debugMode", self.debugMode)
    xmlFile:setFloat(key .. "#rewardMultiplier", self.rewardMultiplier)
end
```

### Event System
Network events should follow this pattern:

```lua
-- scripts/events/SettingsChangeEvent.lua
SettingsChangeEvent = {}
local SettingsChangeEvent_mt = Class(SettingsChangeEvent, Event)

InitEventClass(SettingsChangeEvent, "SettingsChangeEvent")

function SettingsChangeEvent.new(settingName, value)
    local self = Event.new(SettingsChangeEvent_mt)
    self.settingName = settingName
    self.value = value
    return self
end

function SettingsChangeEvent:readStream(streamId, connection)
    self.settingName = streamReadString(streamId)
    self.value = streamReadFloat32(streamId)
    self:run(connection)
end

function SettingsChangeEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.settingName)
    streamWriteFloat32(streamId, self.value)
end

function SettingsChangeEvent:run(connection)
    if g_currentMission.contractBoostSettings then
        g_currentMission.contractBoostSettings[self.settingName] = self.value
    end
end
```

## GUI Integration

### In-Game Menu Integration
Use established patterns for adding menu pages:

```lua
function ModName:setupGui()
    -- Load GUI profiles
    g_gui:loadProfiles(Utils.getFilename("gui/guiProfiles.xml", self.modDirectory))
    
    -- Create menu frame
    local menuFrame = MenuFrame.new()
    g_gui:loadGui(self.modDirectory .. "gui/MenuFrame.xml", "menuFrame", menuFrame)
    
    -- Add to in-game menu
    self:addIngameMenuPage(menuFrame, "menuFrame", {0, 0, 1024, 1024}, 
        function() return true end, "pageSettings")
end

function ModName:addIngameMenuPage(frame, pageName, uvs, predicateFunc, insertAfter)
    -- Standard menu integration code
    local targetPosition = 0
    
    for i = 1, #g_inGameMenu.pagingElement.elements do
        local child = g_inGameMenu.pagingElement.elements[i]
        if child == g_inGameMenu[insertAfter] then
            targetPosition = i + 1
            break
        end
    end
    
    -- Add page logic
    g_inGameMenu[pageName] = frame
    g_inGameMenu.pagingElement:addElement(frame)
    
    -- Additional setup...
end
```

## Multiplayer Considerations

### Server-Client Synchronization
Always handle multiplayer properly:

```lua
function Settings:publishNewSettings()
    if g_server ~= nil then
        -- Server broadcasts to clients
        g_server:broadcastEvent(SettingsChangeEvent.new())
    else
        -- Client requests server to broadcast
        g_client:getServerConnection():sendEvent(SettingsChangeEvent.new())
    end
end

function Settings:onReadStream(streamId, connection)
    -- Receive settings from server
    self.debugMode = streamReadBool(streamId)
    self.rewardMultiplier = streamReadFloat32(streamId)
    
    -- Apply settings
    self:syncSettings()
end

function Settings:onWriteStream(streamId, connection)
    -- Send settings to client
    streamWriteBool(streamId, self.debugMode)
    streamWriteFloat32(streamId, self.rewardMultiplier)
end
```

### Function Overriding
Use Giants' utility functions for safe overriding:

```lua
-- Append to existing function
MissionManager.loadMapData = Utils.appendedFunction(
    MissionManager.loadMapData, 
    ContractBoost.syncSettings
)

-- Overwrite function completely
MissionManager.getIsMissionWorkAllowed = Utils.overwrittenFunction(
    MissionManager.getIsMissionWorkAllowed, 
    MissionTools.getIsMissionWorkAllowed
)

-- Prepend to existing function
BaseMission.loadMapFinished = Utils.prependedFunction(
    BaseMission.loadMapFinished, 
    ContractBoost.init
)
```

## modDesc.xml Structure

### Essential Elements
```xml
<?xml version="1.0" encoding="utf-8" standalone="no"?>
<modDesc descVersion="97">
    <author>YourName</author>
    <version>1.0.0.0</version>
    <title>
        <en>Your Mod Name</en>
        <de>Dein Mod Name</de>
    </title>
    <description>
        <en><![CDATA[
Your mod description here.

Features:
- Feature 1
- Feature 2

Changelog:
1.0.0.0:
- Initial release
        ]]></en>
    </description>
    
    <iconFilename>icon_yourMod.dds</iconFilename>
    <multiplayer supported="true"/>
    
    <extraSourceFiles>
        <sourceFile filename="scripts/YourMod.lua"/>
        <sourceFile filename="scripts/Settings.lua"/>
        <sourceFile filename="scripts/events/SettingsEvent.lua"/>
    </extraSourceFiles>
    
    <l10n filenamePrefix="translations/translation"/>
</modDesc>
```

## Internationalization

### Translation Files
Structure translation files consistently:

```xml
<!-- translations/translation_en.xml -->
<?xml version="1.0" encoding="utf-8" standalone="no"?>
<l10n>
    <translationContributors>YourName</translationContributors>
    
    <texts>
        <text name="yourMod_setting_debugMode" text="Debug Mode"/>
        <text name="yourMod_setting_rewardMultiplier" text="Reward Multiplier"/>
        <text name="yourMod_ui_title" text="Your Mod Settings"/>
        <text name="yourMod_message_enabled" text="Your Mod enabled"/>
    </texts>
</l10n>
```

### Using Translations in Code
```lua
-- Get translated text
local title = g_i18n:getText("yourMod_ui_title")

-- Format with parameters
local message = string.format(
    g_i18n:getText("yourMod_message_value"), 
    settingValue
)
```

## Console Commands

### Adding Debug Commands
```lua
function ContractBoost:initializeListeners()
    -- Add console commands for debugging
    addConsoleCommand("cbDebugToggle", 
        "Toggles debug mode", 
        "consoleCommandToggleDebug", 
        self)
    
    addConsoleCommand("cbReload", 
        "Reloads configuration", 
        "consoleCommandReload", 
        self)
end

function ContractBoost:consoleCommandToggleDebug()
    self.settings.debugMode = not self.settings.debugMode
    return string.format("Debug mode: %s", 
        self.settings.debugMode and "ON" or "OFF")
end
```

## Error Handling and Logging

### Logging Pattern
```lua
-- Define logging utility
local function log(level, message, ...)
    local prefix = string.format("[%s] %s:", MOD_NAME, level)
    Logging.info(prefix .. " " .. string.format(message, ...))
end

function ModName:logInfo(message, ...)
    log("INFO", message, ...)
end

function ModName:logError(message, ...)
    log("ERROR", message, ...)
    printCallstack()
end

function ModName:logDebug(message, ...)
    if self.settings and self.settings.debugMode then
        log("DEBUG", message, ...)
    end
end
```

## Performance Considerations

### Efficient Update Loops (Lua 5.1 Optimized)
```lua
function ModName:update(dt)
    -- Only update when necessary
    if not self.enabled then return end
    
    -- Use timers for expensive operations
    self.updateTimer = self.updateTimer - dt
    if self.updateTimer <= 0 then
        self:performExpensiveUpdate()
        self.updateTimer = self.UPDATE_INTERVAL
    end
end
```

### Lua 5.1 Performance Tips

```lua
-- ✅ Cache frequently accessed globals (Lua 5.1 optimization)
local pairs = pairs
local ipairs = ipairs
local table_insert = table.insert
local string_format = string.format

function MyClass:processItems(items)
    -- Using cached functions is faster in Lua 5.1
    for i, item in ipairs(items) do  -- cached ipairs
        if item.valid then
            table_insert(self.validItems, item)  -- cached table.insert
        end
    end
end

-- ✅ Avoid string concatenation in loops (Lua 5.1)
function buildMessage(parts)
    -- Good: table concat is more efficient
    local buffer = {}
    for i, part in ipairs(parts) do
        buffer[i] = tostring(part)
    end
    return table.concat(buffer, " ")
    
    -- Bad: repeated concatenation creates many temporary strings
    -- local result = ""
    -- for _, part in ipairs(parts) do
    --     result = result .. " " .. tostring(part)
    -- end
end
```

### Memory Management
```lua
function ModName:delete()
    -- Clean up event listeners
    if self.eventListeners then
        for _, listener in pairs(self.eventListeners) do
            g_messageCenter:unsubscribe(listener.messageType, listener.callback)
        end
        self.eventListeners = nil
    end
    
    -- Clean up GUI elements
    if self.menuFrame then
        self.menuFrame:delete()
        self.menuFrame = nil
    end
end
```

## Testing and Debugging

### Debug Utilities (Lua 5.1 Compatible)
```lua
function ModName:dumpTable(table, maxDepth)
    if not self.settings.debugMode then return end
    
    maxDepth = maxDepth or 3
    DebugUtil.printTableRecursively(table, "  ", 0, maxDepth)
end

function ModName:validateSettings()
    local errors = {}
    
    if type(self.settings.rewardMultiplier) ~= "number" then
        table.insert(errors, "rewardMultiplier must be a number")
    end
    
    if #errors > 0 then
        self:logError("Settings validation failed: %s", 
            table.concat(errors, ", "))
        return false
    end
    
    return true
end

-- ✅ Lua 5.1 Compatible Type Checking
function validateLua51Types(value, expectedType, name)
    local actualType = type(value)
    if actualType ~= expectedType then
        error(string.format(
            "Expected %s for %s, got %s", 
            expectedType, name or "value", actualType
        ))
    end
end

-- ✅ Safe nil checking patterns
function safeAccess(obj, ...)
    local keys = {...}
    local current = obj
    
    for _, key in ipairs(keys) do
        if type(current) ~= "table" or current[key] == nil then
            return nil
        end
        current = current[key]
    end
    
    return current
end

-- Usage: safeAccess(animal, "genetics", "quality") instead of animal.genetics.quality
```

## Lua 5.1 Migration Notes

If you're coming from modern Lua versions, be aware of these key differences:

### String Operations
```lua
-- ✅ Lua 5.1: Use string.format for complex formatting
local message = string.format("Player %s has %d items", playerName, itemCount)

-- ❌ Modern Lua: String interpolation not available
-- local message = f"Player {playerName} has {itemCount} items"  -- Not in Lua 5.1
```

### Table Operations
```lua
-- ✅ Lua 5.1: Standard table functions
table.insert(list, item)
table.remove(list, index)
table.concat(list, separator)

-- ✅ Lua 5.1: Manual table.pack equivalent
local function pack(...)
    return {n = select("#", ...), ...}
end

-- ❌ Modern Lua: table.pack/unpack not available in standard Lua 5.1
-- local packed = table.pack(...)  -- Not available
```

### Numeric Operations
```lua
-- ✅ Lua 5.1: Use math functions
local result = math.floor(value)
local power = math.pow(base, exponent)  -- or base ^ exponent

-- ❌ Modern Lua: Integer division and bitwise ops not available
-- local result = 10 // 3      -- Not in Lua 5.1
-- local masked = val & 0xFF   -- Not in Lua 5.1
```

### Function Declarations
```lua
-- ✅ Lua 5.1: Standard function syntax
local function processData(data)
    -- implementation
end

-- ✅ Lua 5.1: Method definitions
function MyClass:method(param)
    -- implementation
end

-- ❌ Modern Lua: No goto/labels
-- goto cleanup  -- Not available in Lua 5.1
-- ::cleanup::   -- Not available in Lua 5.1
```

---

This code style guide reflects the patterns and best practices observed across multiple established FS25 mods, with specific attention to **Lua 5.1 compatibility**. Following these conventions will help create maintainable, professional mod code that integrates well with the FS25 ecosystem while avoiding common Lua version compatibility issues.
