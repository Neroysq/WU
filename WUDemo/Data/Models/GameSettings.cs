namespace WUDemo.Data.Models
{
    public class GameSettings
    {
        // Display
        public int ViewWidth { get; set; }
        public int ViewHeight { get; set; }
        public int TargetFPS { get; set; }
        
        // World
        public float GroundY { get; set; }
        public float WorldBoundsLeft { get; set; }
        public float WorldBoundsRight { get; set; }
        
        // Global Combat
        public float DefaultPostureRecoveryRate { get; set; }
        public float ParryWindow { get; set; }
        public float StunDuration { get; set; }
        
        // Visual Effects
        public float CameraShakeDecay { get; set; }
        public float TimeScaleRecovery { get; set; }
        public int MaxParticles { get; set; }
        
        // Damage Numbers
        public float DamageNumberLifetime { get; set; }
        public float DamageNumberSpeed { get; set; }
        public float DamageNumberGravity { get; set; }
    }
}