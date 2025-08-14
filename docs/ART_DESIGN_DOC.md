# WU (武) - Art Design Document
*Version 1.0 - Ancient China Wuxia-themed 2D Action Roguelike*

## Core Visual Identity

### Diorama Presentation Style
WU will adopt the distinctive **3D diorama stage** presentation, where combat takes place on floating platform stages with painted backgrounds visible through a contextual Chinese-inspired frame. This creates a unique theatrical quality perfect for the dramatic duels of Wuxia fiction.

**Current Implementation:** Basic geometric combat on simple platforms
**Planned Evolution:** Full diorama presentation with atmospheric backgrounds

**Key Elements:**
- **Stage Platform**: Textured stone/wood platforms with visible depth and edges
- **Window Frame**: Chinese-inspired decorative elements that vary by battle context (traditional lattice, temple arches, natural formations, mystical portals)
- **Background Paintings**: Scenic Chinese landscapes visible through the frame
- **Theatrical Lighting**: Dramatic rim lighting emphasizing the stage-like nature

## Visual Style Guidelines

### 1. **Visual Progression Plan**
**Current State:** Simple geometric shapes and bright colors for rapid prototyping
**Target State:** Detailed pixel art with VINIK24 palette

**Pixel Art Specifications (Target):**
- **Resolution**: Mid-to-high resolution pixel art
- **Character Size**: ~32-48 pixels tall for standard human characters
- **Animation Framerate**: 12-15 FPS for smooth martial arts movements
- **Color Depth**: VINIK24 palette exclusively (24 colors maximum)

### 2. **Color Palette**

