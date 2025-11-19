# FS25_AdjustAnimalFood

Adjust Animal Food allows you to customize the animal feeding system in Farming Simulator 2025 through an XML configuration file. Why shouldn't chickens eat oats if you want them to? Or make grass more effective for cows? This mod gives you control over food effectiveness, crop assignments, mixed feed recipes, and TMR compositions.

Supports multiplayer.

## Notes

**This mod requires XML editing.** There is no in-game UI. Configuration is done by editing an XML file that's automatically generated in your savegame folder. If you're not comfortable editing XML files, this mod may not be for you.

**Beta Software:** Please back up your savegames before use. The mod is fully functional but still in beta testing.

As of version 0.11.0.0
You can:
- Add custom food groups to animals and custom ingredients to mixtures/recipes
- Disable unwanted food groups or ingredients
- Adjust food effectiveness and feeding behavior (productionWeight, eatWeight, consumptionType)
- Change which crops belong to each food group (fillTypes)
- Modify mixed feed recipes and ingredient proportions
- Customize TMR/forage recipe compositions and ranges

You **cannot**:
- Cannot delete or add new animal types (only modify existing animals like COW, PIG, CHICKEN, SHEEP, HORSE)
- Cannot delete or add new mixtures/recipes (only modify existing ones like PIGFOOD, FORAGE)
- Cannot change internal names or titles (these are used for matching only)


Documentation, source code and issue tracker at https://github.com/rittermod/FS25_AdjustAnimalFood

## Features

- **Animal Food Control**: Modify food group effectiveness (productionWeight) and consumption preferences (eatWeight) for all animal types
- **Add Custom Content**: Add custom food groups to animals, extra ingredients to mixtures, and additional ingredients to TMR recipes
- **Disable Food Groups & Ingredients**: Remove unwanted food groups, mixture ingredients, or recipe ingredients from the game
- **Custom Crop Assignments**: Add or remove crops from any food group (e.g., add oat to chicken feed, allow cows to eat alfalfa silage)
- **Mixed Feed Customization**: Adjust ingredient proportions and crop types for mixed feeds like pig food
- **Recipe Control**: Customize recipes with precise min/max percentage ranges for each ingredient
- **Automatic Normalization**: Remaining ingredients automatically adjust when you disable or modify items
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
2. **Save and exit the game** - the mod will create `aaf_AnimalFood.xml` in your savegame folder
3. **Locate the XML file** in your savegame directory:
   - Windows: `Documents/My Games/FarmingSimulator2025/savegameX/aaf_AnimalFood.xml`
   - macOS: `~/Library/Application Support/FarmingSimulator2025/savegameX/aaf_AnimalFood.xml`
4. **Edit the XML** with any text editor to customize your animal food system
5. **Load your savegame** - changes take effect immediately

### Making Changes

- The XML file contains all current game defaults when first created
- **The file includes documentation and examples** showing how to use features like disabling items
- Edit any values you want to change (see Configuration Reference below)
- Values you don't change remain at game defaults
- Changes are applied every time you load the savegame
- The file is automatically updated if new content is added (mods, game updates)

### Important Notes

