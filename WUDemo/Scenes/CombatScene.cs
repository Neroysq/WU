using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using System;
using WUDemo.Components;
using WUDemo.Core;
using WUDemo.Entities;
using WUDemo.Systems;

namespace WUDemo.Scenes
{
    public class CombatScene : IScene
    {
        private Fighter _player;
        private Fighter _enemy;
        private MapNode _currentNode;
        private CombatSystem _combatSystem;
        private ParticleSystem _particleSystem;
        private Camera2D _camera;
        private AssetManager _assets;
        
        private bool _isPausedOnEnd;
        private string _endMessage;
        private float _timeScale = 1f;
        private float _timeScaleRecoverTimer = 0f;
        private string _feedbackMessage = "";
        private float _feedbackTimer = 0f;
        
        public event Action<bool> OnCombatEnd; // true = victory, false = defeat
        
        public CombatScene(AssetManager assets)
        {
            _assets = assets;
            _combatSystem = new CombatSystem();
            _particleSystem = new ParticleSystem(GameConstants.MaxParticles);
            _camera = new Camera2D();
            
            // Wire up combat events
            _combatSystem.OnSpawnParticles += (pos, count, color) => 
                _particleSystem.SpawnHitSparks(pos, count, color);
            _combatSystem.OnCameraShake += shake => _camera.AddShake(shake);
            _combatSystem.OnSlowMotion += TriggerSlowMo;
            _combatSystem.OnShowFeedback += ShowFeedback;
        }
        
        public void SetupCombat(Fighter player, MapNode node)
        {
            _player = player;
            _currentNode = node;
            _enemy = EnemyFactory.CreateEnemyForNode(node);
            
            // Reset positions
            _player.Position = new Vector2(360, GameConstants.GroundY);
            _player.Velocity = Vector2.Zero;
            _player.IsStunned = false;
            _player.IsBlocking = false;
            _player.WasHitThisSwing = false;
            
            _isPausedOnEnd = false;
            _endMessage = string.Empty;
            _particleSystem.Clear();
            _camera.Reset();
        }
        
        public void Initialize()
        {
            // Initialization handled in SetupCombat
        }
        
        public void OnEnter()
        {
            _timeScale = 1f;
            _timeScaleRecoverTimer = 0f;
        }
        
        public void OnExit()
        {
            _particleSystem.Clear();
        }
        
        public void Update(GameTime gameTime, KeyboardState kb, KeyboardState prevKb)
        {
            float dtReal = (float)gameTime.ElapsedGameTime.TotalSeconds;
            
            // Time scale recovery
            if (_timeScaleRecoverTimer > 0)
            {
                _timeScaleRecoverTimer -= dtReal;
                _timeScale = MathHelper.Lerp(_timeScale, 1f, GameConstants.TimeScaleRecovery);
            }
            
            float dt = dtReal * _timeScale;
            
            // Update feedback timer
            if (_feedbackTimer > 0) _feedbackTimer -= dtReal;
            
            if (_isPausedOnEnd)
            {
                if (Pressed(kb, prevKb, Keys.Enter) || Pressed(kb, prevKb, Keys.J))
                {
                    bool victory = _player.HealthCurrent > 0;
                    OnCombatEnd?.Invoke(victory);
                }
                return;
            }
            
            // Update facing
            _combatSystem.UpdateFacing(_player, _enemy);
            
            // Update fighters
            _combatSystem.UpdatePlayer(_player, kb, prevKb, dt);
            _combatSystem.UpdateAI(_enemy, _player, dt);
            
            // Resolve combat
            _combatSystem.ResolveHits(_player, _enemy);
            _combatSystem.ResolveHits(_enemy, _player);
            
            // World bounds
            _combatSystem.ClampWorldBounds(_player);
            _combatSystem.ClampWorldBounds(_enemy);
            
            // Check end conditions
            if (_player.HealthCurrent <= 0)
            {
                _isPausedOnEnd = true;
                _endMessage = "Defeat (Enter: continue)";
            }
            else if (_enemy.HealthCurrent <= 0)
            {
                _isPausedOnEnd = true;
                _endMessage = _currentNode.Type == NodeType.Boss ? 
                    "Boss Defeated (Enter)" : "Victory (Enter)";
            }
            
            // Update systems
            _camera.Update(dtReal);
            _particleSystem.Update(dt);
        }
        
