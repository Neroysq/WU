# WU (武) - Gameplay Design Document
*Version 1.0 - Ancient China Wuxia-themed 2D Action Roguelike*

## Core Design Pillars

### 1. **Replayability**
Every run offers meaningful choices and discovery through procedural elements, build variety, and emergent gameplay situations.

### 2. **Diverse Combat Builds**
Deep character customization through martial arts styles, weapon masteries, and qi cultivation techniques that fundamentally change how combat feels and plays.

### 3. **Excellent Action Feel**
Precise, responsive controls with satisfying feedback that makes every attack, parry, and movement feel impactful and deliberate.

## Core Gameplay Loop

### Run Structure
1. **Character Selection**: Choose starting martial artist with unique base abilities
2. **World Navigation**: Traverse interconnected combat encounters on the world map
3. **Combat Encounters**: Engage in skill-based duels using current build
4. **Character Progression**: Acquire new techniques, weapons, and cultivation methods
5. **Boss Confrontation**: Face increasingly challenging master opponents
6. **Death & Rebirth**: Retain meta-progression while starting fresh runs

### Session Flow
- **5-10 minutes per combat encounter**
- **30-60 minutes per complete run**
- **Immediate restart with new build possibilities**

## Combat System Design

### Core Mechanics

#### **Martial Arts Trinity**
Every combat action revolves around three interconnected systems:

1. **攻 (Gōng) - Attack**
   - Light attacks: Fast, combo-building strikes
   - Heavy attacks: Powerful, stance-breaking blows
   - Special techniques: Unique moves per martial style

2. **守 (Shǒu) - Defense** 
   - Block: Reduce damage, build posture pressure
   - Parry: Perfect timing deflects with counterattack window
   - Dodge: I-frames with positioning advantage

3. **气 (Qì) - Energy**
   - Resource for special techniques and enhanced attacks
   - Regenerates through successful combat actions
   - Different cultivation methods alter qi behavior

### Build Diversity Systems

#### **Martial Arts Schools (武术门派)**
Each school fundamentally changes combat approach:

**外家拳 (External Styles)**
- **Shaolin (少林)**: Balanced offense/defense, combo-focused
- **Eagle Claw (鹰爪)**: Grappling specialist, posture manipulation
- **Drunken Boxing (醉拳)**: Unpredictable movement, evasion focus

**内家拳 (Internal Styles)**
- **Taiji (太极)**: Redirection and counterattacks
- **Bagua (八卦)**: Circular movement and positioning
- **Xingyi (形意)**: Direct, explosive power strikes

**兵器 (Weapons Mastery)**
- **Dao (刀)**: Slashing combos, aggressive pressure
- **Jian (剑)**: Precision strikes, elegant techniques
- **Staff (棍)**: Reach advantage, sweeping attacks
- **Double Weapons**: Complex input patterns, high reward

#### **Qi Cultivation Paths (修炼道路)**
Modify how qi resource behaves:

- **Fire Cultivation**: Qi enhances attack power, burns enemies
- **Water Cultivation**: Qi provides healing and flow states
- **Metal Cultivation**: Qi strengthens defense and reflects damage
- **Wood Cultivation**: Qi enables rapid regeneration
- **Earth Cultivation**: Qi creates armor and stability

#### **Technique Acquisition**
**Random Encounter Rewards**: New moves discovered through combat
**Master Teachings**: Rare, powerful techniques from defeated experts
**Ancient Scrolls**: Hidden techniques found in exploration
**Cultivation Breakthroughs**: Qi advancement unlocks new abilities

### Progression Systems

#### **Within-Run Progression**
- **Technique Mastery**: Repeated use improves damage/efficiency
- **Qi Cultivation Level**: Increases maximum qi and regeneration
- **Weapon Affinity**: Better stats with preferred weapon types
- **Battle Insights**: Temporary buffs gained from victory conditions

#### **Meta-Progression (Between Runs)**
- **Martial Heritage**: Permanent character unlocks
- **Ancient Wisdom**: Small stat bonuses that accumulate
- **Master's Memories**: Start runs with basic techniques already known
- **Sect Reputation**: Unlock new starting equipment options

## Action Feel & Feedback

### Input Responsiveness
- **Frame-Perfect Inputs**: 1-2 frame windows for advanced techniques
- **Buffer Systems**: 3-4 frame input buffers for combo fluidity
- **Interrupt Systems**: Most animations cancellable into defensive options

### Visual Feedback
- **Hit Confirmation**: Screen flash, particle effects, brief hitstop
- **Posture Breaks**: Dramatic visual effect with vulnerability window
- **Combo Counters**: Elegant calligraphy-style number display
- **Qi State**: Visual aura effects indicating cultivation level

### Audio Feedback
- **Impact Sounds**: Satisfying hit confirmation with martial arts weapon sounds
- **Whoosh Effects**: Air displacement for powerful attacks
- **Breathing**: Character exertion audio tied to qi usage
- **Environmental**: Platform creaks, fabric rustling

### Haptic Feedback (Controller)
- **Light Rumble**: Successful hits and blocks
- **Heavy Rumble**: Posture breaks and powerful attacks
- **Rhythmic Pulses**: Qi regeneration and special states

## Enemy Design Philosophy

### Opponent Categories

#### **Bandit Fighters (盗匪)**
- **Purpose**: Tutorial opponents, basic pattern practice
- **Behavior**: Simple attack patterns, predictable timing
- **Build Testing**: Safe environment to experiment with new techniques

#### **Martial Artists (武者)**
- **Purpose**: Mirror player capabilities with specific school focus
- **Behavior**: Use same techniques as player, creating style vs style matches
- **Build Challenge**: Force adaptation and counter-strategies

