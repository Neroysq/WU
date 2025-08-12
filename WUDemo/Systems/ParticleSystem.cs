using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using System;
using System.Collections.Generic;
using WUDemo.Core;

namespace WUDemo.Systems
{
    public struct Particle
    {
        public Vector2 Position;
        public Vector2 Velocity;
        public float Life;
        public float MaxLife;
        public Color Color;
        public int Size;
        public float Rotation;
        public float RotationSpeed;
    }
    
    public class ParticleSystem
    {
        private readonly List<Particle> _particles;
        private readonly Random _rng;
        private readonly int _maxParticles;
        
        public ParticleSystem(int maxParticles = 100)
        {
            _particles = new List<Particle>(maxParticles);
            _rng = new Random();
            _maxParticles = maxParticles;
        }
        
        public void SpawnHitSparks(Vector2 center, int count, Color color)
        {
            if (_particles.Count + count > _maxParticles)
                count = _maxParticles - _particles.Count;
            
            for (int i = 0; i < count; i++)
            {
                float angle = (float)(_rng.NextDouble() * Math.PI * 2);
                float speed = 280f + (float)_rng.NextDouble() * 180f;
                var velocity = new Vector2(MathF.Cos(angle), MathF.Sin(angle)) * speed;
                float life = 0.18f + (float)_rng.NextDouble() * 0.22f;
                
                _particles.Add(new Particle
                {
                    Position = center,
                    Velocity = velocity,
                    Life = life,
                    MaxLife = life,
                    Color = color,
                    Size = 2 + _rng.Next(3),
                    Rotation = (float)(_rng.NextDouble() * Math.PI * 2),
                    RotationSpeed = ((float)_rng.NextDouble() - 0.5f) * 12f,
                });
            }
        }
        
        public void Update(float dt)
        {
            for (int i = _particles.Count - 1; i >= 0; i--)
            {
                var p = _particles[i];
                p.Life -= dt;
                
                if (p.Life <= 0)
                {
                    _particles.RemoveAt(i);
                    continue;
                }
                
                p.Position += p.Velocity * dt;
                p.Velocity *= 0.92f; // Drag
                p.Velocity.Y += 120f * dt; // Gravity
                p.Rotation += p.RotationSpeed * dt;
                
                _particles[i] = p;
            }
        }
        
        public void Draw(SpriteBatch spriteBatch, Texture2D pixel)
        {
            foreach (var p in _particles)
            {
                float lifeRatio = p.Life / p.MaxLife;
                byte alpha = (byte)(lifeRatio * 255);
                var particleColor = new Color(p.Color.R, p.Color.G, p.Color.B, alpha);
                
                var destRect = new Rectangle(
                    (int)p.Position.X,
                    (int)p.Position.Y,
                    (int)(p.Size * (0.5f + lifeRatio * 0.5f)),
                    (int)(p.Size * (0.5f + lifeRatio * 0.5f))
                );
                
                var origin = new Vector2(destRect.Width / 2f, destRect.Height / 2f);
                
                spriteBatch.Draw(
                    pixel, 
                    destRect, 
                    null, 
                    particleColor, 
                    p.Rotation, 
                    origin, 
                    SpriteEffects.None, 
                    0f
                );
            }
        }
        
        public void Clear()
        {
            _particles.Clear();
        }
        
        public int Count => _particles.Count;
    }
}