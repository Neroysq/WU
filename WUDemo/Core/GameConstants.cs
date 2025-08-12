using Microsoft.Xna.Framework;

namespace WUDemo.Core
{
    public static class GameConstants
    {
        // Display
        public const int ViewWidth = 1280;
        public const int ViewHeight = 720;
        public const int TargetFPS = 60;
        
        // World
        public const float GroundY = 580f;
        public const float WorldBoundsLeft = 80f;
        public const float WorldBoundsRight = ViewWidth - 80f;
        
        // Combat
        public const float DefaultMoveSpeed = 420f;
        public const float DefaultAttackRange = 72f;
        public const float DefaultAttackDamage = 12f;
        public const float DefaultPostureDamage = 22f;
        
        // Timing
        public const float AttackDuration = 0.35f;
        public const float AttackActiveStart = 0.10f;
        public const float AttackActiveEnd = 0.18f;
        public const float DashDuration = 0.16f;
        public const float DashCooldown = 0.60f;
        public const float ParryWindow = 0.12f;
        public const float StunDuration = 0.7f;
        
        // Resources
        public const float DefaultHealthMax = 100f;
        public const float DefaultPostureMax = 100f;
        public const float DefaultRageMax = 100f;
        public const float PostureRecoveryRate = 12f;
        
        // Visual Effects
        public const float CameraShakeDecay = 20f;
        public const float TimeScaleRecovery = 0.08f;
        public const int MaxParticles = 100;
        
        // Colors
        public static readonly Color ColorInkBlack = new Color(26, 26, 29);
        public static readonly Color ColorScrollWhite = new Color(245, 245, 220);
        public static readonly Color ColorJadeGreen = new Color(0, 168, 107);
        public static readonly Color ColorVermillionRed = new Color(227, 66, 52);
        public static readonly Color ColorImperialGold = new Color(255, 215, 0);
        public static readonly Color ColorMountainBlue = new Color(74, 95, 122);
    }
}