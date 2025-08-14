using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using System;
using System.Collections.Generic;

namespace WUDemo;

public class Game1 : Game
{
    private GraphicsDeviceManager _graphics;
    private SpriteBatch _spriteBatch;

    // Render helpers
    private Texture2D _pixel;
    private SpriteFont _defaultFont;
    private Texture2D _characterSprite;
    
    // Audio feedback (visual for now)
    private string _lastFeedbackMessage = "";
    private float _feedbackTimer = 0f;

    // World
    private const int ViewWidth = 1280;
    private const int ViewHeight = 720;
    private const float GroundY = 580f;

    // Game flow
    private GameMode _mode = GameMode.Map;
    private RunState _run;
    private int _mapSelectionIdx = 0; // selection across available next nodes
    private bool _isBossFight = false;

    // Players
    private Fighter _player;
    private Fighter _enemy;

    // Input
    private KeyboardState _prevKb;

    // Game state
    private bool _isPausedOnEnd;
    private string _endMessage = string.Empty;

    // Stylization / FX
    private Camera2D _camera = new Camera2D();
    private float _timeScale = 1f;
    private float _timeScaleRecoverTimer = 0f;
    private readonly Random _rng = new Random();
    private readonly List<Particle> _particles = new List<Particle>();

    public Game1()
    {
        _graphics = new GraphicsDeviceManager(this);
        Content.RootDirectory = "Content";
        IsMouseVisible = true;

        _graphics.PreferredBackBufferWidth = ViewWidth;
        _graphics.PreferredBackBufferHeight = ViewHeight;
        _graphics.SynchronizeWithVerticalRetrace = true;
        IsFixedTimeStep = true; // 60 FPS
    }

    protected override void Initialize()
    {
        base.Initialize();

        StartNewRun();
    }

    private void StartNewRun()
    {
        _player = new Fighter
        {
            Name = "Player",
            Position = new Vector2(360, GroundY),
            Facing = 1,
            ColorBody = new Color(110, 185, 255),
            ColorAccent = new Color(60, 120, 210),
            Controls = FighterControls.PlayerOne(),
        };

        _run = RunState.CreateSimpleThreeTier();
        _mode = GameMode.Map;
        _mapSelectionIdx = 0;
        _isPausedOnEnd = false;
        _endMessage = string.Empty;
    }

    private void SetupCombatForNode(MapNode node)
    {
        _enemy = EnemyFactory.CreateEnemyForNode(node);
        _player.Position = new Vector2(360, GroundY);
        _player.Velocity = Vector2.Zero;
        _player.IsStunned = false;
        _player.IsBlocking = false;
        _player.WasHitThisSwing = false;

        _isPausedOnEnd = false;
        _endMessage = string.Empty;
        _isBossFight = node.Type == NodeType.Boss;
        _mode = GameMode.Combat;
    }

    protected override void LoadContent()
    {
        _spriteBatch = new SpriteBatch(GraphicsDevice);
        _pixel = new Texture2D(GraphicsDevice, 1, 1);
        _pixel.SetData(new[] { Color.White });
        _defaultFont = Content.Load<SpriteFont>("DefaultFont");
        
        // Create simple character sprite
        CreateCharacterSprite();
    }
    
    private void CreateCharacterSprite()
    {
        int width = 44;
        int height = 88;
        _characterSprite = new Texture2D(GraphicsDevice, width, height);
        
        Color[] data = new Color[width * height];
        
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
        
        _characterSprite.SetData(data);
    }

    protected override void Update(GameTime gameTime)
    {
        var kb = Keyboard.GetState();
        if (kb.IsKeyDown(Keys.Escape))
        {
            Exit();
            return;
        }

        float dtReal = (float)gameTime.ElapsedGameTime.TotalSeconds;
        if (_timeScaleRecoverTimer > 0)
        {
            _timeScaleRecoverTimer -= dtReal;
            _timeScale = MathHelper.Lerp(_timeScale, 1f, 0.08f);
        }
        float dt = dtReal * _timeScale;

        // Global: restart run
        if (Pressed(kb, Keys.R))
        {
            StartNewRun();
            _prevKb = kb;
            base.Update(gameTime);
            return;
        }

        switch (_mode)
        {
            case GameMode.Map:
                UpdateMap(kb, dt);
                break;
            case GameMode.Combat:
                UpdateCombat(kb, dt);
                break;
            case GameMode.Reward:
                UpdateReward(kb, dt);
                break;
            case GameMode.End:
                // Wait for R (handled above)
                break;
        }

        if (_mode == GameMode.Combat)
        {
            _camera.Update(dtReal);
            UpdateParticles(dt);
        }
        
        // Update feedback timer
        if (_feedbackTimer > 0) _feedbackTimer -= dtReal;

        _prevKb = kb;
        base.Update(gameTime);
    }

    private void UpdateCombat(KeyboardState kb, float dt)
    {
        if (_isPausedOnEnd)
        {
            // After combat finishes, go to Reward/End on confirm
            if (Pressed(kb, Keys.Enter) || Pressed(kb, Keys.J))
            {
                if (_player.HealthCurrent <= 0)
                {
                    _mode = GameMode.End;
                }
                else
                {
                    if (_isBossFight)
                    {
                        _mode = GameMode.End;
                        _endMessage = "Run Clear";
                    }
                    else
                    {
                        _mode = GameMode.Reward;
                    }
                }
            }
            return;
        }

        // Determine facing based on relative x
        _player.Facing = _player.Position.X <= _enemy.Position.X ? 1 : -1;
        _enemy.Facing = -_player.Facing;

        // Update fighters
        UpdatePlayer(_player, kb, dt);
        UpdateEnemyAI(_enemy, _player, dt);

        // Resolve combat interactions
        ResolveHits(_player, _enemy, dt);
        ResolveHits(_enemy, _player, dt);

        // Clamp world and handle end
        _player.Position.X = Math.Clamp(_player.Position.X, 80, ViewWidth - 80);
        _enemy.Position.X = Math.Clamp(_enemy.Position.X, 80, ViewWidth - 80);

        if (_player.HealthCurrent <= 0)
        {
            _isPausedOnEnd = true;
            _endMessage = "Defeat (Enter: continue)";
        }
        else if (_enemy.HealthCurrent <= 0)
        {
            _isPausedOnEnd = true;
            _endMessage = _isBossFight ? "Boss Defeated (Enter)" : "Victory (Enter)";
            _run.MarkCurrentNodeCleared();
        }
    }

