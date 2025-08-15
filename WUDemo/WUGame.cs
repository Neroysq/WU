using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using System;
using WUDemo.Components;
using WUDemo.Core;
using WUDemo.Data;
using WUDemo.Entities;
using WUDemo.Scenes;

namespace WUDemo
{
    public class WUGame : Game
    {
        private GraphicsDeviceManager _graphics;
        private SpriteBatch _spriteBatch;
        private AssetManager _assetManager;
        
        // Scenes
        private CombatScene _combatScene;
        private SceneType _currentScene;
        
        // Game state
        private RunState _runState;
        private Fighter _player;
        private int _mapSelectionIdx = 0;
        private RewardOption _reward1, _reward2;
        private string _endMessage = "";
        
        // Input
        private KeyboardState _prevKb;
        
        public WUGame()
        {
            _graphics = new GraphicsDeviceManager(this);
            Content.RootDirectory = "Content";
            IsMouseVisible = true;
            
            _graphics.PreferredBackBufferWidth = GameConstants.ViewWidth;
            _graphics.PreferredBackBufferHeight = GameConstants.ViewHeight;
            _graphics.SynchronizeWithVerticalRetrace = true;
            IsFixedTimeStep = true;
        }
        
        protected override void Initialize()
        {
            // Initialize the DataManager first to load all game data
            DataManager.Initialize();
            
            base.Initialize();
            StartNewRun();
        }
        
        protected override void LoadContent()
        {
            _spriteBatch = new SpriteBatch(GraphicsDevice);
            _assetManager = new AssetManager(Content, GraphicsDevice);
            _assetManager.LoadAssets();
            
            // Initialize scenes
            _combatScene = new CombatScene(_assetManager);
            _combatScene.OnCombatEnd += OnCombatEnd;
            _combatScene.Initialize();
        }
        
        private void StartNewRun()
        {
            _player = EnemyFactory.CreatePlayer();
            _runState = RunState.CreateSimpleThreeTier();
            _currentScene = SceneType.Map;
            _mapSelectionIdx = 0;
            _endMessage = string.Empty;
        }
        
        protected override void Update(GameTime gameTime)
        {
            var kb = Keyboard.GetState();
            
            if (kb.IsKeyDown(Keys.Escape))
            {
                Exit();
                return;
            }
            
            // Reload data files with F5
            if (Pressed(kb, Keys.F5))
            {
                DataManager.ReloadData();
                Console.WriteLine("Reloaded all game data files");
            }
            
            // Global restart
            if (Pressed(kb, Keys.R))
            {
                StartNewRun();
                _prevKb = kb;
                base.Update(gameTime);
                return;
            }
            
            switch (_currentScene)
            {
                case SceneType.Map:
                    UpdateMap(kb);
                    break;
                case SceneType.Combat:
                    _combatScene.Update(gameTime, kb, _prevKb);
                    break;
                case SceneType.Reward:
                    UpdateReward(kb);
                    break;
                case SceneType.GameOver:
                    // Wait for R to restart
                    break;
            }
            
            _prevKb = kb;
            base.Update(gameTime);
        }
        
        private void UpdateMap(KeyboardState kb)
        {
            var nextNodes = _runState.GetAvailableNext();
            if (nextNodes.Count == 0)
            {
                _currentScene = SceneType.GameOver;
                _endMessage = "Run Clear!";
                return;
            }
            
            if (Pressed(kb, Keys.A))
                _mapSelectionIdx = Math.Max(0, _mapSelectionIdx - 1);
            if (Pressed(kb, Keys.D))
                _mapSelectionIdx = Math.Min(nextNodes.Count - 1, _mapSelectionIdx + 1);
            
            if (Pressed(kb, Keys.Enter) || Pressed(kb, Keys.J))
            {
                var chosen = nextNodes[_mapSelectionIdx];
                _runState.AdvanceTo(chosen.Id);
                _mapSelectionIdx = 0;
                
                switch (chosen.Type)
                {
                    case NodeType.Event:
                        // Simple event: heal
                        _player.HealthCurrent = MathF.Min(_player.HealthCurrent + 20, _player.HealthMax);
                        _runState.MarkCurrentNodeCleared();
                        break;
                        
                    case NodeType.Treasure:
                        // Simple treasure: posture boost
                        _player.PostureMax += 10;
                        _player.PostureCurrent = MathF.Min(_player.PostureCurrent + 10, _player.PostureMax);
                        _runState.MarkCurrentNodeCleared();
                        break;
                        
                    default:
                        // Start combat
                        _combatScene.SetupCombat(_player, chosen);
                        _combatScene.OnEnter();
                        _currentScene = SceneType.Combat;
                        break;
                }
            }
        }
        
