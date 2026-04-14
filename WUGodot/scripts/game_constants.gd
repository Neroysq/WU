class_name GameConstants
extends RefCounted

const VIEW_WIDTH: int = 1920
const VIEW_HEIGHT: int = 1080
const TARGET_FPS: int = 60

const GROUND_Y: float = 940.0
const WORLD_BOUNDS_LEFT: float = 80.0
const WORLD_BOUNDS_RIGHT: float = VIEW_WIDTH - 80.0

const DEFAULT_MOVE_SPEED: float = 320.0
const DEFAULT_ATTACK_RANGE: float = 72.0
const DEFAULT_ATTACK_DAMAGE: float = 12.0
const DEFAULT_POSTURE_DAMAGE: float = 22.0

const DASH_DURATION: float = 0.22
const DASH_COOLDOWN: float = 0.80
const DASH_STARTUP_END: float = 0.04
const DASH_IFRAME_END: float = 0.18
const DASH_RECOVERY_END: float = 0.22
const PARRY_WINDOW: float = 0.15
const STUN_DURATION: float = 0.7

const DEFAULT_HEALTH_MAX: float = 100.0
const DEFAULT_POSTURE_MAX: float = 100.0
const DEFAULT_RAGE_MAX: float = 100.0
const POSTURE_RECOVERY_RATE: float = 12.0

const CAMERA_SHAKE_DECAY: float = 20.0
const TIME_SCALE_RECOVERY: float = 0.08
const MAX_PARTICLES: int = 100

const COLOR_INK_BLACK: Color = Color8(15, 15, 27)       # #0f0f1b
const COLOR_INK_DARK: Color = Color8(15, 15, 27)        # #0f0f1b (alias)
const COLOR_INK_MID: Color = Color8(86, 90, 117)        # #565a75
const COLOR_SCROLL_WHITE: Color = Color8(250, 246, 246) # #faf6f6
const COLOR_PAPER: Color = Color8(198, 183, 190)        # #c6b7be
const COLOR_JADE_GREEN: Color = Color8(78, 131, 57)     # #4e8339
const COLOR_JADE_DARK: Color = Color8(44, 74, 46)       # #2c4a2e
const COLOR_VERMILLION_RED: Color = Color8(180, 32, 42) # #b4202a
const COLOR_CRIMSON: Color = Color8(191, 38, 82)        # #bf2652
const COLOR_IMPERIAL_GOLD: Color = Color8(238, 156, 36) # #ee9c24
const COLOR_GOLD_DARK: Color = Color8(106, 74, 26)      # derived shadow tone (not in VINIK24 - exempted as a computed midpoint)
const COLOR_GOLD_BRIGHT: Color = Color8(248, 200, 60)   # #f8c83c
const COLOR_MOUNTAIN_BLUE: Color = Color8(32, 57, 79)   # #20394f
const COLOR_MISTY_BLUE: Color = Color8(87, 115, 153)    # #577399
const COLOR_LIGHT_BLUE: Color = Color8(150, 178, 197)   # #96b2c5
const COLOR_SKY_BLUE: Color = Color8(161, 210, 224)     # #a1d2e0
const COLOR_EARTH_DARK: Color = Color8(59, 23, 37)      # #3b1725
const COLOR_EARTH_MID: Color = Color8(171, 82, 54)      # #ab5236
const COLOR_EARTH_LIGHT: Color = Color8(223, 113, 38)   # #df7126
const COLOR_PURPLE_DARK: Color = Color8(107, 62, 117)   # #6b3e75
const COLOR_PURPLE_MID: Color = Color8(144, 94, 169)    # #905ea9
const COLOR_PURPLE_LIGHT: Color = Color8(168, 132, 243) # #a884f3
const COLOR_SKIN_WARM: Color = Color8(244, 158, 76)     # #f49e4c
const COLOR_MAROON: Color = Color8(116, 35, 60)         # #74233c
const COLOR_RED_DARK: Color = Color8(115, 23, 45)       # #73172d

# UI semantic aliases
const COLOR_PANEL_BG: Color = Color8(15, 15, 27)
const COLOR_PANEL_BORDER: Color = Color8(86, 90, 117)
const COLOR_PANEL_ACCENT: Color = Color8(238, 156, 36)
const COLOR_TEXT_HEADING: Color = Color8(250, 246, 246)
const COLOR_TEXT_SUBHEADING: Color = Color8(198, 183, 190)
const COLOR_TEXT_BODY: Color = Color8(150, 178, 197)
const COLOR_TEXT_CAPTION: Color = Color8(86, 90, 117)
const COLOR_TEXT_ACCENT: Color = Color8(238, 156, 36)
const COLOR_HEALTH: Color = Color8(180, 32, 42)
const COLOR_POSTURE: Color = Color8(238, 156, 36)
const COLOR_RAGE: Color = Color8(78, 131, 57)
