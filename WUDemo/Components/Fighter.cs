using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;
using System;
using WUDemo.Core;
using WUDemo.Debug;
using WUDemo.Graphics;

namespace WUDemo.Components
{
    public enum AnimationState
    {
        Idle,
        Walking,
        Attacking,
        HitReaction,
        Blocking,
        Stunned,
        Dashing,
        Jumping,
        Falling,
        Landing
    }
    
    public class Fighter
    {
        // Identity
        public string Name { get; set; } = "Fighter";
        public bool IsAI { get; set; } = false;
        
        // Visual
        public Color ColorBody { get; set; } = new Color(130, 160, 220);
        public Color ColorAccent { get; set; } = new Color(90, 120, 190);
        private AnimationState _currentAnimation = AnimationState.Idle;
        public AnimationState CurrentAnimation 
        { 
            get => _currentAnimation;
            set
            {
                if (_currentAnimation != value)
                {
                    CombatDebugger.Instance.LogStateChange(Name, _currentAnimation.ToString(), value.ToString());
                    _currentAnimation = value;
                }
            }
        }
        public float AnimationTimer { get; set; } = 0f;
        public Vector2 AnimationOffset { get; set; } = Vector2.Zero;
        public AnimatedSprite Sprite { get; set; }
        
        // Transform
        public Vector2 Position { get; set; }
        public Vector2 Velocity { get; set; }
        public int Facing { get; set; } = 1; // +1 right, -1 left
        
        // Dimensions
        public float HalfWidth { get; set; } = 22f;
        public float Height { get; set; } = 88f;
        
        // Movement
        public float MoveSpeed { get; set; } = GameConstants.DefaultMoveSpeed;
        public float JumpForce { get; set; } = 750f;
        public float Gravity { get; set; } = 2800f;
        public bool IsGrounded { get; set; } = true;
        public bool HasDoubleJump { get; set; } = false;
        public bool IsInvulnerable { get; set; } = false;
        
        // Combat Stats
        public float HealthMax { get; set; } = GameConstants.DefaultHealthMax;
        public float HealthCurrent { get; set; } = GameConstants.DefaultHealthMax;
        public float PostureMax { get; set; } = GameConstants.DefaultPostureMax;
        public float PostureCurrent { get; set; } = GameConstants.DefaultPostureMax;
        public float RageMax { get; set; } = GameConstants.DefaultRageMax;
        public float RageCurrent { get; set; } = 0f;
        
        // Attack Properties
        public float AttackRange { get; set; } = GameConstants.DefaultAttackRange;
        public float AttackDamage { get; set; } = GameConstants.DefaultAttackDamage;
        public float AttackPostureDamage { get; set; } = GameConstants.DefaultPostureDamage;
        
        // State Flags
        public bool IsBlocking { get; set; } = false;
        public bool IsStunned { get; set; } = false;
        public bool IsTelegraphing { get; set; } = false;
        public bool WasHitThisSwing { get; set; } = false;
        
        // Timers
        private float _attackTimer = 0f;
        private float _attackCooldown = 0f;
        private float _dashTimer = 0f;
        private float _dashCooldown = 0f;
        private float _parryTimer = 0f;
        private float _stunTimer = 0f;
        private float _jumpCooldown = 0f;
        private float _landingRecovery = 0f;
        private float _iframeTimer = 0f;
        public float TelegraphTimer { get; set; } = 0f;
        public float ComboWindow { get; set; } = 0f;
        public int ComboCount { get; set; } = 0;
        
        // Input
        public FighterControls Controls { get; set; } = FighterControls.PlayerOne();
        