        private void UpdateReward(KeyboardState kb)
        {
            if (_reward1 == null || _reward2 == null)
            {
                _reward1 = RewardOption.Random();
                _reward2 = RewardOption.Random(exclude: _reward1.Id);
            }
            
            if (Pressed(kb, Keys.D1) || Pressed(kb, Keys.NumPad1))
            {
                _reward1.Apply(_player);
                _reward1 = _reward2 = null;
                _currentScene = SceneType.Map;
            }
            else if (Pressed(kb, Keys.D2) || Pressed(kb, Keys.NumPad2))
            {
                _reward2.Apply(_player);
                _reward1 = _reward2 = null;
                _currentScene = SceneType.Map;
            }
        }
        
        private void OnCombatEnd(bool victory)
        {
            _combatScene.OnExit();
            
            if (victory)
            {
                _runState.MarkCurrentNodeCleared();
                
                if (_runState.GetCurrentNode().Type == NodeType.Boss)
                {
                    _currentScene = SceneType.GameOver;
                    _endMessage = "Victory! Run Complete!";
                }
                else
                {
                    _currentScene = SceneType.Reward;
                }
            }
            else
            {
                _currentScene = SceneType.GameOver;
                _endMessage = "Defeat...";
            }
        }
        
        protected override void Draw(GameTime gameTime)
        {
            GraphicsDevice.Clear(GameConstants.ColorInkBlack);
            
            switch (_currentScene)
            {
                case SceneType.Map:
                    DrawMap();
                    break;
                case SceneType.Combat:
                    _combatScene.Draw(_spriteBatch);
                    break;
                case SceneType.Reward:
                    DrawReward();
                    break;
                case SceneType.GameOver:
                    DrawGameOver();
                    break;
            }
            
            base.Draw(gameTime);
        }
        
        private void DrawMap()
        {
            _spriteBatch.Begin(samplerState: SamplerState.PointClamp);
            
            // Background
            DrawRect(new Rectangle(0, 0, GameConstants.ViewWidth, GameConstants.ViewHeight), 
                    new Color(10, 10, 14));
            DrawRect(new Rectangle(0, 0, GameConstants.ViewWidth, 80), 
                    new Color(18, 18, 24));
            DrawRect(new Rectangle(0, GameConstants.ViewHeight - 100, GameConstants.ViewWidth, 100), 
                    new Color(16, 16, 22));
            
            var nextNodes = _runState.GetAvailableNext();
            int tiers = _runState.MaxTier + 1;
            int top = 120, bottom = GameConstants.ViewHeight - 140;
            int tierHeight = (bottom - top) / Math.Max(1, tiers - 1);
            
            // Draw connections
            foreach (var node in _runState.Nodes)
            {
                foreach (var toId in node.Next)
                {
                    var a = GetMapNodePosition(node, tiers, top, tierHeight);
                    var b = GetMapNodePosition(_runState.GetNode(toId), tiers, top, tierHeight);
                    DrawLine(a, b, new Color(60, 60, 72), 3);
                }
            }
            
            // Draw nodes
            foreach (var node in _runState.Nodes)
            {
                var pos = GetMapNodePosition(node, tiers, top, tierHeight);
                int size = 18;
                var rect = new Rectangle(pos.X - size, pos.Y - size, size * 2, size * 2);
                
                Color nodeColor = node.Type switch
                {
                    NodeType.Battle => new Color(90, 160, 255),
                    NodeType.Elite => new Color(255, 140, 90),
                    NodeType.Treasure => new Color(255, 215, 120),
                    NodeType.Event => new Color(180, 180, 210),
                    NodeType.Boss => new Color(255, 80, 110),
                    _ => Color.White
                };
                
                if (node.Cleared) nodeColor *= 0.5f;
                
                DrawRect(rect, nodeColor);
                
                // Highlight selection
                if (nextNodes.Contains(node))
                {
                    int idx = nextNodes.IndexOf(node);
                    if (idx == _mapSelectionIdx)
                    {
                        DrawRect(new Rectangle(rect.X - 4, rect.Y - 4, rect.Width + 8, rect.Height + 8), 
                                new Color(255, 255, 255, 40));
                    }
                }
            }
            
            DrawText("Map: A/D select | Enter to travel | R restart run", 
                    30, 34, new Color(180, 180, 190));
            
            _spriteBatch.End();
        }
        
