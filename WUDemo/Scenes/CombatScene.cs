using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using System;
using WUDemo.Components;
using WUDemo.Core;
using WUDemo.Debug;
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
        private DamageNumberSystem _damageNumberSystem;
        private Camera2D _camera;
        private AssetManager _assets;
        
        private bool _isPausedOnEnd;
        private string _endMessage;
        private float _timeScale = 1f;
        private float _timeScaleRecoverTimer = 0f;
        private string _feedbackMessage = "";
        private float _feedbackTimer = 0f;
        private bool _isPaused = false;
        
        public event Action<bool> OnCombatEnd; // true = victory, false = defeat
        
        public CombatScene(AssetManager assets)
        {
            _assets = assets;
            _combatSystem = new CombatSystem();
            _particleSystem = new ParticleSystem(GameConstants.MaxParticles);
            _damageNumberSystem = new DamageNumberSystem();
            _camera = new Camera2D();
            
            // Wire up combat events
            _combatSystem.OnSpawnParticles += (pos, count, color) => 
                _particleSystem.SpawnHitSparks(pos, count, color);
            _combatSystem.OnCameraShake += shake => _camera.AddShake(shake);
            _combatSystem.OnSlowMotion += TriggerSlowMo;
            _combatSystem.OnShowFeedback += ShowFeedback;
            _combatSystem.OnDamageDealt += (pos, damage, isCritical) => 
                _damageNumberSystem.SpawnDamageNumber(pos, damage, false, isCritical);
        }
        
        public void SetupCombat(Fighter player, MapNode node)
        {
            _player = player;
            _currentNode = node;
            _enemy = EnemyFactory.CreateEnemyForNode(node);
            
            // Initialize sprites if not already done
            if (_player.Sprite == null)
            {
                _player.SetupSprite(_assets.GetTexture("character"));
            }
            if (_enemy.Sprite == null)
            {
                _enemy.SetupSprite(_assets.GetTexture("character"));
            }
            
            // Reset positions
            _player.Position = new Vector2(360, GameConstants.GroundY);
            _player.Velocity = Vector2.Zero;
            _player.IsStunned = false;
            _player.IsBlocking = false;
            _player.WasHitThisSwing = false;
            
            _isPausedOnEnd = false;
            _endMessage = string.Empty;
            _particleSystem.Clear();
            _damageNumberSystem.Clear();
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
            _damageNumberSystem.Clear();
        }
        
        public void Update(GameTime gameTime, KeyboardState kb, KeyboardState prevKb)
        {
            float dtReal = (float)gameTime.ElapsedGameTime.TotalSeconds;
            
            // Toggle debug mode
            if (Pressed(kb, prevKb, Keys.OemTilde))
            {
                CombatDebugger.Instance.IsEnabled = !CombatDebugger.Instance.IsEnabled;
            }
            
            // Toggle pause
            if (Pressed(kb, prevKb, Keys.P))
            {
                _isPaused = !_isPaused;
                CombatDebugger.Instance.LogSystem(_isPaused ? "COMBAT PAUSED" : "COMBAT RESUMED", 
                    _isPaused ? Color.Orange : Color.LightGreen);
            }
            
            // Always update debug system (works while paused)
            CombatDebugger.Instance.Update(dtReal, _isPaused);
            
            // Update feedback timer (always runs)
            if (_feedbackTimer > 0) _feedbackTimer -= dtReal;
            
            // Exit early if paused (but still allow end-of-combat input)
            if (_isPaused && !_isPausedOnEnd)
            {
                return;
            }
            
            // Time scale recovery
            if (_timeScaleRecoverTimer > 0)
            {
                _timeScaleRecoverTimer -= dtReal;
                _timeScale = MathHelper.Lerp(_timeScale, 1f, GameConstants.TimeScaleRecovery);
            }
            
            float dt = dtReal * _timeScale;
            
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
            _combatSystem.UpdatePlayer(_player, kb, prevKb, dt, _enemy);
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
            
            // Update systems (only when not paused)
            if (!_isPaused)
            {
                _camera.Update(dtReal);
                _particleSystem.Update(dt);
                _damageNumberSystem.Update(dt);
            }
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
            _damageNumberSystem.Draw(spriteBatch, _assets.GetFont());
            
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
            
            // Draw pause indicator
            if (_isPaused)
            {
                DrawPauseIndicator(spriteBatch);
            }
            
            // Draw debug information
            CombatDebugger.Instance.Draw(spriteBatch, _assets.GetFont(), _player, _enemy, _isPaused);
            
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
            
            // Calculate body rect for effects and fallback rendering
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
            
            // Invulnerability effect
            if (fighter.IsInvulnerable)
            {
                float pulse = (float)Math.Sin(fighter.AnimationTimer * 20f) * 0.5f + 0.5f;
                for (int i = 1; i <= 3; i++)
                {
                    var glowRect = new Rectangle(
                        bodyRect.X - i * 3,
                        bodyRect.Y - i * 3,
                        bodyRect.Width + i * 6,
                        bodyRect.Height + i * 6
                    );
                    var alpha = (byte)(80 * pulse / i);
                    DrawRect(spriteBatch, glowRect, new Color((byte)100, (byte)200, (byte)255, alpha));
                }
            }
            
            // Draw character using AnimatedSprite if available, fallback to simple rectangle
            if (fighter.Sprite != null)
            {
                var spriteEffect = fighter.Facing > 0 ? SpriteEffects.None : SpriteEffects.FlipHorizontally;
                
                // Draw shadow/outline
                for (int ox = -1; ox <= 1; ox++)
                {
                    for (int oy = -1; oy <= 1; oy++)
                    {
                        if (ox == 0 && oy == 0) continue;
                        var shadowTint = fighter.Sprite.Tint;
                        fighter.Sprite.Tint = new Color(0, 0, 0, 60);
                        fighter.Sprite.Draw(spriteBatch, animatedPos + new Vector2(ox, oy), spriteEffect);
                        fighter.Sprite.Tint = shadowTint;
                    }
                }
                
                // Draw the sprite
                fighter.Sprite.Draw(spriteBatch, animatedPos, spriteEffect);
            }
            else
            {
                // Fallback rectangle rendering if no sprite
                DrawRect(spriteBatch, bodyRect, fighter.ColorBody);
            }
            
            // Weapon indicator with combo effects
            if (fighter.IsHitActive())
            {
                var weaponStart = new Vector2(
                    fighter.Position.X + fighter.Facing * fighter.HalfWidth,
                    fighter.Position.Y - fighter.Height * 0.4f
                );
                var weaponEnd = weaponStart + new Vector2(fighter.Facing * fighter.AttackRange, 0);
                
                Color weaponColor = fighter.ComboCount > 2 ? 
                    new Color(255, 180, 100, 120) : new Color(210, 240, 255, 80);
                int thickness = fighter.ComboCount > 2 ? 3 : 2;
                
                for (int i = -2; i <= 2; i++)
                {
                    DrawLine(spriteBatch, 
                            new Point((int)weaponStart.X, (int)(weaponStart.Y + i)),
                            new Point((int)weaponEnd.X, (int)(weaponEnd.Y + i)),
                            weaponColor, thickness);
                }
                
                // Trail effect for combos
                if (fighter.ComboCount > 1)
                {
                    for (int trail = 1; trail <= fighter.ComboCount; trail++)
                    {
                        var trailStart = weaponStart - new Vector2(fighter.Facing * trail * 15, trail * 3);
                        var trailEnd = weaponEnd - new Vector2(fighter.Facing * trail * 20, trail * 3);
                        var trailAlpha = (byte)(40 / trail);
                        var trailColor = new Color((byte)255, (byte)200, (byte)100, trailAlpha);
                        
                        DrawLine(spriteBatch,
                                new Point((int)trailStart.X, (int)trailStart.Y),
                                new Point((int)trailEnd.X, (int)trailEnd.Y),
                                trailColor, 1);
                    }
                }
            }
            
            // Stun indicator
            if (fighter.IsStunned)
            {
                float stunPulse = (float)Math.Sin(fighter.AnimationTimer * 12f) * 0.5f + 0.5f;
                var stunRect = new Rectangle(bodyRect.X, bodyRect.Y - 18, bodyRect.Width, 12);
                DrawRect(spriteBatch, stunRect, new Color((byte)255, (byte)220, (byte)0, (byte)(120 * stunPulse)));
                
                // Stars around stunned character
                for (int i = 0; i < 3; i++)
                {
                    float angle = fighter.AnimationTimer * 4f + i * 2.1f;
                    var starPos = new Vector2(
                        bodyRect.Center.X + MathF.Cos(angle) * 30,
                        bodyRect.Y - 10 + MathF.Sin(angle) * 15
                    );
                    DrawRect(spriteBatch, 
                            new Rectangle((int)starPos.X - 3, (int)starPos.Y - 3, 6, 6),
                            new Color(255, 255, 100, 180));
                }
            }
            
            // Combo indicator
            if (fighter.ComboCount > 1 && fighter.ComboWindow > 0)
            {
                var comboPos = new Vector2(bodyRect.Center.X - 20, bodyRect.Y - 40);
                DrawText(spriteBatch, $"x{fighter.ComboCount}", (int)comboPos.X, (int)comboPos.Y,
                        new Color(255, 200, 100));
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
            
            DrawText(spriteBatch, "A/D move | W jump | J attack | K block/parry | Space dash | P pause | R restart", 
                    30, 124, new Color(180, 180, 190));
        }
        
        private void DrawBars(SpriteBatch spriteBatch, Fighter fighter, int x, int y, bool mirror = false)
        {
            int width = GameConstants.ViewWidth / 2 - 60;
            int barH = 16;
            int gap = 6;
            
            void DrawBar(float current, float max, Color color, int row, string label)
            {
                float pct = current / max;
                var back = new Rectangle(x, y + row * (barH + gap), width, barH);
                DrawRect(spriteBatch, new Rectangle(back.X - 1, back.Y - 1, back.Width + 2, back.Height + 2), 
                        new Color(60, 60, 70));
                DrawRect(spriteBatch, back, new Color(20, 20, 24));
                
                int w = (int)(width * Math.Clamp(pct, 0f, 1f));
                var fill = new Rectangle(x, y + row * (barH + gap), w, barH);
                
                // Animate bar changes
                if (row == 0 && pct < 0.3f) // Low health pulse
                {
                    float pulse = (float)Math.Sin(_timeScale * 8f) * 0.3f + 0.7f;
                    color = new Color(
                        (byte)(color.R * pulse + 50),
                        (byte)(color.G * pulse),
                        (byte)(color.B * pulse),
                        color.A
                    );
                }
                
                DrawRect(spriteBatch, fill, color);
                
                if (pct > 0.95f)
                {
                    var highlight = new Rectangle(x, y + row * (barH + gap), w, 2);
                    DrawRect(spriteBatch, highlight, Color.Lerp(color, Color.White, 0.6f));
                }
                
                // Bar shine animation
                if (row == 2 && fighter.RageCurrent >= fighter.RageMax * 0.8f)
                {
                    float shine = (float)Math.Sin(_timeScale * 4f) * 0.5f + 0.5f;
                    var shineRect = new Rectangle(
                        x + (int)(w * shine * 0.8f),
                        y + row * (barH + gap),
                        (int)(w * 0.2f),
                        barH
                    );
                    DrawRect(spriteBatch, shineRect, new Color((byte)255, (byte)255, (byte)255, (byte)(40 * shine)));
                }
                
                // Draw numeric values
                string valueText = $"{(int)current}/{(int)max}";
                var font = _assets.GetFont();
                if (font != null)
                {
                    var textSize = font.MeasureString(valueText);
                    int textX = mirror ? x + width - (int)textSize.X - 4 : x + 4;
                    int textY = y + row * (barH + gap) + 1;
                    
                    // Draw text shadow for better readability
                    DrawText(spriteBatch, valueText, textX + 1, textY + 1, new Color(0, 0, 0, 180));
                    DrawText(spriteBatch, valueText, textX, textY, Color.White);
                }
            }
            
            DrawBar(fighter.HealthCurrent, fighter.HealthMax, new Color(231, 76, 60), 0, "HP");
            DrawBar(fighter.PostureCurrent, fighter.PostureMax, new Color(241, 196, 15), 1, "PST");
            DrawBar(fighter.RageCurrent, fighter.RageMax, new Color(142, 68, 173), 2, "RGE");
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
        
        private void DrawPauseIndicator(SpriteBatch spriteBatch)
        {
            // Draw semi-transparent overlay
            var overlay = new Rectangle(0, 0, GameConstants.ViewWidth, GameConstants.ViewHeight);
            DrawRect(spriteBatch, overlay, new Color(0, 0, 0, 100));
            
            // Draw pause text
            var font = _assets.GetFont();
            if (font != null)
            {
                string pauseText = "PAUSED";
                var textSize = font.MeasureString(pauseText);
                var textPos = new Vector2(
                    (GameConstants.ViewWidth - textSize.X) / 2,
                    (GameConstants.ViewHeight - textSize.Y) / 2 - 50
                );
                
                // Draw text with outline
                for (int ox = -2; ox <= 2; ox++)
                {
                    for (int oy = -2; oy <= 2; oy++)
                    {
                        if (ox == 0 && oy == 0) continue;
                        spriteBatch.DrawString(font, pauseText, textPos + new Vector2(ox, oy), Color.Black);
                    }
                }
                spriteBatch.DrawString(font, pauseText, textPos, Color.White);
                
                // Draw instructions
                string instructionText = "Press P to resume | ` for debug | R to restart";
                var instrSize = font.MeasureString(instructionText);
                var instrPos = new Vector2(
                    (GameConstants.ViewWidth - instrSize.X) / 2,
                    textPos.Y + textSize.Y + 20
                );
                spriteBatch.DrawString(font, instructionText, instrPos, Color.LightGray);
            }
        }
        
        private bool Pressed(KeyboardState current, KeyboardState previous, Keys key)
        {
            return current.IsKeyDown(key) && !previous.IsKeyDown(key);
        }
    }
}