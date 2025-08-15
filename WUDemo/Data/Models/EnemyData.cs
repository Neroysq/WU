using Microsoft.Xna.Framework;
using System.Text.Json.Serialization;

namespace WUDemo.Data.Models
{
    public class EnemyData
    {
        public string Type { get; set; }
        public string Name { get; set; }
        public string Description { get; set; }
        
        // Movement
        public float MoveSpeed { get; set; }
        public float JumpForce { get; set; }
        public float Gravity { get; set; }
        
        // Combat Stats
        public float HealthMax { get; set; }
        public float PostureMax { get; set; }
        public float PostureRecoveryRate { get; set; }
        
        // Attack Properties
        public float AttackDamage { get; set; }
        public float AttackPostureDamage { get; set; }
        public float AttackRange { get; set; }
        public float AttackDuration { get; set; }
        public float TelegraphDuration { get; set; }
        
        // AI Behavior
        public float AggressionLevel { get; set; }
        public float ReactionTime { get; set; }
        public float AttackCooldown { get; set; }
        public float BlockChance { get; set; }
        public float DodgeChance { get; set; }
        
        // Visual
        [JsonConverter(typeof(ColorJsonConverter))]
        public Color ColorBody { get; set; }
        [JsonConverter(typeof(ColorJsonConverter))]
        public Color ColorAccent { get; set; }
        
        // Dimensions
        public float HalfWidth { get; set; }
        public float Height { get; set; }
    }
}