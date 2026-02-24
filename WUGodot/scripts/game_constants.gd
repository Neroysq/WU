class_name GameConstants
extends RefCounted

const VIEW_WIDTH: int = 1280
const VIEW_HEIGHT: int = 720
const TARGET_FPS: int = 60

const GROUND_Y: float = 580.0
const WORLD_BOUNDS_LEFT: float = 80.0
const WORLD_BOUNDS_RIGHT: float = VIEW_WIDTH - 80.0

const DEFAULT_MOVE_SPEED: float = 420.0
const DEFAULT_ATTACK_RANGE: float = 72.0
const DEFAULT_ATTACK_DAMAGE: float = 12.0
const DEFAULT_POSTURE_DAMAGE: float = 22.0

const ATTACK_DURATION: float = 0.35
const ATTACK_ACTIVE_START: float = 0.10
const ATTACK_ACTIVE_END: float = 0.18
const DASH_DURATION: float = 0.16
const DASH_COOLDOWN: float = 0.60
const PARRY_WINDOW: float = 0.12
const STUN_DURATION: float = 0.7

const DEFAULT_HEALTH_MAX: float = 100.0
const DEFAULT_POSTURE_MAX: float = 100.0
const DEFAULT_RAGE_MAX: float = 100.0
const POSTURE_RECOVERY_RATE: float = 12.0

const CAMERA_SHAKE_DECAY: float = 20.0
const TIME_SCALE_RECOVERY: float = 0.08
const MAX_PARTICLES: int = 100

const COLOR_INK_BLACK: Color = Color8(26, 26, 29)
const COLOR_INK_DARK: Color = Color8(18, 18, 22)
const COLOR_INK_MID: Color = Color8(36, 34, 42)
const COLOR_SCROLL_WHITE: Color = Color8(245, 245, 220)
const COLOR_PAPER: Color = Color8(232, 226, 198)
const COLOR_JADE_GREEN: Color = Color8(0, 168, 107)
const COLOR_JADE_DARK: Color = Color8(0, 120, 82)
const COLOR_VERMILLION_RED: Color = Color8(227, 66, 52)
const COLOR_CRIMSON: Color = Color8(182, 44, 44)
const COLOR_IMPERIAL_GOLD: Color = Color8(255, 215, 0)
const COLOR_GOLD_DARK: Color = Color8(182, 140, 34)
const COLOR_MOUNTAIN_BLUE: Color = Color8(74, 95, 122)
const COLOR_MISTY_BLUE: Color = Color8(96, 114, 140)
