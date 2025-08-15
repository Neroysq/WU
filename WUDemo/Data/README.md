# Game Data Configuration

This directory contains all modular game parameters in JSON format, allowing easy gameplay tweaking without recompiling.

## Directory Structure

- `Characters/` - Player character data files
  - `Hu.json` - Tiger character parameters
  
- `Enemies/` - Enemy type data files
  - `BasicEnemy.json` - Common enemy parameters
  - `EliteEnemy.json` - Elite enemy parameters
  - `BossEnemy.json` - Boss enemy parameters
  
- `Settings/` - Global game settings
  - `GameSettings.json` - General game parameters

## Character Parameters

Character JSON files control:
- **Movement**: moveSpeed, jumpForce, gravity, dashSpeed, airDashSpeed
- **Combat Stats**: healthMax, postureMax, rageMax, postureRecoveryRate
- **Attack Properties**: attackDamage, attackPostureDamage, attackRange, timing
- **Cooldowns**: dashDuration, dashCooldown, parryWindow, stunDuration, comboWindow
- **Visual**: colorBody, colorAccent (hex format)
- **Dimensions**: halfWidth, height

## Enemy Parameters

Enemy JSON files control:
- **Basic Properties**: type, name, description
- **Movement**: moveSpeed, jumpForce, gravity
- **Combat Stats**: healthMax, postureMax, postureRecoveryRate
- **Attack Properties**: damage, posture damage, range, duration, telegraph
- **AI Behavior**: aggressionLevel, reactionTime, blockChance, dodgeChance
- **Visual**: colorBody, colorAccent
- **Dimensions**: halfWidth, height

## Game Settings

Global settings control:
- **Display**: viewWidth, viewHeight, targetFPS
- **World**: groundY, worldBounds
- **Combat**: postureRecoveryRate, parryWindow, stunDuration
- **Visual Effects**: cameraShakeDecay, timeScaleRecovery, maxParticles
- **Damage Numbers**: lifetime, speed, gravity

## Live Reloading

Press **F5** during gameplay to reload all data files without restarting the game.

## Color Format

Colors use hex format: `"#RRGGBB"`
Example: `"#6EB9FF"` for light blue

## Adding New Characters/Enemies

1. Create a new JSON file in the appropriate directory
2. Follow the existing format (copy an existing file as template)
3. Ensure the `name` (for characters) or `type` (for enemies) field is unique
4. Press F5 in-game to reload