    private void UpdateMap(KeyboardState kb, float dt)
    {
        // Compute available next nodes from current
        var next = _run.GetAvailableNext();
        if (next.Count == 0)
        {
            // At boss? If run finished, go to end
            _mode = GameMode.End;
            _endMessage = "Run Clear";
            return;
        }

        if (Pressed(kb, Keys.Left)) _mapSelectionIdx = Math.Max(0, _mapSelectionIdx - 1);
        if (Pressed(kb, Keys.Right)) _mapSelectionIdx = Math.Min(next.Count - 1, _mapSelectionIdx + 1);

        if (Pressed(kb, Keys.Enter) || Pressed(kb, Keys.J))
        {
            var chosen = next[_mapSelectionIdx];
            _run.AdvanceTo(chosen.Id);
            _mapSelectionIdx = 0;

            if (chosen.Type == NodeType.Event)
            {
                // Simple event: heal 20
                _player.HealthCurrent = MathF.Min(_player.HealthCurrent + 20, _player.HealthMax);
                _run.MarkCurrentNodeCleared();
            }
            else if (chosen.Type == NodeType.Treasure)
            {
                // Simple treasure: +10 posture max
                _player.PostureMax += 10;
                _player.PostureCurrent = MathF.Min(_player.PostureCurrent + 10, _player.PostureMax);
                _run.MarkCurrentNodeCleared();
            }
            else
            {
                SetupCombatForNode(chosen);
            }
        }
    }

