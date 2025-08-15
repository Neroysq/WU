using Microsoft.Xna.Framework;
using System;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace WUDemo.Data.Models
{
    public class CharacterData
    {
        public string Name { get; set; }
        public string Description { get; set; }
        
        // Movement
        public float MoveSpeed { get; set; }
        public float JumpForce { get; set; }
        public float Gravity { get; set; }
        public float DashSpeed { get; set; }
        public float AirDashSpeed { get; set; }
        
        // Combat Stats
        public float HealthMax { get; set; }
        public float PostureMax { get; set; }
        public float RageMax { get; set; }
        public float PostureRecoveryRate { get; set; }
        
        // Attack Properties
        public float AttackDamage { get; set; }
        public float AttackPostureDamage { get; set; }
        public float AttackRange { get; set; }
        public float AttackDuration { get; set; }
        public float AttackActiveStart { get; set; }
        public float AttackActiveEnd { get; set; }
        
        // Cooldowns
        public float DashDuration { get; set; }
        public float DashCooldown { get; set; }
        public float ParryWindow { get; set; }
        public float StunDuration { get; set; }
        public float ComboWindow { get; set; }
        
        // Visual
        [JsonConverter(typeof(ColorJsonConverter))]
        public Color ColorBody { get; set; }
        [JsonConverter(typeof(ColorJsonConverter))]
        public Color ColorAccent { get; set; }
        
        // Dimensions
        public float HalfWidth { get; set; }
        public float Height { get; set; }
    }
    
    public class ColorJsonConverter : JsonConverter<Color>
    {
        public override Color Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        {
            if (reader.TokenType == JsonTokenType.String)
            {
                var hex = reader.GetString();
                if (hex.StartsWith("#"))
                {
                    hex = hex.Substring(1);
                }
                
                if (hex.Length == 6)
                {
                    int r = Convert.ToInt32(hex.Substring(0, 2), 16);
                    int g = Convert.ToInt32(hex.Substring(2, 2), 16);
                    int b = Convert.ToInt32(hex.Substring(4, 2), 16);
                    return new Color(r, g, b);
                }
            }
            
            throw new JsonException("Invalid color format");
        }
        
        public override void Write(Utf8JsonWriter writer, Color value, JsonSerializerOptions options)
        {
            writer.WriteStringValue($"#{value.R:X2}{value.G:X2}{value.B:X2}");
        }
    }
}