- **5-Entry Limit**: Keep total **active** (non-disabled) food groups/ingredients to **5 or fewer** per animal/mixture/recipe. The game may not display or handle more than 5 correctly. If you want to add custom entries, consider disabling existing ones first.
- **CRITICAL - Never Disable Grass**: Do NOT disable the Grass food group for any animal. The game's Meadow system has an internal dependency on Grass configuration and disabling it will cause the game to hang. Other food groups may have similar hidden dependencies - disable with caution.
- **Language-Specific**: The generated XML uses your game's language (e.g., "Hay" in English, "Heu" in German)
- **Backup First**: Always back up your XML before making major changes
- **Order Matters**: Keep the order of food groups and ingredients in the order they should appear in the UI display
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
- `consumptionType`: Set to `"SERIAL"` (eat one food at a time) or `"PARALLEL"` (eat all foods simultaneously) - changes how animals consume multiple food types
- `disabled`: Set to `"true"` to remove this food group from the game (animals won't accept this food type)

**What You Cannot Change:**
- `animalType`: Used for matching only - can't add new animal types
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
- `disabled` (on ingredient): Set to `"true"` to remove this ingredient from the mixture

**Notes:**
- Weights are automatically normalized (if you use 50, 25, 20, 5 they become 0.5, 0.25, 0.2, 0.05)
- When you disable an ingredient, remaining ingredients are automatically renormalized
- Ingredient order must match the game's order (usually matches the order in the XML)
- You cannot disable entire mixtures, only individual ingredients

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
- `disabled` (on ingredient): Set to `"true"` to remove this ingredient from the recipe

**What You Cannot Change:**
- `name`: Internal identifier - must match game
- `title`: Display name - modification has no effect

**Notes:**
- Percentages define the valid range for the mixing wagon UI
- Ratios are automatically normalized based on your min/max ranges
- When you disable an ingredient, it's completely removed from the TMR mixer UI
- You cannot disable entire recipes, only individual ingredients

## Practical Examples

### Simple: Adjust Food Effectiveness (Weights)

The most common use case is adjusting how effective different foods are. Values range from 0.0 to 1.0.

**Make hay more effective for cows (increase from 0.8 to 1.0):**
```xml
<foodGroup title="Hay" productionWeight="1.0" eatWeight="1.00" fillTypes="DRYGRASS_WINDROW"/>
```

**Make straw less effective (decrease from 0.2 to 0.1):**
```xml
<foodGroup title="Straw" productionWeight="0.1" eatWeight="1.00" fillTypes="STRAW"/>
```

Values between 0.0 and 1.0 where higher = more effective for animal productivity.

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

### Disable Hay for Cows

Don't want cows to eat hay? Add `disabled="true"` to the hay food group:

```xml
<foodGroup title="Hay" productionWeight="0.80" eatWeight="1.00" fillTypes="DRYGRASS_WINDROW" disabled="true"/>
```

Cows will no longer accept hay. The food group is completely removed from the game but stays in your XML file.

### Remove Grain from Pig Feed

Want to exclude wheat and barley from your pig feed mix? Disable the grain ingredient:

```xml
<mixture fillType="PIGFOOD" animalType="PIG">
    <ingredient weight="0.50" fillTypes="MAIZE TRITICALE"/>
    <ingredient weight="0.25" fillTypes="WHEAT BARLEY" disabled="true"/>  <!-- Grain excluded -->
    <ingredient weight="0.20" fillTypes="SOYBEAN CANOLA"/>
    <ingredient weight="0.05" fillTypes="POTATO SUGARBEET_CUT"/>
</mixture>
```

The remaining ingredients automatically adjust: Base 66.6%, Protein 26.6%, Roots 6.6%.

### Exclude Straw from TMR Recipe

Don't want straw in your TMR? Disable the straw ingredient:

```xml
<recipe fillType="FORAGE">
    <ingredient name="silage" title="Silage" minPercentage="0" maxPercentage="75" fillTypes="SILAGE"/>
    <ingredient name="straw" title="Straw" minPercentage="10" maxPercentage="30" fillTypes="STRAW" disabled="true"/>
    <ingredient name="dryGrass" title="Hay" minPercentage="20" maxPercentage="50" fillTypes="DRYGRASS_WINDROW"/>
    <ingredient name="mineralFeed" title="Mineral Feed" minPercentage="0" maxPercentage="10" fillTypes="MINERAL_FEED"/>
</recipe>
```

Your TMR mixer will only show 3 ingredient slots instead of 4.

### Change Cow Feeding from Sequential to Simultaneous

By default, cows eat foods one at a time in priority order (SERIAL mode). Change to PARALLEL mode to simulate a realistic mixed ration where cows consume multiple food types simultaneously:

```xml
<animal animalType="COW" consumptionType="PARALLEL">
    <foodGroup title="Hay" productionWeight="0.8" eatWeight="0.3" fillTypes="DRYGRASS_WINDROW"/>
    <foodGroup title="Silage" productionWeight="1.0" eatWeight="0.5" fillTypes="SILAGE"/>
    <foodGroup title="Grass" productionWeight="0.7" eatWeight="0.2" fillTypes="GRASS_WINDROW"/>
</animal>
```

In PARALLEL mode, `eatWeight` controls consumption proportions (50% silage, 30% hay, 20% grass based on the weights above). In the default SERIAL mode, cows would eat one food type completely before moving to the next.

### Change Pig Feeding from Simultaneous to Sequential

By default, pigs eat all foods simultaneously (PARALLEL mode). Change to SERIAL mode to force pigs to eat one food type at a time in priority order:

```xml
<animal animalType="PIG" consumptionType="SERIAL">
    <foodGroup title="Mixed Feed" productionWeight="1.0" eatWeight="1.0" fillTypes="PIGFOOD"/>
    <foodGroup title="Grain" productionWeight="0.8" eatWeight="1.0" fillTypes="WHEAT BARLEY"/>
    <foodGroup title="Roots" productionWeight="0.6" eatWeight="1.0" fillTypes="POTATO SUGARBEET"/>
</animal>
```

In SERIAL mode, pigs eat Mixed Feed first, then Grain when depleted, then Roots. The `eatWeight` values are ignored in SERIAL mode - only `productionWeight` affects productivity.

### Advanced: Add Custom Food Type (Staying Within 5-Entry Limit)

Want to add a custom food group? Remember the 5-entry limit! COW has 4 vanilla food groups, so you can safely add 1 custom food OR disable one vanilla and add a custom replacement.

**Option 1: Add custom when under 5 (COW has 4, adding 1 = 5 total):**
```xml
<animal animalType="COW" consumptionType="SERIAL">
    <!-- 4 existing vanilla food groups -->
    <foodGroup title="Total Mixed Ration" productionWeight="1.0" eatWeight="1.0" fillTypes="FORAGE"/>
    <foodGroup title="Hay" productionWeight="0.8" eatWeight="1.0" fillTypes="DRYGRASS_WINDROW"/>
    <foodGroup title="Silage" productionWeight="0.8" eatWeight="1.0" fillTypes="SILAGE"/>
    <foodGroup title="Grass" productionWeight="0.4" eatWeight="1.0" fillTypes="GRASS_WINDROW"/>

    <!-- Add custom 5th food group -->
    <foodGroup title="Oat" productionWeight="1.0" eatWeight="1.0" fillTypes="OAT"/>
</animal>
```

**Option 2: Disable one + add custom (stay at 4 active):**
```xml
<animal animalType="COW" consumptionType="SERIAL">
    <foodGroup title="Total Mixed Ration" productionWeight="1.0" eatWeight="1.0" fillTypes="FORAGE"/>
    <foodGroup title="Hay" productionWeight="0.8" eatWeight="1.0" fillTypes="DRYGRASS_WINDROW"/>
    <foodGroup title="Silage" productionWeight="0.8" eatWeight="1.0" fillTypes="SILAGE"/>
    <foodGroup title="Grass" productionWeight="0.4" eatWeight="1.0" fillTypes="GRASS_WINDROW" disabled="true"/>  <!-- Disable -->
    <foodGroup title="Oat" productionWeight="1.0" eatWeight="1.0" fillTypes="OAT"/>  <!-- Add custom -->
</animal>
```

**⚠️ Don't do this (6 active entries will cause problems):**
```xml
<!-- BAD: 4 vanilla + 2 custom = 6 active entries -->
<foodGroup title="Oat" productionWeight="1.0" eatWeight="1.0" fillTypes="OAT"/>
<foodGroup title="Barley" productionWeight="1.0" eatWeight="1.0" fillTypes="BARLEY"/>
```

Same principle applies to mixtures and recipes - keep active entries ≤ 5.

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