    // Reward selection after non-boss fights
    private RewardOption _reward1, _reward2;
    private void UpdateReward(KeyboardState kb, float dt)
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
            _mode = GameMode.Map;
        }
        else if (Pressed(kb, Keys.D2) || Pressed(kb, Keys.NumPad2))
        {
            _reward2.Apply(_player);
            _reward1 = _reward2 = null;
            _mode = GameMode.Map;
        }
    }

    private void UpdatePlayer(Fighter f, KeyboardState kb, float dt)
    {
        // Movement
        float move = 0f;
        if (kb.IsKeyDown(f.Controls.Left)) move -= 1f;
        if (kb.IsKeyDown(f.Controls.Right)) move += 1f;
        bool isTryingToMove = Math.Abs(move) > 0.01f;

        float targetSpeed = isTryingToMove ? move * f.MoveSpeed : 0f;
        f.Velocity.X = MathHelper.Lerp(f.Velocity.X, targetSpeed, 0.25f);
        
        // Update movement animation
        if (isTryingToMove && f.CurrentAnimation == AnimationState.Idle)
        {
            f.CurrentAnimation = AnimationState.Walking;
            f.AnimationTimer = 0f;
        }

        // Dash
        if (Pressed(kb, f.Controls.Dash) && f.CanDash())
        {
            f.StartDash();
            // Spawn dash particles
            SpawnHitSparks(f.Position, 8, new Color(200, 200, 255));
            AddShake(3f);
        }

        // Attack
        if (Pressed(kb, f.Controls.Attack) && f.CanAttack())
        {
            f.StartAttack();
            // Spawn attack particles at weapon position
            var attackPos = new Vector2(
                f.Position.X + f.Facing * f.HalfWidth,
                f.Position.Y - f.Height * 0.4f
            );
            SpawnHitSparks(attackPos, 6, new Color(255, 255, 200));
            AddShake(2f);
        }

        // Block/Parry
        f.IsBlocking = kb.IsKeyDown(f.Controls.Block);
        if (Pressed(kb, f.Controls.Block)) 
        {
            f.TriggerParryWindow();
            f.CurrentAnimation = AnimationState.Blocking;
            f.AnimationTimer = 0f;
        }
        else if (f.IsBlocking && f.CurrentAnimation == AnimationState.Idle)
        {
            f.CurrentAnimation = AnimationState.Blocking;
            f.AnimationTimer = 0f;
        }

        f.UpdateTimers(dt);
        f.Position += f.Velocity * dt;

        // Keep on ground plane
        f.Position.Y = GroundY;
    }

    private void UpdateEnemyAI(Fighter ai, Fighter target, float dt)
    {
        if (!ai.IsAI)
        {
            // Allow keyboard control if desired later
            return;
        }

        ai.UpdateTimers(dt);

        // Simple approach behavior
        float distance = target.Position.X - ai.Position.X;
        float abs = Math.Abs(distance);
        float direction = Math.Sign(distance);

        if (ai.IsInRecovery() || ai.IsStunned)
        {
            ai.Velocity.X = MathHelper.Lerp(ai.Velocity.X, 0, 0.2f);
        }
        else
        {
            if (abs > ai.AttackRange * 0.85f)
            {
                ai.Velocity.X = MathHelper.Lerp(ai.Velocity.X, direction * ai.MoveSpeed * 0.6f, 0.2f);
            }
            else
            {
                ai.Velocity.X = MathHelper.Lerp(ai.Velocity.X, 0, 0.3f);
                if (ai.CanAttack()) ai.StartTelegraph();
            }
        }

        // Attack sequence after telegraph
        if (ai.IsTelegraphing && ai.TelegraphTimer <= 0)
        {
            ai.StartAttack();
        }

        ai.Position += ai.Velocity * dt;
        ai.Position.Y = GroundY;
    }

    private void ResolveHits(Fighter attacker, Fighter defender, float dt)
    {
        if (!attacker.IsHitActive()) return;

        // Simple hitbox check: within horizontal range and roughly on same y
        float front = attacker.Position.X + attacker.Facing * attacker.AttackRange;
        bool inRange = Math.Abs(defender.Position.X - attacker.Position.X) <= attacker.AttackRange + defender.HalfWidth;
        bool facingCorrect = Math.Sign(defender.Position.X - attacker.Position.X) == attacker.Facing;

        if (inRange && facingCorrect && !defender.WasHitThisSwing)
        {
            defender.WasHitThisSwing = true;

            bool parried = defender.ConsumeParryIfActive();

            if (parried)
            {
                // Defender parries: heavy posture damage to attacker, small rage to defender
                attacker.ApplyPostureDamage(55);
                attacker.ApplyStun(0.6f);
                defender.GainRage(12);
                AddShake(12f);
                
                // Special parry effect - ring of sparkles
                var parryPos = defender.Position + new Vector2(defender.Facing * -6, -defender.Height + 24);
                for (int i = 0; i < 24; i++)
                {
                    float angle = (i / 24f) * MathF.PI * 2f;
                    var sparkPos = parryPos + new Vector2(MathF.Cos(angle), MathF.Sin(angle)) * 30f;
                    SpawnHitSparks(sparkPos, 2, new Color(255, 230, 90));
                }
                
                TriggerSlowMo(0.55f, 0.30f);
                ShowFeedback("PARRY!", 0.8f);
                return;
            }

            float hpDamage = attacker.AttackDamage;
            float postureDamage = attacker.AttackPostureDamage;

            if (defender.IsBlocking)
            {
                // Reduce HP damage, increase posture damage
                hpDamage *= 0.2f;
                postureDamage *= 1.6f;
                defender.GainRage(6);
                ShowFeedback("BLOCKED", 0.5f);
            }
            else
            {
                ShowFeedback("HIT", 0.3f);
            }

            bool defenderWasStunned = defender.IsStunned;

            defender.HealthCurrent -= hpDamage;
            defender.ApplyPostureDamage(postureDamage);

            // Rage: both sides gain some
            attacker.GainRage(10);
            defender.GainRage(4);
            
            // Trigger hit reaction animation
            if (!defender.IsStunned)
            {
                defender.CurrentAnimation = AnimationState.HitReaction;
                defender.AnimationTimer = 0f;
            }

            if (defender.HealthCurrent < 0) defender.HealthCurrent = 0;
            AddShake(6f);
            SpawnHitSparks(defender.Position + new Vector2(defender.Facing * -4, -defender.Height + 28), 10, new Color(255, 190, 160));
        }
    }

    protected override void Draw(GameTime gameTime)
    {
        GraphicsDevice.Clear(new Color(12, 12, 16));

        if (_mode == GameMode.Map)
        {
            _spriteBatch.Begin(samplerState: SamplerState.PointClamp);
            DrawMap();
            _spriteBatch.End();
        }
        else if (_mode == GameMode.Combat)
        {
            _spriteBatch.Begin(samplerState: SamplerState.PointClamp, transformMatrix: _camera.GetTransform());
            DrawArena();
            DrawFighter(_player);
            DrawFighter(_enemy);
            DrawParticles();
            _spriteBatch.End();

            _spriteBatch.Begin(samplerState: SamplerState.PointClamp);
            DrawHUD();
            
            // Draw combat feedback
            if (_feedbackTimer > 0)
            {
                var alpha = (byte)MathHelper.Clamp(_feedbackTimer * 255f, 0, 255);
                var feedbackColor = new Color((byte)255, (byte)255, (byte)100, alpha);
                var pos = new Vector2(ViewWidth / 2 - 50, 200);
                DrawText(_lastFeedbackMessage, pos, feedbackColor);
            }

            if (_isPausedOnEnd)
            {
                DrawCenterText(_endMessage, new Color(250, 250, 250, 200));
                DrawSubCenterText("Enter: continue | R: restart run", new Color(220, 220, 220, 180));
            }
            DrawVignette();
            DrawScanlines();
            _spriteBatch.End();
        }
        else if (_mode == GameMode.Reward)
        {
            _spriteBatch.Begin(samplerState: SamplerState.PointClamp);
            DrawMapBackdrop();
            DrawReward();
            _spriteBatch.End();
        }
        else if (_mode == GameMode.End)
        {
            _spriteBatch.Begin(samplerState: SamplerState.PointClamp);
            DrawMapBackdrop();
            DrawCenterText(_endMessage == string.Empty ? "Run Over" : _endMessage, Color.White);
            DrawSubCenterText("R: restart run", new Color(220, 220, 220, 180));
            _spriteBatch.End();
        }

        base.Draw(gameTime);
    }

    private void DrawMap()
    {
        DrawMapBackdrop();

        var next = _run.GetAvailableNext();
        // Layout tiers vertically
        int tiers = _run.MaxTier + 1;
        int top = 120, bottom = ViewHeight - 140;
        int tierHeight = (bottom - top) / Math.Max(1, tiers - 1);

        // Draw connections first
        foreach (var node in _run.Nodes)
        {
            foreach (var to in node.Next)
            {
                var a = MapNodePos(node, tiers, top, tierHeight);
                var b = MapNodePos(_run.GetNode(to), tiers, top, tierHeight);
                DrawLine(a, b, new Color(60, 60, 72), 3);
            }
        }

        // Draw nodes
        int iSel = 0;
        foreach (var node in _run.Nodes)
        {
            var p = MapNodePos(node, tiers, top, tierHeight);
            int size = 18;
            var rect = new Rectangle(p.X - size, p.Y - size, size * 2, size * 2);
            Color c = node.Type switch
            {
                NodeType.Battle => new Color(90, 160, 255),
                NodeType.Elite => new Color(255, 140, 90),
                NodeType.Treasure => new Color(255, 215, 120),
                NodeType.Event => new Color(180, 180, 210),
                NodeType.Boss => new Color(255, 80, 110),
                _ => Color.White
            };

            if (node.Cleared) c *= 0.5f;

            DrawRect(rect, c);

            // Available next highlight
            var available = _run.GetAvailableNext();
            if (available.Contains(node))
            {
                int idx = available.IndexOf(node);
                if (idx == _mapSelectionIdx)
                {
                    DrawRect(new Rectangle(rect.X - 4, rect.Y - 4, rect.Width + 8, rect.Height + 8), new Color(255, 255, 255, 40));
                }
            }
        }

        DrawText("Map: Left/Right select | Enter to travel | R restart run", 30, 34, new Color(180, 180, 190));
    }

    private void DrawMapBackdrop()
    {
        DrawRect(new Rectangle(0, 0, ViewWidth, ViewHeight), new Color(10, 10, 14));
        DrawRect(new Rectangle(0, 0, ViewWidth, 80), new Color(18, 18, 24));
        DrawRect(new Rectangle(0, ViewHeight - 100, ViewWidth, 100), new Color(16, 16, 22));
    }

    private void DrawMountainLayer(int amp, float freq, int baseY, Color color)
    {
        for (int x = 0; x < ViewWidth; x += 6)
        {
            float y = baseY + (float)Math.Sin(x * freq) * amp;
            DrawRect(new Rectangle(x, (int)y, 6, (int)(GroundY + 60 - y)), color);
        }
    }

    private Point MapNodePos(MapNode n, int tiers, int top, int tierH)
    {
        int y = top + n.Tier * tierH;
        // Distribute nodes in tier across width
        int countInTier = _run.CountInTier(n.Tier);
        int idxInTier = _run.IndexInTier(n);
        int left = 140, right = ViewWidth - 140;
        int x = countInTier <= 1 ? (left + right) / 2 : left + idxInTier * (right - left) / (countInTier - 1);
        return new Point(x, y);
    }

    private void DrawReward()
    {
        int w = ViewWidth - 300;
        int h = 200;
        var rect = new Rectangle((ViewWidth - w) / 2, (ViewHeight - h) / 2 - 40, w, h);
        DrawRect(rect, new Color(0, 0, 0, 140));
        DrawText("Choose a reward: 1 or 2", rect.X + 28, rect.Y + 28, Color.White);

        // Draw two option boxes
        int boxW = (w - 60) / 2;
        int boxH = 80;
        var box1 = new Rectangle(rect.X + 20, rect.Y + 80, boxW, boxH);
        var box2 = new Rectangle(rect.X + 40 + boxW, rect.Y + 80, boxW, boxH);
        DrawRect(box1, new Color(30, 30, 36));
        DrawRect(box2, new Color(30, 30, 36));
        DrawText(_reward1?.Label ?? "...", box1.X + 16, box1.Y + 16, new Color(200, 220, 255));
        DrawText(_reward2?.Label ?? "...", box2.X + 16, box2.Y + 16, new Color(200, 220, 255));
    }

    private void DrawArena()
    {
        // Parallax sky and mountains
        DrawRect(new Rectangle(0, 0, ViewWidth, (int)GroundY + 200), new Color(16, 12, 28));
        DrawMountainLayer(amp: 40, freq: 0.010f, baseY: (int)GroundY - 140, color: new Color(24, 20, 50));
        DrawMountainLayer(amp: 28, freq: 0.014f, baseY: (int)GroundY - 100, color: new Color(30, 22, 60));
        DrawMountainLayer(amp: 16, freq: 0.020f, baseY: (int)GroundY - 70, color: new Color(40, 26, 74));

        // Ground line and floor
        DrawRect(new Rectangle(0, (int)GroundY + 40, ViewWidth, 6), new Color(60, 40, 88));
        DrawRect(new Rectangle(0, (int)GroundY + 46, ViewWidth, 200), new Color(10, 8, 18));
    }

    private void DrawFighter(Fighter f)
    {
        // Apply animation offset to position
        var animatedPos = f.Position + f.AnimationOffset;
        var bodyRect = new Rectangle((int)(animatedPos.X - f.HalfWidth), (int)(animatedPos.Y - f.Height), (int)(f.HalfWidth * 2), (int)f.Height);

        // Enhanced telegraph animation
        if (f.IsTelegraphing)
        {
            float intensity = 0.5f + 0.5f * (float)Math.Abs(Math.Sin((f.TelegraphTimer * 15)));
            var flash = Color.Lerp(Color.Transparent, new Color(255, 50, 50), intensity);
            
            // Pulsing outline effect
            for (int size = 1; size <= 4; size++)
            {
                var outlineRect = new Rectangle(
                    bodyRect.X - size * 2, 
                    bodyRect.Y - size * 2, 
                    bodyRect.Width + size * 4, 
                    bodyRect.Height + size * 4
                );
                var outlineAlpha = (byte)(flash.A / (size * 2));
                DrawRect(outlineRect, new Color((byte)255, (byte)50, (byte)50, outlineAlpha));
            }
            
            // Warning indicators
            var warningPos1 = new Vector2(bodyRect.X + bodyRect.Width/2, bodyRect.Y - 20);
            var warningPos2 = new Vector2(bodyRect.X + bodyRect.Width/2, bodyRect.Y + bodyRect.Height + 10);
            DrawRect(new Rectangle((int)warningPos1.X - 10, (int)warningPos1.Y - 2, 20, 4), flash);
            DrawRect(new Rectangle((int)warningPos2.X - 10, (int)warningPos2.Y - 2, 20, 4), flash);
        }

        // Draw character sprite with glow effect for better visibility
        var spriteEffect = f.Facing > 0 ? SpriteEffects.None : SpriteEffects.FlipHorizontally;
        var spriteColor = f.ColorBody;
        
        // Special effects based on animation state
        if (f.CurrentAnimation == AnimationState.Attacking)
        {
            spriteColor = Color.Lerp(spriteColor, Color.Yellow, 0.3f);
        }
        else if (f.CurrentAnimation == AnimationState.Blocking)
        {
            spriteColor = Color.Lerp(spriteColor, Color.Cyan, 0.2f);
        }
        else if (f.CurrentAnimation == AnimationState.HitReaction)
        {
            spriteColor = Color.Lerp(spriteColor, Color.Red, 0.4f);
        }
        
        // Add a subtle glow/outline effect
        for (int ox = -1; ox <= 1; ox++)
        {
            for (int oy = -1; oy <= 1; oy++)
            {
                if (ox == 0 && oy == 0) continue;
                var glowRect = new Rectangle(bodyRect.X + ox, bodyRect.Y + oy, bodyRect.Width, bodyRect.Height);
                _spriteBatch.Draw(_characterSprite, glowRect, null, new Color(0, 0, 0, 60), 0f, Vector2.Zero, spriteEffect, 0f);
            }
        }
        
        // Tint sprite with character color
        _spriteBatch.Draw(_characterSprite, bodyRect, null, spriteColor, 0f, Vector2.Zero, spriteEffect, 0f);
        
        // Special dash afterimage effect
        if (f.CurrentAnimation == AnimationState.Dashing)
        {
            for (int i = 1; i <= 3; i++)
            {
                var afterimageRect = new Rectangle(
                    bodyRect.X - f.Facing * i * 12,
                    bodyRect.Y,
                    bodyRect.Width,
                    bodyRect.Height
                );
                var afterimageAlpha = (byte)(60 / i);
                var afterimageColor = new Color(spriteColor.R, spriteColor.G, spriteColor.B, afterimageAlpha);
                _spriteBatch.Draw(_characterSprite, afterimageRect, null, afterimageColor, 0f, Vector2.Zero, spriteEffect, 0f);
            }
        }

        // Weapon indicator (sword-like line)
        if (f.IsHitActive())
        {
            int len = (int)f.AttackRange;
            var weaponStart = new Vector2(
                f.Facing > 0 ? f.Position.X + f.HalfWidth : f.Position.X - f.HalfWidth,
                f.Position.Y - f.Height * 0.4f
            );
            var weaponEnd = new Vector2(
                weaponStart.X + f.Facing * len,
                weaponStart.Y
            );
            
            // Draw weapon trail as a thick line
            for (int i = 0; i < 4; i++)
            {
                var offset = new Vector2(0, i - 2);
                DrawLine(new Point((int)(weaponStart.X + offset.X), (int)(weaponStart.Y + offset.Y)), 
                        new Point((int)(weaponEnd.X + offset.X), (int)(weaponEnd.Y + offset.Y)), 
                        new Color(210, 240, 255, 80), 2);
            }
        }

        // Stun stars
        if (f.IsStunned)
        {
            var stunRect = new Rectangle(bodyRect.X, bodyRect.Y - 18, bodyRect.Width, 12);
            DrawRect(stunRect, new Color(255, 220, 0, 120));
        }
    }

    private void DrawHUD()
    {
        // Panels
        var left = new Rectangle(20, 20, ViewWidth / 2 - 40, 92);
        var right = new Rectangle(ViewWidth / 2 + 20, 20, ViewWidth / 2 - 40, 92);
        DrawRect(left, new Color(22, 22, 28, 220));
        DrawRect(right, new Color(22, 22, 28, 220));

        // Bars
        DrawBars(_player, 30, 34);
        DrawBars(_enemy, ViewWidth / 2 + 30, 34, mirror: true);

        // Help
        DrawText("A/D move | J attack | K block/parry | Space dash | R restart", 30, 124, new Color(180, 180, 190));
    }

    private void DrawBars(Fighter f, int x, int y, bool mirror = false)
    {
        int width = ViewWidth / 2 - 60;
        int barH = 16;
        int gap = 6;

        void Bar(float pct, Color c, int row, string label)
        {
            var back = new Rectangle(x, y + row * (barH + gap), width, barH);
            DrawRect(back, new Color(12, 12, 16));
            
            // Add a subtle border
            DrawRect(new Rectangle(back.X - 1, back.Y - 1, back.Width + 2, back.Height + 2), new Color(60, 60, 70));
            DrawRect(back, new Color(20, 20, 24));
            
            int w = (int)(width * Math.Clamp(pct, 0f, 1f));
            var fill = new Rectangle(x, y + row * (barH + gap), w, barH);
            DrawRect(fill, c);
            
            // Add a bright edge effect for full bars
            if (pct > 0.95f)
            {
                var highlight = new Rectangle(x, y + row * (barH + gap), w, 2);
                DrawRect(highlight, Color.Lerp(c, Color.White, 0.6f));
            }
            
            // Draw label
            DrawText(label, x - 50, y + row * (barH + gap) + 2, new Color(180, 180, 190));
        }

        Bar(f.HealthCurrent / f.HealthMax, new Color(231, 76, 60), 0, "HP");
        Bar(f.PostureCurrent / f.PostureMax, new Color(241, 196, 15), 1, "PST");
        Bar(f.RageCurrent / f.RageMax, new Color(142, 68, 173), 2, "RGE");
    }

    private void DrawCenterText(string text, Color color)
    {
        // Minimalist center block instead of font rendering
        int w = 420;
        int h = 120;
        var rect = new Rectangle((ViewWidth - w) / 2, (ViewHeight - h) / 2 - 24, w, h);
        DrawRect(rect, new Color(0, 0, 0, 140));
        DrawText(text, rect.X + 28, rect.Y + 28, color);
    }

    private void DrawSubCenterText(string text, Color color)
    {
        int w = 380;
        int h = 60;
        var rect = new Rectangle((ViewWidth - w) / 2, (ViewHeight - h) / 2 + 60, w, h);
        DrawRect(rect, new Color(0, 0, 0, 90));
        DrawText(text, rect.X + 18, rect.Y + 18, color);
    }

    private void DrawText(string text, Vector2 position, Color color)
    {
        _spriteBatch.DrawString(_defaultFont, text, position, color);
    }

    private void DrawText(string text, int x, int y, Color color)
    {
        DrawText(text, new Vector2(x, y), color);
    }

    private void DrawRect(Rectangle r, Color c)
    {
        _spriteBatch.Draw(_pixel, r, c);
    }

    private void DrawLine(Point a, Point b, Color c, int thickness)
    {
        var dx = b.X - a.X;
        var dy = b.Y - a.Y;
        var len = (float)Math.Sqrt(dx * dx + dy * dy);
        float angle = (float)Math.Atan2(dy, dx);
        var rect = new Rectangle(a.X, a.Y, (int)len, thickness);
        _spriteBatch.Draw(_pixel, rect, null, c, angle, Vector2.Zero, SpriteEffects.None, 0f);
    }

    private void DrawScanlines()
    {
        var c = new Color(255, 255, 255, 12);
        for (int y = 0; y < ViewHeight; y += 4)
        {
            DrawRect(new Rectangle(0, y, ViewWidth, 1), c);
        }
    }

    private void DrawVignette()
    {
        int border = 30;
        var col = new Color(0, 0, 0, 120);
        DrawRect(new Rectangle(0, 0, ViewWidth, border), col);
        DrawRect(new Rectangle(0, ViewHeight - border, ViewWidth, border), col);
        DrawRect(new Rectangle(0, 0, border, ViewHeight), col);
        DrawRect(new Rectangle(ViewWidth - border, 0, border, ViewHeight), col);
    }

    private bool Pressed(KeyboardState kb, Keys key)
    {
        return kb.IsKeyDown(key) && !_prevKb.IsKeyDown(key);
    }

    private void AddShake(float amount)
    {
        _camera.Shake += amount;
    }

    private void TriggerSlowMo(float factor, float duration)
    {
        _timeScale = MathHelper.Clamp(factor, 0.3f, 1f);
        _timeScaleRecoverTimer = Math.Max(_timeScaleRecoverTimer, duration);
    }
    
    private void ShowFeedback(string message, float duration = 1.0f)
    {
        _lastFeedbackMessage = message;
        _feedbackTimer = duration;
    }

    private void SpawnHitSparks(Vector2 center, int count, Color color)
    {
        for (int i = 0; i < count; i++)
        {
            float ang = (float)(_rng.NextDouble() * Math.PI * 2);
            float spd = 280f + (float)_rng.NextDouble() * 180f;
            var vel = new Vector2(MathF.Cos(ang), MathF.Sin(ang)) * spd;
            float life = 0.18f + (float)_rng.NextDouble() * 0.22f;
            _particles.Add(new Particle
            {
                Position = center,
                Velocity = vel,
                Life = life,
                MaxLife = life,
                Color = color,
                Size = 2 + _rng.Next(3),
                Rotation = (float)(_rng.NextDouble() * Math.PI * 2),
                RotationSpeed = ((float)_rng.NextDouble() - 0.5f) * 12f,
            });
        }
    }

    private void UpdateParticles(float dt)
    {
        for (int i = _particles.Count - 1; i >= 0; i--)
        {
            var p = _particles[i];
            p.Life -= dt;
            if (p.Life <= 0) { _particles.RemoveAt(i); continue; }
            p.Position += p.Velocity * dt;
            p.Velocity *= 0.92f;
            p.Rotation += p.RotationSpeed * dt;
            p.Velocity.Y += 120f * dt; // Gravity
            _particles[i] = p;
        }
    }

    private void DrawParticles()
    {
        foreach (var p in _particles)
        {
            float lifeRatio = p.Life / p.MaxLife;
            byte a = (byte)(lifeRatio * 255);
            var particleColor = new Color(p.Color.R, p.Color.G, p.Color.B, a);
            
            // Draw as rotated squares that fade and shrink over time
            var destRect = new Rectangle(
                (int)p.Position.X, 
                (int)p.Position.Y, 
                (int)(p.Size * (0.5f + lifeRatio * 0.5f)), 
                (int)(p.Size * (0.5f + lifeRatio * 0.5f))
            );
            var origin = new Vector2(destRect.Width / 2f, destRect.Height / 2f);
            
            _spriteBatch.Draw(_pixel, destRect, null, particleColor, p.Rotation, origin, SpriteEffects.None, 0f);
        }
    }
}

