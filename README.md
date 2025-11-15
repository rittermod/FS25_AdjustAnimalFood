# FS25_AdjustAnimalFood

Adjust Animal Food allows you to customize the animal feeding system in Farming Simulator 2025 through an XML configuration file. Why shouldn't chickens eat oats if you want them to? Or make grass more effective for cows? This mod gives you control over food effectiveness, crop assignments, mixed feed recipes, and TMR compositions.

Supports multiplayer.

## Notes

**This mod requires XML editing.** There is no in-game UI. Configuration is done by editing an XML file that's automatically generated in your savegame folder. If you're not comfortable editing XML files, this mod may not be for you.

**Beta Software:** Please back up your savegames before use. The mod is fully functional but still in beta testing.

**At the moment, you cannot add/remove food groups, change name of food groups etc. Only change the weights and what fillTypes are in the groups.**

Documentation, source code and issue tracker at https://github.com/rittermod/FS25_AdjustAnimalFood

## Features

- **Animal Food Control**: Modify food group effectiveness (productionWeight) and consumption preferences (eatWeight) for all animal types
- **Custom Crop Assignments**: Add or remove crops from any food group (e.g., add oat to chicken feed, allow cows to eat alfalfa silage)
- **Mixed Feed Customization**: Adjust ingredient proportions and crop types for mixed feeds like pig food
- **Recipe Control**: Customize recipes with precise min/max percentage ranges for each ingredient
- **Schema-Validated Configuration**: Uses the game's built-in AnimalFoodSystem schema for robust, error-checked XML handling
- **Intelligent Merging**: Your XML overrides customizations while automatically adding new content from mods or game updates
- **Per-Savegame Configuration**: Each savegame gets its own XML file for independent customization
- **Automatic Updates**: Configuration file is automatically updated with any new content on each load


## Installation

1. Download the latest release zip file
2. Move or copy the zip file into your Farming Simulator 2025 mods folder, typically located at:
   - Windows: `Documents/My Games/FarmingSimulator2025/mods`
   - macOS: `~/Library/Application Support/FarmingSimulator2025/mods`
3. Make sure you don't have any older versions of the mod installed in the mods folder

## Usage

The mod works through XML configuration files that are automatically created for each savegame:

### First Time Setup

1. **Start your game** with the mod installed and load your savegame
2. **Exit the game** - the mod will create `aaf_AnimalFood.xml` in your savegame folder
3. **Locate the XML file** in your savegame directory:
   - Windows: `Documents/My Games/FarmingSimulator2025/savegameX/aaf_AnimalFood.xml`
   - macOS: `~/Library/Application Support/FarmingSimulator2025/savegameX/aaf_AnimalFood.xml`
4. **Edit the XML** with any text editor to customize your animal food system
5. **Load your savegame** - changes take effect immediately

### Making Changes

- The XML file contains all current game defaults when first created
- Edit any values you want to change (see Configuration Reference below)
- Values you don't change remain at game defaults
- Changes are applied every time you load the savegame
- The file is automatically updated if new content is added (mods, game updates)

### Important Notes

- **Language-Specific**: The generated XML uses your game's language (e.g., "Hay" in English, "Heu" in German)
- **Backup First**: Always back up your XML before making major changes
- **Order Matters**: For mixtures and recipes, ingredient order must match the game's order
- **Invalid Values**: Unknown crop names or invalid values will be logged but won't crash the game

## Configuration Reference

The XML file has three main sections: animals, mixtures, and recipes.

### Animals Section

Controls food group effectiveness and crop assignments for each animal type.

```xml
<animal animalType="COW" consumptionType="SERIAL">
    <foodGroup
        title="Hay"
        productionWeight="0.80"
        eatWeight="1.00"
        fillTypes="DRYGRASS_WINDROW"/>
</animal>
```

**What You Can Change:**
- `productionWeight`: Food effectiveness (0.0-1.0) - higher means better productivity
- `eatWeight`: Consumption preference (0.0-1.0) - affects PARALLEL consumption animals only
- `fillTypes`: Space-separated crop names that belong to this food group. Most animal pens will only accept bulk or bale fillTypes and not pallets. (If you want your animals to eat cake the pen must have a pallet trigger. Not tested.)

**What You Cannot Change:**
- `animalType`: Used for matching only - can't add new animal types
- `consumptionType`: Game-defined, modification has no effect
- `title`: Used for matching only - must match game's food group name

### Mixtures Section

Controls mixed feed recipes and ingredient proportions.

```xml
<mixture fillType="PIGFOOD" animalType="PIG">
    <ingredient weight="0.50" fillTypes="MAIZE TRITICALE"/>
    <ingredient weight="0.25" fillTypes="WHEAT BARLEY"/>
    <ingredient weight="0.20" fillTypes="SOYBEAN CANOLA"/>
    <ingredient weight="0.05" fillTypes="POTATO SUGARBEET_CUT"/>
</mixture>
```