        private void DrawReward()
        {
            _spriteBatch.Begin(samplerState: SamplerState.PointClamp);
            
            // Background
            DrawRect(new Rectangle(0, 0, GameConstants.ViewWidth, GameConstants.ViewHeight), 
                    new Color(10, 10, 14));
            
            int w = GameConstants.ViewWidth - 300;
            int h = 200;
            var rect = new Rectangle((GameConstants.ViewWidth - w) / 2, (GameConstants.ViewHeight - h) / 2 - 40, w, h);
            DrawRect(rect, new Color(0, 0, 0, 140));
            DrawText("Choose a reward: 1 or 2", rect.X + 28, rect.Y + 28, Color.White);
            
            int boxW = (w - 60) / 2;
            int boxH = 80;
            var box1 = new Rectangle(rect.X + 20, rect.Y + 80, boxW, boxH);
            var box2 = new Rectangle(rect.X + 40 + boxW, rect.Y + 80, boxW, boxH);
            DrawRect(box1, new Color(30, 30, 36));
            DrawRect(box2, new Color(30, 30, 36));
            DrawText(_reward1?.Label ?? "...", box1.X + 16, box1.Y + 16, new Color(200, 220, 255));
            DrawText(_reward2?.Label ?? "...", box2.X + 16, box2.Y + 16, new Color(200, 220, 255));
            
            _spriteBatch.End();
        }
        
        private void DrawGameOver()
        {
            _spriteBatch.Begin(samplerState: SamplerState.PointClamp);
            
            DrawRect(new Rectangle(0, 0, GameConstants.ViewWidth, GameConstants.ViewHeight), 
                    new Color(10, 10, 14));
            
            int w = 420;
            int h = 120;
            var rect = new Rectangle((GameConstants.ViewWidth - w) / 2, (GameConstants.ViewHeight - h) / 2 - 24, w, h);
            DrawRect(rect, new Color(0, 0, 0, 140));
            DrawText(_endMessage, rect.X + 28, rect.Y + 28, Color.White);
            DrawText("R: restart run", rect.X + 28, rect.Y + 60, new Color(220, 220, 220, 180));
            
            _spriteBatch.End();
        }
        
        private Point GetMapNodePosition(MapNode node, int tiers, int top, int tierHeight)
        {
            int y = top + node.Tier * tierHeight;
            int countInTier = _runState.CountInTier(node.Tier);
            int idxInTier = _runState.IndexInTier(node);
            int left = 140, right = GameConstants.ViewWidth - 140;
            int x = countInTier <= 1 ? (left + right) / 2 : 
                    left + idxInTier * (right - left) / (countInTier - 1);
            return new Point(x, y);
        }
        
        private void DrawRect(Rectangle rect, Color color)
        {
            _spriteBatch.Draw(_assetManager.Pixel, rect, color);
        }
        
        private void DrawLine(Point a, Point b, Color color, int thickness)
        {
            var dx = b.X - a.X;
            var dy = b.Y - a.Y;
            var len = (float)Math.Sqrt(dx * dx + dy * dy);
            float angle = (float)Math.Atan2(dy, dx);
            var rect = new Rectangle(a.X, a.Y, (int)len, thickness);
            _spriteBatch.Draw(_assetManager.Pixel, rect, null, color, angle, 
                            Vector2.Zero, SpriteEffects.None, 0f);
        }
        
        private void DrawText(string text, int x, int y, Color color)
        {
            var font = _assetManager.GetFont();
            if (font != null)
            {
                _spriteBatch.DrawString(font, text, new Vector2(x, y), color);
            }
        }
        
        private bool Pressed(KeyboardState current, Keys key)
        {
            return current.IsKeyDown(key) && !_prevKb.IsKeyDown(key);
        }
        
        protected override void UnloadContent()
        {
            _assetManager?.Dispose();
            base.UnloadContent();
        }
    }
}