public enum AnimationState
{
    Idle,
    Walking,
    Attacking,
    HitReaction,
    Blocking,
    Stunned,
    Dashing
}

public class Fighter
{
    // Identity
    public string Name { get; set; } = "Fighter";

    // Visual
    public Color ColorBody { get; set; } = new Color(130, 160, 220);
    public Color ColorAccent { get; set; } = new Color(90, 120, 190);
    
    // Animation
    public AnimationState CurrentAnimation { get; set; } = AnimationState.Idle;
    public float AnimationTimer { get; set; } = 0f;
    public Vector2 AnimationOffset { get; set; } = Vector2.Zero;

    // Kinematics
    public Vector2 Position;
    public Vector2 Velocity;
    public int Facing = 1; // +1 right, -1 left
    public float MoveSpeed = 420f;
    public float HalfWidth = 22f;
    public float Height = 88f;

    // Combat stats
    public float HealthMax = 100f;
    public float HealthCurrent = 100f;
    public float PostureMax = 100f;
    public float PostureCurrent = 100f;
    public float RageMax = 100f;
    public float RageCurrent = 0f;

    // Attack properties
    public float AttackRange = 72f;
    public float AttackDamage = 12f;
    public float AttackPostureDamage = 22f;

    // Timers
    private float _attackTimer = 0f;
    private float _attackCooldown = 0f;
    private float _attackActiveStart = 0.10f; // seconds after start
    private float _attackActiveEnd = 0.18f;
    public bool WasHitThisSwing = false;