        public void Draw(SpriteBatch spriteBatch)
        {
            // Draw with camera transform
            spriteBatch.Begin(samplerState: SamplerState.PointClamp, 
                             transformMatrix: _camera.GetTransform());
            
            DrawArena(spriteBatch);
            DrawFighter(spriteBatch, _player);
            DrawFighter(spriteBatch, _enemy);
            _particleSystem.Draw(spriteBatch, _assets.Pixel);
            
            spriteBatch.End();
            
            // Draw UI without camera transform
            spriteBatch.Begin(samplerState: SamplerState.PointClamp);
            
            DrawHUD(spriteBatch);
            DrawFeedback(spriteBatch);
            
            if (_isPausedOnEnd)
            {
                DrawEndMessage(spriteBatch);
            }
            
            DrawEffects(spriteBatch);
            
            spriteBatch.End();
        }
        
        private void DrawArena(SpriteBatch spriteBatch)
        {
            // Background layers
            DrawRect(spriteBatch, new Rectangle(0, 0, GameConstants.ViewWidth, (int)GameConstants.GroundY + 200), 
                    new Color(16, 12, 28));
            
            // Mountain layers with parallax
            DrawMountainLayer(spriteBatch, 40, 0.010f, (int)GameConstants.GroundY - 140, new Color(24, 20, 50));
            DrawMountainLayer(spriteBatch, 28, 0.014f, (int)GameConstants.GroundY - 100, new Color(30, 22, 60));
            DrawMountainLayer(spriteBatch, 16, 0.020f, (int)GameConstants.GroundY - 70, new Color(40, 26, 74));
            
            // Ground
            DrawRect(spriteBatch, new Rectangle(0, (int)GameConstants.GroundY + 40, GameConstants.ViewWidth, 6), 
                    new Color(60, 40, 88));
            DrawRect(spriteBatch, new Rectangle(0, (int)GameConstants.GroundY + 46, GameConstants.ViewWidth, 200), 
                    new Color(10, 8, 18));
        }
        
        private void DrawMountainLayer(SpriteBatch spriteBatch, int amp, float freq, int baseY, Color color)
        {
            for (int x = 0; x < GameConstants.ViewWidth; x += 6)
            {
                float y = baseY + (float)Math.Sin(x * freq) * amp;
                DrawRect(spriteBatch, new Rectangle(x, (int)y, 6, (int)(GameConstants.GroundY + 60 - y)), color);
            }
        }
        