**What You Can Change:**
- `weight`: Ingredient proportion (any positive number - automatically normalized to 1.0)
- `fillTypes`: Space-separated crop names for this ingredient slot

**Notes:**
- Weights are automatically normalized (if you use 50, 25, 20, 5 they become 0.5, 0.25, 0.2, 0.05)
- Ingredient order must match the game's order (usually matches the order in the XML)

### Recipes Section

Controls TMR/Forage recipes for mixing wagons.

```xml
<recipe fillType="FORAGE">
    <ingredient
        name="silage"
        title="Silage"
        minPercentage="0"
        maxPercentage="75"
        fillTypes="SILAGE ALFALFA_FERMENTED"/>
    <ingredient
        name="straw"
        title="Straw"
        minPercentage="10"
        maxPercentage="30"
        fillTypes="STRAW"/>
</recipe>
```

**What You Can Change:**
- `minPercentage`: Minimum percentage (0-100) for this ingredient
- `maxPercentage`: Maximum percentage (0-100) for this ingredient
- `fillTypes`: Space-separated crop names for this ingredient

**What You Cannot Change:**
- `name`: Internal identifier - must match game
- `title`: Display name - modification has no effect

**Notes:**
- Percentages define the valid range for the mixing wagon UI
- Ratios are automatically normalized based on your min/max ranges

## Practical Examples

### Make Hay More Effective for Cows

Find the hay food group for cows and increase productionWeight:

```xml
<foodGroup title="Hay" productionWeight="1.0" eatWeight="1.00" fillTypes="DRYGRASS_WINDROW"/>
```

Now hay provides 100% food effectiveness.

### Add Oat to Chicken Feed

Find the grain food group for chickens and add OAT to fillTypes:

```xml
<foodGroup title="Grain" productionWeight="1.00" eatWeight="1.00" fillTypes="WHEAT BARLEY SORGHUM OAT"/>
```

Chickens can now eat oat along with other grains. 

### Adjust Pig Feed Recipe

Modify the PIGFOOD mixture to use more grain:

```xml
<mixture fillType="PIGFOOD" animalType="PIG">
    <ingredient weight="0.60" fillTypes="MAIZE TRITICALE"/>  <!-- More grain -->
    <ingredient weight="0.30" fillTypes="SOYBEAN CANOLA"/>   <!-- More protein -->
    <ingredient weight="0.10" fillTypes="POTATO"/>           <!-- Less roots -->
</mixture>
```

The weights will be automatically normalized to 100%.

### Allow More Silage in TMR

Adjust the FORAGE recipe to allow up to 80% silage:

```xml
<ingredient name="silage" title="Silage" minPercentage="0" maxPercentage="80" fillTypes="SILAGE"/>
```

Your TMR mixer will now accept up to 80% silage instead of the default 75%.

### Add Alfalfa Silage as Alternative

If there are custom filltypes from maps and mods they can be added. 
ALFALFA_FERMENTED to the silage ingredient if the map has alfalfa silage:

```xml
<ingredient name="silage" title="Silage" minPercentage="0" maxPercentage="75" fillTypes="SILAGE ALFALFA_FERMENTED"/>
```

You can now use either grass silage or alfalfa silage in your TMR.

## How It Works

The mod integrates with Farming Simulator's animal food system through several mechanisms:

- **Schema Validation**: Uses `AnimalFoodSystem.xmlSchema` to load and validate XML configuration files with the game's built-in schema
- **Lifecycle Hooks**: Hooks into `BaseMission.loadMapFinished` to initialize after the game loads map data
- **Auto-Save Integration**: Hooks into `FSBaseMission.saveSavegame` to update the XML file when you save your game
- **Merging**: When loading, the mod:
  1. Reads the game's current animal food system defaults
  2. Loads your XML customizations
  3. Merges them (XML values override, but new game content is added)
  4. Applies the merged configuration to the game
  5. Saves the merged result back to XML for next time
- **Direct System Modification**: Updates `g_currentMission.animalFoodSystem` data structures that the game reads for animal behavior
- **Automatic Normalization**: Mixture weights and recipe ratios are automatically normalized to prevent invalid configurations


## Troubleshooting

### Changes Don't Take Effect

- Make sure you saved the XML file after editing
- Verify the XML file is in the correct savegame folder
- Check the game log for warnings about unknown fillTypes or invalid values

### Game Log Shows Warnings

- `Unknown fillType 'XXX'`: You used a crop name that doesn't exist - check spelling or remove it
- `Failed to load XML`: XML syntax error - check for missing quotes, unclosed tags, or special characters
- `AnimalFoodSystem not available`: The mod loaded too early - this is usually harmless and will self-correct

### Want to Reset to Defaults

1. Delete the `aaf_AnimalFood.xml` file from your savegame folder
2. Load your savegame
3. A fresh XML with current game defaults will be created

### Multiple Mods Conflict

The merging system should handle most conflicts automatically. If you have issues:
- The last-loaded mod's XML values will take precedence
- Check if other mods modify the same animal food values
- Try loading this mod last (rename to start with "zzz" if needed)