    private float _dashTimer = 0f;
    private float _dashCooldown = 0f;

    public bool IsBlocking = false;
    private float _parryTimer = 0f; // small window after tap block

    public bool IsStunned = false;
    private float _stunTimer = 0f;

    // AI
    public bool IsAI = false;
    public bool IsTelegraphing = false;
    public float TelegraphTimer = 0f;

    // Input mapping
    public FighterControls Controls = FighterControls.PlayerOne();

    public void UpdateTimers(float dt)
    {
        // Natural posture recovery if not stunned
        if (!IsStunned)
        {
            PostureCurrent = MathHelper.Clamp(PostureCurrent + 12f * dt, 0f, PostureMax);
        }

        if (_attackCooldown > 0) _attackCooldown -= dt;
        if (_dashCooldown > 0) _dashCooldown -= dt;
        if (_parryTimer > 0) _parryTimer -= dt;

        if (IsStunned)
        {
            _stunTimer -= dt;
            if (_stunTimer <= 0) 
            {
                IsStunned = false;
                CurrentAnimation = AnimationState.Idle;
            }
        }

        if (_attackTimer > 0)
        {
            _attackTimer -= dt;
            if (_attackTimer <= 0)
            {
                _attackTimer = 0;
                WasHitThisSwing = false;
                CurrentAnimation = AnimationState.Idle;
            }
        }

        if (_dashTimer > 0)
        {
            _dashTimer -= dt;
            if (_dashTimer <= 0)
            {
                _dashTimer = 0;
                // End dash velocity
                Velocity.X *= 0.3f;
                CurrentAnimation = AnimationState.Idle;
            }
        }

        if (IsTelegraphing)
        {
            TelegraphTimer -= dt;
            if (TelegraphTimer <= 0)
            {
                IsTelegraphing = false;
            }
        }
        
        // Update animation
        UpdateAnimation(dt);
    }
    
