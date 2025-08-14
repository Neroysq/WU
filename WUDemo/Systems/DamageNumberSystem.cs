using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using System;
using System.Collections.Generic;

namespace WUDemo.Systems
{
    public class DamageNumber
    {
        public Vector2 Position { get; set; }
        public float Value { get; set; }
        public Color Color { get; set; }
        public float Timer { get; set; }
        public float MaxTime { get; set; }
        public bool IsCritical { get; set; }
        
        public DamageNumber(Vector2 position, float value, Color color, bool isCritical = false)
        {
            Position = position;
            Value = value;
            Color = color;
            IsCritical = isCritical;
            Timer = 0f;
            MaxTime = 1.2f;
        }
        
        public void Update(float dt)
        {
            Timer += dt;
            
            // Float upward and slightly to the side
            float xDrift = (float)Math.Sin(Timer * 3f) * 20f * dt;
            float yDrift = -60f * dt * (1f - Timer / MaxTime); // Slow down as it rises
            Position += new Vector2(xDrift, yDrift);
        }
        
        public bool IsExpired => Timer >= MaxTime;
        
        public float GetAlpha()
        {
            // Fade out in the last 30% of lifetime
            if (Timer > MaxTime * 0.7f)
            {
                return 1f - (Timer - MaxTime * 0.7f) / (MaxTime * 0.3f);
            }
            return 1f;
        }
        
        public float GetScale()
        {
            // Start big, quickly shrink, then stay steady
            if (Timer < 0.1f)
            {
                return 1.5f - (Timer / 0.1f) * 0.5f;
            }
            return 1f;
        }
    }
    
    public class DamageNumberSystem
    {
        private readonly List<DamageNumber> _damageNumbers;
        private readonly int _maxNumbers;
        
        public DamageNumberSystem(int maxNumbers = 50)
        {
            _maxNumbers = maxNumbers;
            _damageNumbers = new List<DamageNumber>(maxNumbers);
        }
        
        public void SpawnDamageNumber(Vector2 position, float damage, bool isHealing = false, bool isCritical = false)
        {
            if (_damageNumbers.Count >= _maxNumbers)
            {
                // Remove oldest
                _damageNumbers.RemoveAt(0);
            }
            
            Color color;
            if (isHealing)
            {
                color = new Color(100, 255, 100); // Green for healing
            }
            else if (isCritical)
            {
                color = new Color(255, 200, 50); // Yellow/gold for critical
            }
            else
            {
                color = new Color(255, 100, 100); // Red for damage
            }
            
            // Add slight random offset to prevent overlapping
            var random = new Random();
            float xOffset = (float)(random.NextDouble() * 20 - 10);
            float yOffset = (float)(random.NextDouble() * 10 - 5);
            
            _damageNumbers.Add(new DamageNumber(
                position + new Vector2(xOffset, yOffset),
                damage,
                color,
                isCritical
            ));
        }
        
        public void Update(float dt)
        {
            for (int i = _damageNumbers.Count - 1; i >= 0; i--)
            {
                _damageNumbers[i].Update(dt);
                
                if (_damageNumbers[i].IsExpired)
                {
                    _damageNumbers.RemoveAt(i);
                }
            }
        }
        
        public void Draw(SpriteBatch spriteBatch, SpriteFont font)
        {
            if (font == null) return;
            
            foreach (var number in _damageNumbers)
            {
                string text = number.Value.ToString("0");
                if (number.IsCritical)
                {
                    text = text + "!";
                }
                
                float alpha = number.GetAlpha();
                float scale = number.GetScale();
                
                Color drawColor = new Color(
                    (byte)number.Color.R,
                    (byte)number.Color.G,
                    (byte)number.Color.B,
                    (byte)(255 * alpha)
                );
                
                // Draw shadow for better visibility
                Vector2 shadowOffset = new Vector2(1, 1);
                spriteBatch.DrawString(
                    font,
                    text,
                    number.Position + shadowOffset,
                    new Color((byte)0, (byte)0, (byte)0, (byte)(128 * alpha)),
                    0f,
                    Vector2.Zero,
                    scale,
                    SpriteEffects.None,
                    0f
                );
                
                // Draw the number
                spriteBatch.DrawString(
                    font,
                    text,
                    number.Position,
                    drawColor,
                    0f,
                    Vector2.Zero,
                    scale,
                    SpriteEffects.None,
                    0f
                );
            }
        }
        
        public void Clear()
        {
            _damageNumbers.Clear();
        }
    }
}