        public void UpdateTimers(float dt)
        {
            // Natural posture recovery
            if (!IsStunned)
            {
                PostureCurrent = MathHelper.Clamp(
                    PostureCurrent + GameConstants.PostureRecoveryRate * dt, 
                    0f, 
                    PostureMax
                );
            }
            
            // Update cooldowns
            if (_attackCooldown > 0) _attackCooldown -= dt;
            if (_dashCooldown > 0) _dashCooldown -= dt;
            if (_parryTimer > 0) _parryTimer -= dt;
            if (_jumpCooldown > 0) _jumpCooldown -= dt;
            if (_landingRecovery > 0) _landingRecovery -= dt;
            if (_iframeTimer > 0) _iframeTimer -= dt;
            if (ComboWindow > 0) 
            {
                ComboWindow -= dt;
                if (ComboWindow <= 0) ComboCount = 0;
            }
            
            // Update invulnerability
            IsInvulnerable = _iframeTimer > 0 || (_dashTimer > 0 && _dashTimer > GameConstants.DashDuration * 0.2f);
            
            // Update sprite animation
            FighterAnimations.UpdateFighterAnimation(this, dt);
            
            // Handle stun
            if (IsStunned)
            {
                _stunTimer -= dt;
                if (_stunTimer <= 0)
                {
                    IsStunned = false;
                    CurrentAnimation = AnimationState.Idle;
                }
            }
            
            // Handle attack timer
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
            
            // Handle dash timer
            if (_dashTimer > 0)
            {
                _dashTimer -= dt;
                if (_dashTimer <= 0)
                {
                    _dashTimer = 0;
                    Velocity = new Vector2(Velocity.X * 0.3f, Velocity.Y);
                    CurrentAnimation = AnimationState.Idle;
                }
            }
            
            // Handle telegraph
            if (IsTelegraphing)
            {
                TelegraphTimer -= dt;
                
                // Safety timeout - if telegraph has been going too long, cancel it
                if (TelegraphTimer < -1f)
                {
                    IsTelegraphing = false;
                    CombatDebugger.Instance.LogSystem($"{Name}: Telegraph timeout - cancelling", Color.Red);
                }
            }
            
            UpdateAnimation(dt);
        }
        
