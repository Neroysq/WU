using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using System;
using System.Collections.Generic;

namespace WUDemo.Graphics
{
    public class AnimatedSprite
    {
        private Dictionary<string, Animation> _animations;
        private Animation _currentAnimation;
        private Texture2D _spriteSheet;
        private Vector2 _origin;
        private float _scale;
        private float _rotation;
        private Color _tint;
        
        public string CurrentAnimationName => _currentAnimation?.Name ?? "";
        public bool IsAnimationComplete => _currentAnimation?.IsComplete ?? false;
        public Vector2 Origin => _origin;
        public float Scale 
        { 
            get => _scale; 
            set => _scale = value; 
        }
        public float Rotation 
        { 
            get => _rotation; 
            set => _rotation = value; 
        }
        public Color Tint 
        { 
            get => _tint; 
            set => _tint = value; 
        }
        
        public AnimatedSprite(Texture2D spriteSheet, Vector2? origin = null)
        {
            _spriteSheet = spriteSheet;
            _animations = new Dictionary<string, Animation>();
            _origin = origin ?? Vector2.Zero;
            _scale = 1f;
            _rotation = 0f;
            _tint = Color.White;
        }
        
        public void AddAnimation(string name, Animation animation)
        {
            _animations[name] = animation;
            
            if (_currentAnimation == null)
            {
                _currentAnimation = animation;
            }
        }
        
        public void AddAnimation(string name, int startX, int startY, int width, int height, 
                                int frameCount, float frameDuration, bool isLooping = true)
        {
            var frames = new List<Rectangle>();
            
            for (int i = 0; i < frameCount; i++)
            {
                frames.Add(new Rectangle(
                    startX + i * width,
                    startY,
                    width,
                    height
                ));
            }
            
            AddAnimation(name, new Animation(name, frames, frameDuration, isLooping));
        }
        
        public void PlayAnimation(string name, bool resetIfSame = false)
        {
            if (!_animations.ContainsKey(name))
            {
                throw new ArgumentException($"Animation '{name}' not found");
            }
            
            if (_currentAnimation?.Name == name && !resetIfSame)
            {
                return;
            }
            
            _currentAnimation = _animations[name];
            _currentAnimation.Reset();
        }
        
        public void Update(float deltaTime)
        {
            _currentAnimation?.Update(deltaTime);
        }
        
        public void Draw(SpriteBatch spriteBatch, Vector2 position, SpriteEffects effects = SpriteEffects.None)
        {
            if (_currentAnimation == null || _spriteSheet == null)
                return;
                
            var sourceRect = _currentAnimation.CurrentFrameRect;
            var origin = new Vector2(
                sourceRect.Width * _origin.X,
                sourceRect.Height * _origin.Y
            );
            
            spriteBatch.Draw(
                _spriteSheet,
                position,
                sourceRect,
                _tint,
                _rotation,
                origin,
                _scale,
                effects,
                0f
            );
        }
        
        public void Draw(SpriteBatch spriteBatch, Rectangle destinationRect, SpriteEffects effects = SpriteEffects.None)
        {
            if (_currentAnimation == null || _spriteSheet == null)
                return;
                
            spriteBatch.Draw(
                _spriteSheet,
                destinationRect,
                _currentAnimation.CurrentFrameRect,
                _tint,
                _rotation,
                Vector2.Zero,
                effects,
                0f
            );
        }
        
        public Rectangle GetCurrentFrameBounds()
        {
            return _currentAnimation?.CurrentFrameRect ?? Rectangle.Empty;
        }
        
        public void SetFrame(int frame)
        {
            if (_currentAnimation != null && frame >= 0 && frame < _currentAnimation.Frames.Count)
            {
                var animation = _currentAnimation;
                animation.Reset();
                for (int i = 0; i < frame; i++)
                {
                    animation.Update(animation.FrameDuration);
                }
            }
        }
    }
}