    private void UpdateAnimation(float dt)
    {
        AnimationTimer += dt;
        
        switch (CurrentAnimation)
        {
            case AnimationState.Attacking:
                // Lunge forward during attack
                float attackProgress = 1f - (_attackTimer / 0.35f);
                AnimationOffset = new Vector2(MathF.Sin(attackProgress * MathF.PI) * 15f * Facing, AnimationOffset.Y);
                break;
                
            case AnimationState.HitReaction:
                // Knockback effect
                AnimationOffset = new Vector2(MathF.Cos(AnimationTimer * 20f) * 8f * -Facing, AnimationOffset.Y);
                if (AnimationTimer > 0.3f)
                {
                    CurrentAnimation = AnimationState.Idle;
                    AnimationTimer = 0f;
                }
                break;
                
            case AnimationState.Blocking:
                // Slight defensive crouch
                AnimationOffset = new Vector2(AnimationOffset.X, MathF.Sin(AnimationTimer * 8f) * 3f);
                if (!IsBlocking)
                {
                    CurrentAnimation = AnimationState.Idle;
                    AnimationTimer = 0f;
                }
                break;
                
            case AnimationState.Stunned:
                // Wobble effect
                AnimationOffset = new Vector2(MathF.Sin(AnimationTimer * 12f) * 5f, MathF.Cos(AnimationTimer * 15f) * 2f);
                break;
                
            case AnimationState.Dashing:
                // Blur/stretch effect handled in rendering
                break;
                
            case AnimationState.Walking:
                // Bob up and down
                AnimationOffset = new Vector2(AnimationOffset.X, MathF.Sin(AnimationTimer * 12f) * 2f);
                if (Math.Abs(Velocity.X) < 10f)
                {
                    CurrentAnimation = AnimationState.Idle;
                    AnimationTimer = 0f;
                }
                break;
                
            default:
                AnimationOffset = Vector2.Lerp(AnimationOffset, Vector2.Zero, 0.15f);
                break;
        }
    }

