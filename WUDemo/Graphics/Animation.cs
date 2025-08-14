using Microsoft.Xna.Framework;
using System.Collections.Generic;

namespace WUDemo.Graphics
{
    public class Animation
    {
        public string Name { get; }
        public List<Rectangle> Frames { get; }
        public float FrameDuration { get; }
        public bool IsLooping { get; }
        public bool FlipHorizontally { get; set; }
        public bool FlipVertically { get; set; }
        
        private float _timer;
        private int _currentFrame;
        
        public int CurrentFrame => _currentFrame;
        public Rectangle CurrentFrameRect => Frames[_currentFrame];
        public bool IsComplete => !IsLooping && _currentFrame >= Frames.Count - 1;
        
        public Animation(string name, List<Rectangle> frames, float frameDuration, bool isLooping = true)
        {
            Name = name;
            Frames = frames;
            FrameDuration = frameDuration;
            IsLooping = isLooping;
            _currentFrame = 0;
            _timer = 0f;
        }
        
        public void Update(float deltaTime)
        {
            _timer += deltaTime;
            
            if (_timer >= FrameDuration)
            {
                _timer -= FrameDuration;
                _currentFrame++;
                
                if (_currentFrame >= Frames.Count)
                {
                    if (IsLooping)
                    {
                        _currentFrame = 0;
                    }
                    else
                    {
                        _currentFrame = Frames.Count - 1;
                    }
                }
            }
        }
        
        public void Reset()
        {
            _currentFrame = 0;
            _timer = 0f;
        }
        
        public Animation Clone()
        {
            return new Animation(Name, new List<Rectangle>(Frames), FrameDuration, IsLooping)
            {
                FlipHorizontally = FlipHorizontally,
                FlipVertically = FlipVertically
            };
        }
    }
}