#### Primary Palette - "VINIK24"
Adopting the VINIK24 palette (https://lospec.com/palette-list/vinik24) for its soft, contemplative tones that enhance the Wuxia atmosphere and provide connected color ramps essential for pixel art consistency.

**Key Palette Applications:**
- **Deep tones**: UI frames, character silhouettes
- **Mid tones**: Character details, environmental elements
- **Light tones**: Highlights, qi effects, atmospheric elements
- **Accent colors**: Special attacks, status effects, interactive elements

### 3. **Stage/Platform Design**

Each combat arena is a carefully crafted diorama with:

**Platform Materials:**
- Worn stone tiles with Chinese patterns
- Wooden temple floors with visible grain
- Bamboo platforms with rope bindings
- Jade stone for mystical areas
- Cracked earth for demon realms

**Platform Details:**
- Visible thickness (8-12 pixels) showing material layers
- Edge wear and damage
- Small environmental details (grass tufts, cracks, moss)
- Subtle parallax between platform and background

### 4. **Background Art ("Window Paintings")**

Backgrounds are painted sceneries visible through the window frame:

**Artistic Style:**
- Traditional Chinese landscape painting (山水画) aesthetic
- Multiple depth layers for parallax
- Soft, painterly pixel art with dithering
- Atmospheric perspective with fading distant elements

**Scene Types:**
- Misty mountain ranges with pagodas
- Dense bamboo forests with light rays
- Ancient temples in clouds
- Moonlit lakes with willow trees
- Volcanic demon lands with floating rocks

### 5. **Character Design Philosophy**

#### Player Characters
**Current:** Simple geometric shapes (rectangles) with basic color coding
**Planned:**
- **Silhouette First**: Clear, readable shapes even in pure black
- **Flowing Fabrics**: Robes and sashes with secondary animation
- **Weapon Integration**: Weapons as extension of character design
- **Stance Variety**: Each character has unique idle stance
- **Color Scheme**: All character elements using VINIK24 palette

#### Design Elements
- Traditional Chinese clothing (Hanfu, martial robes)
- Hair ornaments and topknots
- Flowing ribbons and sashes
- Distinctive weapon types (dao, jian, staff, fan)

#### Enemy Design Tiers
1. **Common Bandits**: Simple clothing, basic weapons
2. **Martial Artists**: Sect uniforms, refined stances
3. **Elite Guards**: Ornate armor, intimidating masks
4. **Demons/Spirits**: Ethereal effects, non-human proportions
5. **Bosses**: Larger sprites, dramatic clothing, unique weapons

### 6. **Animation Principles**

#### Combat Animations
- **Anticipation**: 2-3 frame wind-up for attacks
- **Impact Freeze**: 1-2 frame pause on hit
- **Follow-through**: Weapon trails and fabric movement
- **Recovery**: Return to idle with secondary motion

#### Key Animations per Character
1. Idle (breathing, fabric sway)
2. Walk/Run cycle
3. Light Attack combo (3 hits)
4. Heavy Attack
5. Block/Parry pose
6. Dash (with afterimage)
7. Hit reaction
8. Stun/Posture break
9. Death sequence
10. Special move(s)

### 7. **Visual Effects (VFX)**

#### Particle Systems
- **Cherry blossoms**: Falling petals for atmosphere
- **Qi sparks**: Energy particles for hits
- **Dust clouds**: Movement and landing effects
- **Slash trails**: Weapon swing arcs
- **Spirit flames**: Mystical fire effects

#### Combat Effects
- **Parry Flash**: Bright circular burst with Chinese pattern
- **Posture Break**: Shattering effect with kanji (破)
- **Rage Activation**: Aura with floating Chinese symbols
- **Execution**: Dramatic ink splash effect

### 8. **UI/HUD Design**

#### Frame Design
- **Window Frame**: Contextual Chinese elements (temple archways, bamboo borders, mystical portals)
- **Corner Decorations**: Dragon or phoenix motifs
- **Border Pattern**: Cloud scrolls (云纹) or geometric patterns

#### Health/Resource Bars
**Current:** Simple colored bars (red health, yellow stamina, purple resource)
**Planned:** 
- **Container Style**: Bamboo segments or jade inlay
- **Fill Effects**: Liquid ink for health, flowing energy for qi
- **Typography**: Mix of pixel Chinese characters and numbers
- **Colors**: All bars using VINIK24 palette tones

#### Combat UI Elements
- **Attack Indicators**: Red Chinese seals (印章) for danger
- **Combo Counter**: Calligraphy brush strokes
- **Status Effects**: Floating Chinese characters

### 9. **Environmental Storytelling**

#### Stage Props
- Broken weapons stuck in ground
- Prayer flags and banners
- Stone lanterns
- Fallen leaves accumulation
- Training dummies
- Incense braziers with smoke

#### Interactive Elements
- **Destructibles**: Vases, barrels, bamboo
- **Hazards**: Spike traps, fire braziers
- **Atmospheric**: Birds that fly away, fireflies

### 10. **Lighting and Atmosphere**

#### Time of Day Variations
- **Dawn**: Soft orange light, long shadows
- **Noon**: Bright, minimal shadows
- **Dusk**: Golden hour, dramatic orange/purple
- **Night**: Blue moonlight, lantern pools

#### Weather Effects
- **Rain**: Visible droplets, puddle reflections
- **Snow**: Accumulation on platforms
- **Mist**: Fog layers for depth
- **Wind**: Particle effects, fabric movement

## Technical Specifications

### Development Phases
**Phase 1 (Current):** Geometric prototyping with placeholder colors
**Phase 2 (Next):** VINIK24 palette integration
**Phase 3 (Final):** Full pixel art assets

### Sprite Sheets (Target)
- **Character Sprites**: 512x512 per character
- **Effect Sprites**: 256x256 per effect type
- **Environment Tiles**: 32x32 or 16x16 base tiles
- **Background Layers**: 1280x720 minimum, 3-5 layers
- **Palette Constraint**: All assets limited to VINIK24's 24 colors

### Performance Considerations
- Maximum 100 particles on screen
- 3-5 background parallax layers
- Sprite batching for similar elements
- LOD system for distant elements

## Art Production Pipeline

### 1. Concept Phase
- Rough sketches establishing silhouette
- Color mood boards
- Animation planning

### 2. Pixel Art Creation
- Base sprite creation
- Animation frames
- Color variations for different tiers

### 3. Implementation
- Sprite sheet assembly
- Animation timing setup
- VFX integration
- Lighting passes

### 4. Polish
- Edge cleanup
- Color balance
- Animation smoothing
- Performance optimization

## Consistency Checklist

Before finalizing any art asset, verify:
- [ ] Matches established color palette
- [ ] Maintains consistent pixel density
- [ ] Readable at gameplay distance
- [ ] Follows animation principles
- [ ] Fits within technical constraints
- [ ] Supports gameplay clarity
- [ ] Enhances Wuxia atmosphere

## Reference Mood Board

### Visual Inspiration Sources
- **Artis Impact**: Diorama presentation, pixel art style
- **Chinese Ink Paintings**: Background art style
- **Wuxia Films**: Character poses, combat choreography
- **Dead Cells**: Animation fluidity, VFX impact
- **Blasphemous**: Environmental atmosphere
- **Traditional Chinese Architecture**: Structural details

## Updates and Revisions

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | [Current] | Initial design document |

---

*This document serves as the definitive guide for all art production in WU. All artists and developers should reference this document to maintain visual consistency throughout development.*