        private void DrawFighter(SpriteBatch spriteBatch, Fighter fighter)
        {
            var animatedPos = fighter.Position + fighter.AnimationOffset;
            var bodyRect = new Rectangle(
                (int)(animatedPos.X - fighter.HalfWidth),
                (int)(animatedPos.Y - fighter.Height),
                (int)(fighter.HalfWidth * 2),
                (int)fighter.Height
            );
            
            // Telegraph effect
            if (fighter.IsTelegraphing)
            {
                float intensity = 0.5f + 0.5f * (float)Math.Abs(Math.Sin(fighter.TelegraphTimer * 15));
                var flash = Color.Lerp(Color.Transparent, new Color(255, 50, 50), intensity);
                
                for (int size = 1; size <= 4; size++)
                {
                    var outlineRect = new Rectangle(
                        bodyRect.X - size * 2,
                        bodyRect.Y - size * 2,
                        bodyRect.Width + size * 4,
                        bodyRect.Height + size * 4
                    );
                    var alpha = (byte)(flash.A / (size * 2));
                    DrawRect(spriteBatch, outlineRect, new Color((byte)255, (byte)50, (byte)50, alpha));
                }
            }
            
            // Draw character sprite
            var sprite = _assets.GetTexture("character");
            var spriteEffect = fighter.Facing > 0 ? SpriteEffects.None : SpriteEffects.FlipHorizontally;
            var spriteColor = fighter.ColorBody;
            
            // Animation color effects
            if (fighter.CurrentAnimation == AnimationState.Attacking)
                spriteColor = Color.Lerp(spriteColor, Color.Yellow, 0.3f);
            else if (fighter.CurrentAnimation == AnimationState.Blocking)
                spriteColor = Color.Lerp(spriteColor, Color.Cyan, 0.2f);
            else if (fighter.CurrentAnimation == AnimationState.HitReaction)
                spriteColor = Color.Lerp(spriteColor, Color.Red, 0.4f);
            
            // Outline glow
            for (int ox = -1; ox <= 1; ox++)
            {
                for (int oy = -1; oy <= 1; oy++)
                {
                    if (ox == 0 && oy == 0) continue;
                    var glowRect = new Rectangle(bodyRect.X + ox, bodyRect.Y + oy, bodyRect.Width, bodyRect.Height);
                    spriteBatch.Draw(sprite, glowRect, null, new Color((byte)0, (byte)0, (byte)0, (byte)60), 
                                   0f, Vector2.Zero, spriteEffect, 0f);
                }
            }
            
            spriteBatch.Draw(sprite, bodyRect, null, spriteColor, 0f, Vector2.Zero, spriteEffect, 0f);
            
            // Weapon indicator
            if (fighter.IsHitActive())
            {
                var weaponStart = new Vector2(
                    fighter.Position.X + fighter.Facing * fighter.HalfWidth,
                    fighter.Position.Y - fighter.Height * 0.4f
                );
                var weaponEnd = weaponStart + new Vector2(fighter.Facing * fighter.AttackRange, 0);
                
                for (int i = -2; i <= 2; i++)
                {
                    DrawLine(spriteBatch, 
                            new Point((int)weaponStart.X, (int)(weaponStart.Y + i)),
                            new Point((int)weaponEnd.X, (int)(weaponEnd.Y + i)),
                            new Color(210, 240, 255, 80), 2);
                }
            }
            
            // Stun indicator
            if (fighter.IsStunned)
            {
                var stunRect = new Rectangle(bodyRect.X, bodyRect.Y - 18, bodyRect.Width, 12);
                DrawRect(spriteBatch, stunRect, new Color(255, 220, 0, 120));
            }
        }
        
        private void DrawHUD(SpriteBatch spriteBatch)
        {
            var leftPanel = new Rectangle(20, 20, GameConstants.ViewWidth / 2 - 40, 92);
            var rightPanel = new Rectangle(GameConstants.ViewWidth / 2 + 20, 20, GameConstants.ViewWidth / 2 - 40, 92);
            
            DrawRect(spriteBatch, leftPanel, new Color(22, 22, 28, 220));
            DrawRect(spriteBatch, rightPanel, new Color(22, 22, 28, 220));
            
            DrawBars(spriteBatch, _player, 30, 34);
            DrawBars(spriteBatch, _enemy, GameConstants.ViewWidth / 2 + 30, 34, true);
            
            DrawText(spriteBatch, "A/D move | J attack | K block/parry | Space dash | R restart", 
                    30, 124, new Color(180, 180, 190));
        }
        