    public bool IsInRecovery()
    {
        return _attackTimer <= 0 && _attackCooldown > 0;
    }

    public bool CanAttack()
    {
        return _attackTimer <= 0 && _attackCooldown <= 0 && !IsStunned && !IsTelegraphing;
    }

    public void StartTelegraph()
    {
        if (CanAttack())
        {
            IsTelegraphing = true;
            TelegraphTimer = 0.35f;
        }
    }

    public void StartAttack()
    {
        if (!CanAttack()) return;
        _attackTimer = 0.35f;
        _attackCooldown = 0.35f;
        WasHitThisSwing = false;
        IsTelegraphing = false;
        CurrentAnimation = AnimationState.Attacking;
        AnimationTimer = 0f;
    }

    public bool IsHitActive()
    {
        return _attackTimer > 0 && _attackTimer <= (0.35f - _attackActiveStart) && _attackTimer >= (0.35f - _attackActiveEnd);
    }

    public bool CanDash()
    {
        return _dashTimer <= 0 && _dashCooldown <= 0 && !IsStunned;
    }

    public void StartDash()
    {
        _dashTimer = 0.16f;
        _dashCooldown = 0.60f;
        Velocity.X = Facing * 900f;
        CurrentAnimation = AnimationState.Dashing;
        AnimationTimer = 0f;
    }

    public void TriggerParryWindow()
    {
        _parryTimer = 0.12f;
    }

    public bool ConsumeParryIfActive()
    {
        if (_parryTimer > 0)
        {
            _parryTimer = 0;
            return true;
        }
        return false;
    }

    public void ApplyPostureDamage(float amount)
    {
        PostureCurrent -= amount;
        if (PostureCurrent <= 0)
        {
            PostureCurrent = 0;
            ApplyStun(0.7f);
            // Small posture refill after break
            PostureCurrent = MathF.Min(PostureMax * 0.4f, PostureMax);
        }
    }

    public void ApplyStun(float duration)
    {
        IsStunned = true;
        _stunTimer = duration;
        _attackTimer = 0;
        _attackCooldown = 0.25f;
        IsTelegraphing = false;
        Velocity.X *= 0.3f;
        CurrentAnimation = AnimationState.Stunned;
        AnimationTimer = 0f;
    }

    public void GainRage(float amount)
    {
        RageCurrent = MathHelper.Clamp(RageCurrent + amount, 0f, RageMax);
    }
}

public class FighterControls
{
    public Keys Left { get; set; }
    public Keys Right { get; set; }
    public Keys Attack { get; set; }
    public Keys Block { get; set; }
    public Keys Dash { get; set; }

    public static FighterControls PlayerOne()
    {
        return new FighterControls
        {
            Left = Keys.A,
            Right = Keys.D,
            Attack = Keys.J,
            Block = Keys.K,
            Dash = Keys.Space,
        };
    }
}

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