        private void UpdateAnimation(float dt)
        {
            AnimationTimer += dt;
            
            switch (CurrentAnimation)
            {
                case AnimationState.Attacking:
                    float attackProgress = 1f - (_attackTimer / GameConstants.AttackDuration);
                    AnimationOffset = new Vector2(
                        MathF.Sin(attackProgress * MathF.PI) * 15f * Facing, 
                        AnimationOffset.Y
                    );
                    break;
                    
                case AnimationState.HitReaction:
                    AnimationOffset = new Vector2(
                        MathF.Cos(AnimationTimer * 20f) * 8f * -Facing, 
                        AnimationOffset.Y
                    );
                    if (AnimationTimer > 0.3f)
                    {
                        CurrentAnimation = AnimationState.Idle;
                        AnimationTimer = 0f;
                    }
                    break;
                    
                case AnimationState.Blocking:
                    AnimationOffset = new Vector2(
                        AnimationOffset.X, 
                        MathF.Sin(AnimationTimer * 8f) * 3f
                    );
                    if (!IsBlocking)
                    {
                        CurrentAnimation = AnimationState.Idle;
                        AnimationTimer = 0f;
                    }
                    break;
                    
                case AnimationState.Stunned:
                    AnimationOffset = new Vector2(
                        MathF.Sin(AnimationTimer * 12f) * 5f, 
                        MathF.Cos(AnimationTimer * 15f) * 2f
                    );
                    break;
                    
                case AnimationState.Dashing:
                    float dashProgress = 1f - (_dashTimer / GameConstants.DashDuration);
                    AnimationOffset = new Vector2(
                        MathF.Sin(dashProgress * MathF.PI) * 20f * Facing,
                        MathF.Sin(dashProgress * MathF.PI * 2) * -8f
                    );
                    break;
                    
                case AnimationState.Jumping:
                    AnimationOffset = new Vector2(
                        AnimationOffset.X,
                        MathF.Sin(AnimationTimer * 10f) * 3f - 5f
                    );
                    break;
                    
                case AnimationState.Landing:
                    AnimationOffset = new Vector2(
                        AnimationOffset.X,
                        MathF.Cos(AnimationTimer * 15f) * 4f + 3f
                    );
                    if (AnimationTimer > 0.2f)
                    {
                        CurrentAnimation = AnimationState.Idle;
                        AnimationTimer = 0f;
                    }
                    break;
                    
                case AnimationState.Walking:
                    AnimationOffset = new Vector2(
                        AnimationOffset.X, 
                        MathF.Sin(AnimationTimer * 12f) * 2f
                    );
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
        
        public bool CanAttack()
        {
            return _attackTimer <= 0 && _attackCooldown <= 0 && !IsStunned && !IsTelegraphing && _landingRecovery <= 0;
        }
        
        public bool CanJump()
        {
            return (IsGrounded || HasDoubleJump) && _jumpCooldown <= 0 && !IsStunned;
        }
        
        public void StartJump()
        {
            if (!IsGrounded && HasDoubleJump)
            {
                HasDoubleJump = false;
                Velocity = new Vector2(Velocity.X, -JumpForce * 0.85f);
            }
            else if (IsGrounded)
            {
                Velocity = new Vector2(Velocity.X, -JumpForce);
                IsGrounded = false;
                HasDoubleJump = true;
            }
            _jumpCooldown = 0.1f;
            CurrentAnimation = AnimationState.Jumping;
            AnimationTimer = 0f;
        }
        
        public void Land()
        {
            IsGrounded = true;
            HasDoubleJump = false;
            _landingRecovery = 0.1f;
            if (CurrentAnimation == AnimationState.Jumping || CurrentAnimation == AnimationState.Falling)
            {
                CurrentAnimation = AnimationState.Landing;
                AnimationTimer = 0f;
            }
        }
        
        public void StartTelegraph()
        {
            if (CanAttack())
            {
                IsTelegraphing = true;
                TelegraphTimer = 0.35f;
                CombatDebugger.Instance.LogSystem($"{Name}: Telegraph started (0.35s)", Color.Orange);
            }
            else
            {
                CombatDebugger.Instance.LogSystem($"{Name}: Telegraph failed - can't attack", Color.Red);
            }
        }
        
        public void StartAttack()
        {
            // Can attack if not already attacking and not stunned
            // Don't check IsTelegraphing here since this is called after telegraph
            if (_attackTimer > 0 || _attackCooldown > 0 || IsStunned || _landingRecovery > 0) 
            {
                CombatDebugger.Instance.LogSystem($"{Name}: StartAttack failed - " +
                    $"attacking:{_attackTimer > 0} cooldown:{_attackCooldown > 0} stunned:{IsStunned} landing:{_landingRecovery > 0}", 
                    Color.Red);
                return;
            }
            
            ComboCount = ComboWindow > 0 ? ComboCount + 1 : 1;
            ComboWindow = 0.5f;
            
            // Keep attack duration consistent for hit detection
            _attackTimer = GameConstants.AttackDuration;
            _attackCooldown = GameConstants.AttackDuration * (ComboCount > 2 ? 0.8f : 1f);
            WasHitThisSwing = false;
            IsTelegraphing = false;
            CurrentAnimation = AnimationState.Attacking;
            AnimationTimer = 0f;
            
            CombatDebugger.Instance.LogSystem($"{Name}: Attack started successfully! (combo:{ComboCount})", Color.LightGreen);
            
            if (!IsGrounded)
            {
                Velocity = new Vector2(Velocity.X, Velocity.Y * 0.5f);
            }
        }
        
        public bool IsHitActive()
        {
            return _attackTimer > 0 && 
                   _attackTimer <= (GameConstants.AttackDuration - GameConstants.AttackActiveStart) && 
                   _attackTimer >= (GameConstants.AttackDuration - GameConstants.AttackActiveEnd);
        }
        
        public bool CanDash()
        {
            return _dashTimer <= 0 && _dashCooldown <= 0 && !IsStunned;
        }
        
        public void StartDash()
        {
            _dashTimer = GameConstants.DashDuration;
            _dashCooldown = GameConstants.DashCooldown;
            float dashSpeed = IsGrounded ? 1100f : 950f;
            Velocity = new Vector2(Facing * dashSpeed, IsGrounded ? 0 : Velocity.Y * 0.3f);
            CurrentAnimation = AnimationState.Dashing;
            AnimationTimer = 0f;
            _iframeTimer = GameConstants.DashDuration * 0.7f;
        }
        
        public void TriggerParryWindow()
        {
            _parryTimer = GameConstants.ParryWindow;
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
                ApplyStun(GameConstants.StunDuration);
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
            Velocity = new Vector2(Velocity.X * 0.3f, Velocity.Y);
            CurrentAnimation = AnimationState.Stunned;
            AnimationTimer = 0f;
            CombatDebugger.Instance.LogStun(Name, duration);
        }
        
        public void GainRage(float amount)
        {
            RageCurrent = MathHelper.Clamp(RageCurrent + amount, 0f, RageMax);
        }
        
        public bool IsInRecovery()
        {
            return _attackTimer <= 0 && _attackCooldown > 0;
        }
        
        public void SetupSprite(Texture2D spriteSheet)
        {
            Sprite = FighterAnimations.CreateFighterSprite(spriteSheet);
            Sprite.Tint = ColorBody;
        }
    }
    
    public class FighterControls
    {
        public Keys Left { get; set; }
        public Keys Right { get; set; }
        public Keys Attack { get; set; }
        public Keys Block { get; set; }
        public Keys Dash { get; set; }
        
        public Keys Jump { get; set; }
        
        public static FighterControls PlayerOne()
        {
            return new FighterControls
            {
                Left = Keys.A,
                Right = Keys.D,
                Attack = Keys.J,
                Block = Keys.K,
                Dash = Keys.Space,
                Jump = Keys.W,
            };
        }
        
        public static FighterControls None()
        {
            return new FighterControls
            {
                Left = Keys.None,
                Right = Keys.None,
                Attack = Keys.None,
                Block = Keys.None,
                Dash = Keys.None,
            };
        }
    }
}