using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Content;
using Microsoft.Xna.Framework.Graphics;
using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;

namespace WUDemo.Core
{
    public class AssetManager
    {
        private ContentManager _content;
        private GraphicsDevice _graphics;
        private Dictionary<string, Texture2D> _textures;
        private Dictionary<string, SpriteFont> _fonts;
        private Texture2D _pixel;
        
        public Texture2D Pixel => _pixel;
        
        public AssetManager(ContentManager content, GraphicsDevice graphics)
        {
            _content = content;
            _graphics = graphics;
            _textures = new Dictionary<string, Texture2D>();
            _fonts = new Dictionary<string, SpriteFont>();
            
            CreatePixelTexture();
        }
        
        private void CreatePixelTexture()
        {
            _pixel = new Texture2D(_graphics, 1, 1);
            _pixel.SetData(new[] { Color.White });
        }
        
        public void LoadAssets()
        {
            // Load default font
            try
            {
                _fonts["default"] = _content.Load<SpriteFont>("DefaultFont");
            }
            catch
            {
                // Font not found, we'll handle text rendering differently if needed
            }
            
            // Create placeholder textures
            CreatePlaceholderTextures();
        }
        
        private void CreatePlaceholderTextures()
        {
            // Create simple colored rectangle placeholders for now
            _textures["player"] = CreateColoredTexture(44, 88, GameConstants.ColorMountainBlue);
            _textures["enemy_basic"] = CreateColoredTexture(44, 88, new Color(255, 120, 120));
            _textures["enemy_elite"] = CreateColoredTexture(44, 88, new Color(255, 170, 110));
            _textures["enemy_boss"] = CreateColoredTexture(52, 104, new Color(255, 90, 130));
            
            // Create character sprite with humanoid shape
            _textures["character"] = CreateCharacterSprite();
            
            // UI elements
            _textures["ui_panel"] = CreateColoredTexture(400, 100, new Color(22, 22, 28, 220));
        }
        
        private Texture2D CreateColoredTexture(int width, int height, Color color)
        {
            var texture = new Texture2D(_graphics, width, height);
            var data = new Color[width * height];
            for (int i = 0; i < data.Length; i++)
            {
                data[i] = color;
            }
            texture.SetData(data);
            return texture;
        }
        
        private Texture2D CreateCharacterSprite()
        {
            int width = 44;
            int height = 88;
            var texture = new Texture2D(_graphics, width, height);
            var data = new Color[width * height];
            
            // Create a simple humanoid shape
            for (int y = 0; y < height; y++)
            {
                for (int x = 0; x < width; x++)
                {
                    int idx = y * width + x;
                    data[idx] = Color.Transparent;
                    
                    // Head (circle-ish)
                    if (y >= 8 && y <= 28 && x >= 16 && x <= 28)
                    {
                        float centerX = 22f;
                        float centerY = 18f;
                        float dist = MathF.Sqrt((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY));
                        if (dist <= 8f) data[idx] = Color.White;
                    }
                    
                    // Body (rectangle)
                    if (y >= 28 && y <= 60 && x >= 18 && x <= 26)
                    {
                        data[idx] = Color.White;
                    }
                    
                    // Arms
                    if (y >= 32 && y <= 48 && ((x >= 12 && x <= 17) || (x >= 27 && x <= 32)))
                    {
                        data[idx] = Color.White;
                    }
                    
                    // Legs
                    if (y >= 60 && y <= 84 && ((x >= 16 && x <= 20) || (x >= 24 && x <= 28)))
                    {
                        data[idx] = Color.White;
                    }
                }
            }
            
            texture.SetData(data);
            return texture;
        }
        
        public Texture2D GetTexture(string name)
        {
            if (_textures.ContainsKey(name))
                return _textures[name];
            
            // Return a default texture if not found
            if (!_textures.ContainsKey("missing"))
            {
                _textures["missing"] = CreateColoredTexture(32, 32, Color.Magenta);
            }
            return _textures["missing"];
        }
        
        public SpriteFont GetFont(string name = "default")
        {
            if (_fonts.ContainsKey(name))
                return _fonts[name];
            return null;
        }
        
        public void Dispose()
        {
            foreach (var texture in _textures.Values)
            {
                texture?.Dispose();
            }
            _textures.Clear();
            _fonts.Clear();
        }
    }
}