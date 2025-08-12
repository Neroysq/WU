using Microsoft.Xna.Framework;
using System;

namespace WUDemo.Systems
{
    public class Camera2D
    {
        private Vector2 _position;
        private Vector2 _offset;
        private float _shake;
        private float _zoom;
        private readonly Random _rng;
        
        public Vector2 Position
        {
            get => _position;
            set => _position = value;
        }
        
        public float Zoom
        {
            get => _zoom;
            set => _zoom = MathHelper.Clamp(value, 0.5f, 2f);
        }
        
        public float Shake
        {
            get => _shake;
            set => _shake = Math.Max(0, value);
        }
        
        public Camera2D()
        {
            _position = Vector2.Zero;
            _offset = Vector2.Zero;
            _zoom = 1f;
            _shake = 0f;
            _rng = new Random();
        }
        
        public void Update(float dt)
        {
            if (_shake > 0)
            {
                _shake = Math.Max(0, _shake - 20f * dt);
                float dx = ((float)_rng.NextDouble() * 2f - 1f) * _shake;
                float dy = ((float)_rng.NextDouble() * 2f - 1f) * _shake * 0.6f;
                _offset = new Vector2(dx, dy);
            }
            else
            {
                _offset *= 0.85f;
            }
        }
        
        public void AddShake(float amount)
        {
            _shake += amount;
        }
        
        public void Reset()
        {
            _position = Vector2.Zero;
            _offset = Vector2.Zero;
            _shake = 0f;
            _zoom = 1f;
        }
        
        public Matrix GetTransform()
        {
            return Matrix.CreateTranslation(new Vector3(-_position + _offset, 0f)) *
                   Matrix.CreateScale(_zoom);
        }
        
        public Matrix GetTransform(int viewportWidth, int viewportHeight)
        {
            return Matrix.CreateTranslation(new Vector3(-_position + _offset, 0f)) *
                   Matrix.CreateScale(_zoom) *
                   Matrix.CreateTranslation(new Vector3(viewportWidth / 2f, viewportHeight / 2f, 0f));
        }
    }
}