public sealed class Camera2D
{
    public float Shake { get; set; } = 0f;
    private Vector2 _offset = Vector2.Zero;
    private readonly Random _rng = new Random();

    public void Update(float dt)
    {
        if (Shake > 0)
        {
            Shake = Math.Max(0, Shake - 20f * dt);
            float dx = ((float)_rng.NextDouble() * 2f - 1f) * Shake;
            float dy = ((float)_rng.NextDouble() * 2f - 1f) * Shake * 0.6f;
            _offset = new Vector2(dx, dy);
        }
        else
        {
            _offset *= 0.85f;
        }
    }

    public Matrix GetTransform()
    {
        return Matrix.CreateTranslation(new Vector3(_offset, 0f));
    }
}
public enum GameMode
{
    Map,
    Combat,
    Reward,
    End
}

public enum NodeType
{
    Battle,
    Elite,
    Treasure,
    Event,
    Boss
}

public class MapNode
{
    public int Id { get; set; }
    public int Tier { get; set; }
    public NodeType Type { get; set; }
    public bool Cleared { get; set; }
    public List<int> Next { get; set; } = new();
}

public class RunState
{
    public List<MapNode> Nodes { get; private set; } = new();
    public int CurrentNodeId { get; private set; }
    public int MaxTier { get; private set; }

    public static RunState CreateSimpleThreeTier()
    {
        // Tiers: 0 (start event), 1 (battle), 2 (battle/elite), 3 (boss)
        var r = new RunState();
        r.Nodes = new List<MapNode>
        {
            new MapNode{ Id=0, Tier=0, Type=NodeType.Event, Next={1,2}},
            new MapNode{ Id=1, Tier=1, Type=NodeType.Battle, Next={3}},
            new MapNode{ Id=2, Tier=1, Type=NodeType.Battle, Next={4}},
            new MapNode{ Id=3, Tier=2, Type=NodeType.Elite, Next={5}},
            new MapNode{ Id=4, Tier=2, Type=NodeType.Treasure, Next={5}},
            new MapNode{ Id=5, Tier=3, Type=NodeType.Boss, Next={}},
        };
        r.CurrentNodeId = 0;
        r.MaxTier = 3;
        return r;
    }

    public MapNode GetNode(int id) => Nodes.Find(n => n.Id == id)!;

    public List<MapNode> GetAvailableNext()
    {
        var cur = GetNode(CurrentNodeId);
        var list = new List<MapNode>();
        foreach (var id in cur.Next)
        {
            list.Add(GetNode(id));
        }
        return list;
    }

    public void AdvanceTo(int id)
    {
        CurrentNodeId = id;
    }

    public void MarkCurrentNodeCleared()
    {
        GetNode(CurrentNodeId).Cleared = true;
    }

    public int CountInTier(int tier) => Nodes.FindAll(n => n.Tier == tier).Count;
    public int IndexInTier(MapNode node)
    {
        int idx = 0;
        foreach (var n in Nodes)
        {
            if (n.Tier != node.Tier) continue;
            if (n.Id == node.Id) return idx;
            idx++;
        }
        return 0;
    }
}

public class RewardOption
{
    public string Id { get; set; } = Guid.NewGuid().ToString("N");
    public string Label { get; set; } = "";

    public void Apply(Fighter f)
    {
        switch (Id)
        {
            case "atk_up":
                f.AttackDamage += 4f;
                break;
            case "posture_up":
                f.PostureMax += 25f;
                f.PostureCurrent += 25f;
                break;
            case "rage_gain":
                // Simulate as passive: slightly increase damage when rage high
                f.AttackPostureDamage += 6f;
                break;
            case "dash_cd":
                // Make dash stronger via speed
                f.MoveSpeed += 40f;
                break;
        }
    }

    public static RewardOption Random(string? exclude = null)
    {
        var pool = new List<(string id, string label)>
        {
            ("atk_up", "+4 Attack Damage"),
            ("posture_up", "+25 Posture Max"),
            ("rage_gain", "+6 Posture Damage"),
            ("dash_cd", "+40 Move Speed"),
        };
        var rnd = new Random();
        (string id, string label) pick;
        do
        {
            pick = pool[rnd.Next(pool.Count)];
        } while (exclude != null && pick.id == exclude);
        return new RewardOption { Id = pick.id, Label = pick.label };
    }
}

public static class EnemyFactory
{
    public static Fighter CreateEnemyForNode(MapNode node)
    {
        // Scale enemy by node type
        float hp = node.Type switch
        {
            NodeType.Battle => 90,
            NodeType.Elite => 130,
            NodeType.Boss => 220,
            _ => 90
        };
        float dmg = node.Type switch
        {
            NodeType.Battle => 10,
            NodeType.Elite => 14,
            NodeType.Boss => 18,
            _ => 10
        };
        float posture = node.Type switch
        {
            NodeType.Battle => 100,
            NodeType.Elite => 120,
            NodeType.Boss => 160,
            _ => 100
        };

        return new Fighter
        {
            Name = node.Type == NodeType.Boss ? "Boss" : (node.Type == NodeType.Elite ? "Elite" : "Enemy"),
            Position = new Vector2(Game1Accessor.ViewWidthStatic - 360, Game1Accessor.GroundYStatic),
            Facing = -1,
            ColorBody = node.Type == NodeType.Boss ? new Color(255, 90, 130) : (node.Type == NodeType.Elite ? new Color(255, 170, 110) : new Color(255, 120, 120)),
            ColorAccent = new Color(210, 60, 60),
            IsAI = true,
            HealthMax = hp,
            HealthCurrent = hp,
            AttackDamage = dmg,
            PostureMax = posture,
            PostureCurrent = posture,
            AttackPostureDamage = 24f,
            MoveSpeed = 380f,
        };
    }
}

// Accessors to reuse constants without making them static on Game1
public static class Game1Accessor
{
    public static int ViewWidthStatic => 1280;
    public static float GroundYStatic => 580f;
}