        private void DrawBars(SpriteBatch spriteBatch, Fighter fighter, int x, int y, bool mirror = false)
        {
            int width = GameConstants.ViewWidth / 2 - 60;
            int barH = 16;
            int gap = 6;
            
            void DrawBar(float pct, Color color, int row, string label)
            {
                var back = new Rectangle(x, y + row * (barH + gap), width, barH);
                DrawRect(spriteBatch, new Rectangle(back.X - 1, back.Y - 1, back.Width + 2, back.Height + 2), 
                        new Color(60, 60, 70));
                DrawRect(spriteBatch, back, new Color(20, 20, 24));
                
                int w = (int)(width * Math.Clamp(pct, 0f, 1f));
                var fill = new Rectangle(x, y + row * (barH + gap), w, barH);
                DrawRect(spriteBatch, fill, color);
                
                if (pct > 0.95f)
                {
                    var highlight = new Rectangle(x, y + row * (barH + gap), w, 2);
                    DrawRect(spriteBatch, highlight, Color.Lerp(color, Color.White, 0.6f));
                }
            }
            
            DrawBar(fighter.HealthCurrent / fighter.HealthMax, new Color(231, 76, 60), 0, "HP");
            DrawBar(fighter.PostureCurrent / fighter.PostureMax, new Color(241, 196, 15), 1, "PST");
            DrawBar(fighter.RageCurrent / fighter.RageMax, new Color(142, 68, 173), 2, "RGE");
        }
        
        private void DrawFeedback(SpriteBatch spriteBatch)
        {
            if (_feedbackTimer > 0)
            {
                var alpha = (byte)MathHelper.Clamp(_feedbackTimer * 255f, 0, 255);
                var color = new Color((byte)255, (byte)255, (byte)100, alpha);
                var pos = new Vector2(GameConstants.ViewWidth / 2 - 50, 200);
                DrawText(spriteBatch, _feedbackMessage, (int)pos.X, (int)pos.Y, color);
            }
        }
        
        private void DrawEndMessage(SpriteBatch spriteBatch)
        {
            int w = 420;
            int h = 120;
            var rect = new Rectangle((GameConstants.ViewWidth - w) / 2, (GameConstants.ViewHeight - h) / 2 - 24, w, h);
            DrawRect(spriteBatch, rect, new Color(0, 0, 0, 140));
            DrawText(spriteBatch, _endMessage, rect.X + 28, rect.Y + 28, Color.White);
        }
        
        private void DrawEffects(SpriteBatch spriteBatch)
        {
            // Vignette
            int border = 30;
            var col = new Color(0, 0, 0, 120);
            DrawRect(spriteBatch, new Rectangle(0, 0, GameConstants.ViewWidth, border), col);
            DrawRect(spriteBatch, new Rectangle(0, GameConstants.ViewHeight - border, GameConstants.ViewWidth, border), col);
            DrawRect(spriteBatch, new Rectangle(0, 0, border, GameConstants.ViewHeight), col);
            DrawRect(spriteBatch, new Rectangle(GameConstants.ViewWidth - border, 0, border, GameConstants.ViewHeight), col);
        }
        
        private void TriggerSlowMo(float factor, float duration)
        {
            _timeScale = MathHelper.Clamp(factor, 0.3f, 1f);
            _timeScaleRecoverTimer = Math.Max(_timeScaleRecoverTimer, duration);
        }
        
        private void ShowFeedback(string message, float duration)
        {
            _feedbackMessage = message;
            _feedbackTimer = duration;
        }
        
        private void DrawRect(SpriteBatch spriteBatch, Rectangle rect, Color color)
        {
            spriteBatch.Draw(_assets.Pixel, rect, color);
        }
        
        private void DrawLine(SpriteBatch spriteBatch, Point a, Point b, Color color, int thickness)
        {
            var dx = b.X - a.X;
            var dy = b.Y - a.Y;
            var len = (float)Math.Sqrt(dx * dx + dy * dy);
            float angle = (float)Math.Atan2(dy, dx);
            var rect = new Rectangle(a.X, a.Y, (int)len, thickness);
            spriteBatch.Draw(_assets.Pixel, rect, null, color, angle, Vector2.Zero, SpriteEffects.None, 0f);
        }
        
        private void DrawText(SpriteBatch spriteBatch, string text, int x, int y, Color color)
        {
            var font = _assets.GetFont();
            if (font != null)
            {
                spriteBatch.DrawString(font, text, new Vector2(x, y), color);
            }
        }
        
        private bool Pressed(KeyboardState current, KeyboardState previous, Keys key)
        {
            return current.IsKeyDown(key) && !previous.IsKeyDown(key);
        }
    }
}