#### **Elite Guards (精锐卫士)**
- **Purpose**: Specialized defensive or offensive challenges
- **Behavior**: Extreme focus on one aspect (heavy armor, fast attacks, etc.)
- **Build Pressure**: Test specific build components

#### **Demon Spirits (妖魔)**
- **Purpose**: Break conventional combat rules
- **Behavior**: Unique mechanics not available to player
- **Build Innovation**: Force creative use of current abilities

#### **Grandmasters (大师)**
- **Purpose**: Ultimate skill test combining multiple challenges
- **Behavior**: Multiple phases, adaptive AI, full technique repertoire
- **Build Mastery**: Require complete understanding of current build

### Adaptive Difficulty
- **Performance Scaling**: Better play leads to stronger opponents
- **Build Countering**: Enemies occasionally equipped to counter player's current build
- **Momentum Systems**: Winning/losing streaks modify encounter difficulty

## World & Encounter Design

### Map Structure
- **Node-Based Progression**: Choose path through interconnected combat encounters
- **Risk/Reward Branches**: Harder paths offer better progression rewards
- **Secret Encounters**: Hidden masters with rare technique rewards
- **Rest Areas**: Safe spaces for technique practice and build planning

### Encounter Types

#### **Honor Duels (切磋)**
- **Standard 1v1 combat**
- **Focus on pure skill expression**
- **Most common encounter type**

#### **Ambush Scenarios (伏击)**
- **Unfavorable starting positions**
- **Multiple opponents in sequence**
- **Tests adaptability under pressure**

#### **Sparring Matches (比武)**
- **Non-lethal with special victory conditions**
- **Technique demonstration challenges**
- **Unique rewards for creative solutions**

#### **Demon Hunts (除魔)**
- **Supernatural opponents with unique mechanics**
- **Environmental hazards**
- **Tests build versatility**

## Replayability Mechanics

### Procedural Elements
- **Technique Pool Randomization**: Different techniques available each run
- **Encounter Ordering**: Varied enemy sequence creates different build pressures
- **Master Locations**: Random placement of technique teachers
- **Equipment Spawns**: Different starting weapon/armor configurations

### Build Discovery
- **Technique Synergies**: Combinations create emergent playstyles
- **Cross-School Training**: Mix techniques from different martial arts
- **Weapon Style Fusion**: Combine weapon techniques with hand-to-hand combat
- **Qi Cultivation Variants**: Different cultivation paths unlock unique techniques

### Challenge Variants
- **Ascension Levels**: Increasing difficulty modifiers with unique rewards
- **Daily Challenges**: Specific build constraints or objectives
- **Master's Trials**: Preset challenging encounters with leaderboards
- **Perfect Run Attempts**: No-damage challenges with special unlocks

## Balancing Philosophy

### Power Scaling
- **Horizontal Progression**: New options rather than pure stat increases
- **Situational Strengths**: Every build excels in specific scenarios
- **Meaningful Tradeoffs**: Power comes with corresponding vulnerabilities
- **Skill Expression**: Player execution matters more than build optimization

### Combat Pacing
- **Quick Encounters**: Fast-paced duels maintain engagement
- **Decisive Moments**: Brief windows where superior play creates large advantages
- **Recovery Opportunities**: Mistakes aren't immediately fatal
- **Escalating Stakes**: Encounters become more demanding as run progresses

## Technical Implementation Notes

### Performance Targets
- **60 FPS Combat**: Consistent framerate for responsive feel
- **Input Lag < 50ms**: Minimal delay between input and action
- **Load Times < 2s**: Quick restart for failed runs
- **Memory Efficient**: Support for extended play sessions

### Save System
- **Run State Persistence**: Save mid-run for session interruption
- **Meta-Progress Tracking**: Reliable unlock and achievement system
- **Replay Storage**: Save exceptional moments for sharing
- **Settings Sync**: Maintain control and display preferences

### Accessibility Features
- **Colorblind Support**: Alternative indicators for status effects
- **Input Remapping**: Full controller and keyboard customization
- **Difficulty Options**: Separate sliders for reaction time and complexity
- **Visual Clarity**: Options for reduced visual effects

## Integration with Art Direction

### Diorama Combat
- **Stage-Based Encounters**: Each fight on unique platform with thematic background
- **Contextual Framing**: Window elements change based on encounter type
- **Environmental Storytelling**: Stage details hint at opponent background

### VINIK24 Palette Integration
- **Status Indication**: Different palette tones for health/qi/posture states
- **Attack Types**: Color coding for different martial arts schools
- **Environmental Mood**: Palette shifts reflect encounter difficulty/type

### Animation Requirements
- **Martial Arts Authenticity**: Moves based on real techniques
- **Flow State Visualization**: Smooth transitions between techniques
- **Impact Emphasis**: Clear visual distinction between hit types

## Success Metrics

### Player Engagement
- **Session Length**: Target 45-60 minute average play sessions
- **Return Rate**: 70%+ players return within 24 hours
- **Completion Rate**: 15-20% of runs reach final boss
- **Build Variety**: Players experiment with 80%+ of available techniques

### Gameplay Flow
- **Combat Encounter Length**: 30 seconds to 3 minutes
- **Decision Points**: 5-10 meaningful choices per run
- **Technique Usage**: Balanced use across all martial arts schools
- **Difficulty Curve**: Steady increase in challenge without walls

## Updates and Revisions

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | [Current] | Initial gameplay design document |

---

*This document defines the core gameplay experience for WU, focusing on the three pillars of replayability, diverse combat builds, and excellent action feel. All subsequent gameplay development should reference and support these design goals.*