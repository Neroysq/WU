using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Input;
using System;
using WUDemo.Components;
using WUDemo.Core;
using WUDemo.Debug;

namespace WUDemo.Systems
{
    public class CombatSystem
    {
        private readonly Random _rng = new Random();
        
        public event Action<Vector2, int, Color> OnSpawnParticles;
        public event Action<float> OnCameraShake;
        public event Action<float, float> OnSlowMotion;
        public event Action<string, float> OnShowFeedback;
        public event Action<Vector2, float, bool> OnDamageDealt; // position, damage, isCritical
        
        public void UpdatePlayer(Fighter fighter, KeyboardState kb, KeyboardState prevKb, float dt, Fighter enemy = null)
        {
            // Movement input
            float move = 0f;
            if (kb.IsKeyDown(fighter.Controls.Left)) move -= 1f;
            if (kb.IsKeyDown(fighter.Controls.Right)) move += 1f;
            bool isTryingToMove = Math.Abs(move) > 0.01f;
            
            float airControl = fighter.IsGrounded ? 0.25f : 0.12f;
            float targetSpeed = isTryingToMove ? move * fighter.MoveSpeed : 0f;
            
            // Prevent movement during attacks and certain states
            bool canMove = fighter.CurrentAnimation != AnimationState.Dashing && 
                          fighter.CurrentAnimation != AnimationState.Attacking &&
                          fighter.CurrentAnimation != AnimationState.Stunned;
            
            if (canMove)
            {
                fighter.Velocity = new Vector2(
                    MathHelper.Lerp(fighter.Velocity.X, targetSpeed, airControl),
                    fighter.Velocity.Y
                );
            }
            else if (fighter.CurrentAnimation == AnimationState.Attacking)
            {
                // Stop horizontal movement during attacks
                fighter.Velocity = new Vector2(
                    MathHelper.Lerp(fighter.Velocity.X, 0f, airControl * 2f),
                    fighter.Velocity.Y
                );
            }
            
            // Update movement animation
            if (fighter.IsGrounded && isTryingToMove && fighter.CurrentAnimation == AnimationState.Idle)
            {
                fighter.CurrentAnimation = AnimationState.Walking;
                fighter.AnimationTimer = 0f;
            }
            
            // Jump
            if (Pressed(kb, prevKb, fighter.Controls.Jump) && fighter.CanJump())
            {
                string jumpType = fighter.IsGrounded ? "JUMP" : "DOUBLE JUMP";
                fighter.StartJump();
                CombatDebugger.Instance.LogMovement(fighter.Name, jumpType);
                OnSpawnParticles?.Invoke(
                    fighter.Position + new Vector2(0, 5),
                    12,
                    new Color(180, 200, 255)
                );
            }
            
            // Dash
            if (Pressed(kb, prevKb, fighter.Controls.Dash) && fighter.CanDash())
            {
                int dashDirection;
                
                // Determine dash direction based on input or enemy position
                if (isTryingToMove)
                {
                    // Dash in the direction currently being pressed
                    dashDirection = move > 0 ? 1 : -1;
                    CombatDebugger.Instance.LogMovement(fighter.Name, $"DASH {(dashDirection > 0 ? "RIGHT" : "LEFT")}");
                }
                else if (enemy != null)
                {
                    // No direction pressed, dash toward enemy
                    dashDirection = enemy.Position.X > fighter.Position.X ? 1 : -1;
                    CombatDebugger.Instance.LogMovement(fighter.Name, $"DASH TOWARD ENEMY {(dashDirection > 0 ? "RIGHT" : "LEFT")}");
                }
                else
                {
                    // Fallback to current facing direction
                    dashDirection = fighter.Facing;
                    CombatDebugger.Instance.LogMovement(fighter.Name, "DASH");
                }
                
                fighter.StartDash(dashDirection);
                OnSpawnParticles?.Invoke(fighter.Position, 8, new Color(200, 200, 255));
                OnCameraShake?.Invoke(3f);
            }
            
            // Attack
            if (Pressed(kb, prevKb, fighter.Controls.Attack) && fighter.CanAttack())
            {
                fighter.StartAttack();
                
                if (fighter.ComboCount > 1)
                {
                    CombatDebugger.Instance.LogCombo(fighter.Name, fighter.ComboCount);
                }
                else
                {
                    CombatDebugger.Instance.LogMovement(fighter.Name, "ATTACK");
                }
                
                var attackPos = new Vector2(
                    fighter.Position.X + fighter.Facing * fighter.HalfWidth,
                    fighter.Position.Y - fighter.Height * 0.4f
                );
                
                int particleCount = 6 + fighter.ComboCount * 2;
                Color attackColor = fighter.ComboCount > 2 ? 
                    new Color(255, 180, 100) : new Color(255, 255, 200);
                    
                OnSpawnParticles?.Invoke(attackPos, particleCount, attackColor);
                OnCameraShake?.Invoke(2f + fighter.ComboCount * 0.5f);
                
                if (fighter.ComboCount > 2)
                {
                    OnShowFeedback?.Invoke($"COMBO x{fighter.ComboCount}!", 0.5f);
                }
            }
            
            // Block/Parry
            bool wasBlocking = fighter.IsBlocking;
            fighter.IsBlocking = kb.IsKeyDown(fighter.Controls.Block);
            if (Pressed(kb, prevKb, fighter.Controls.Block))
            {
                fighter.TriggerParryWindow();
                fighter.CurrentAnimation = AnimationState.Blocking;
                fighter.AnimationTimer = 0f;
                CombatDebugger.Instance.LogMovement(fighter.Name, "PARRY WINDOW");
            }
            else if (fighter.IsBlocking && !wasBlocking)
            {
                CombatDebugger.Instance.LogMovement(fighter.Name, "BLOCK START");
            }
            else if (!fighter.IsBlocking && wasBlocking)
            {
                CombatDebugger.Instance.LogMovement(fighter.Name, "BLOCK END");
            }
            
            if (fighter.IsBlocking && fighter.CurrentAnimation == AnimationState.Idle)
            {
                fighter.CurrentAnimation = AnimationState.Blocking;
                fighter.AnimationTimer = 0f;
            }
            
            // Gravity and physics
            if (!fighter.IsGrounded)
            {
                fighter.Velocity = new Vector2(
                    fighter.Velocity.X,
                    fighter.Velocity.Y + fighter.Gravity * dt
                );
                
                if (fighter.Velocity.Y > 0 && fighter.CurrentAnimation == AnimationState.Jumping)
                {
                    fighter.CurrentAnimation = AnimationState.Falling;
                    fighter.AnimationTimer = 0f;
                }
            }
            
            fighter.UpdateTimers(dt);
            fighter.Position += fighter.Velocity * dt;
            
            // Ground collision
            if (fighter.Position.Y >= GameConstants.GroundY)
            {
                if (!fighter.IsGrounded && fighter.Velocity.Y > 100)
                {
                    fighter.Land();
                    OnSpawnParticles?.Invoke(
                        new Vector2(fighter.Position.X, GameConstants.GroundY + 5),
                        8,
                        new Color(140, 120, 100)
                    );
                }
                fighter.Position = new Vector2(fighter.Position.X, GameConstants.GroundY);
                fighter.Velocity = new Vector2(fighter.Velocity.X, 0);
                fighter.IsGrounded = true;
            }
            else
            {
                fighter.IsGrounded = false;
            }
        }
        
        public void UpdateAI(Fighter ai, Fighter target, float dt)
        {
            if (!ai.IsAI) return;
            
            ai.UpdateTimers(dt);
            
            float distance = target.Position.X - ai.Position.X;
            float abs = Math.Abs(distance);
            float direction = Math.Sign(distance);
            float verticalDiff = target.Position.Y - ai.Position.Y;
            
            // Aggressive AI behavior
            float aggressionMultiplier = 1.2f + (1f - ai.HealthCurrent / ai.HealthMax) * 0.5f;
            
            // Debug AI state
            if (CombatDebugger.Instance.IsEnabled && _rng.NextDouble() < 0.02f) // Log occasionally
            {
                string aiState = ai.IsInRecovery() ? "RECOVERY" : 
                               ai.IsStunned ? "STUNNED" : 
                               abs > ai.AttackRange * 0.9f ? $"PURSUING (dist:{abs:F0})" : 
                               "IN_RANGE";
                CombatDebugger.Instance.LogSystem($"{ai.Name} AI: {aiState}", Color.Cyan);
            }
            
            if (ai.IsInRecovery() || ai.IsStunned)
            {
                // Retreat when recovering
                float retreatSpeed = ai.IsStunned ? 0 : -direction * ai.MoveSpeed * 0.4f;
                ai.Velocity = new Vector2(
                    MathHelper.Lerp(ai.Velocity.X, retreatSpeed, 0.2f),
                    ai.Velocity.Y
                );
            }
            else
            {
                // Aggressive pursuit
                if (abs > ai.AttackRange * 0.9f)
                {
                    ai.Velocity = new Vector2(
                        MathHelper.Lerp(ai.Velocity.X, direction * ai.MoveSpeed * aggressionMultiplier, 0.3f),
                        ai.Velocity.Y
                    );
                    
                    // Jump if target is above
                    if (verticalDiff < -50 && ai.CanJump() && _rng.NextDouble() < 0.1f)
                    {
                        ai.StartJump();
                    }
                    
                    // Dash to close distance quickly
                    if (abs > 200 && ai.CanDash() && _rng.NextDouble() < 0.05f * aggressionMultiplier)
                    {
                        ai.StartDash();
                        OnSpawnParticles?.Invoke(ai.Position, 8, new Color(255, 100, 100));
                    }
                }
                else
                {
                    // Mix-up at close range
                    if (_rng.NextDouble() < 0.02f * aggressionMultiplier)
                    {
                        // Occasional backstep
                        ai.Velocity = new Vector2(
                            MathHelper.Lerp(ai.Velocity.X, -direction * ai.MoveSpeed * 0.8f, 0.3f),
                            ai.Velocity.Y
                        );
                    }
                    else
                    {
                        ai.Velocity = new Vector2(
                            MathHelper.Lerp(ai.Velocity.X, 0, 0.3f),
                            ai.Velocity.Y
                        );
                    }
                    
                    // Attack with increased frequency based on aggression
                    float attackRoll = (float)_rng.NextDouble();
                    float attackChance = 0.25f * aggressionMultiplier;
                    
                    if (ai.CanAttack())
                    {
                        if (attackRoll < attackChance)
                        {
                            ai.StartTelegraph();
                            CombatDebugger.Instance.LogSystem($"{ai.Name} AI: ATTACK DECISION (roll:{attackRoll:F3} < chance:{attackChance:F3})", Color.Yellow);
                        }
                        else if (CombatDebugger.Instance.IsEnabled && _rng.NextDouble() < 0.1f)
                        {
                            CombatDebugger.Instance.LogSystem($"{ai.Name} AI: No attack (roll:{attackRoll:F3} >= chance:{attackChance:F3})", Color.Gray);
                        }
                    }
                    else if (CombatDebugger.Instance.IsEnabled && _rng.NextDouble() < 0.05f)
                    {
                        string reason = ai.IsStunned ? "stunned" : 
                                      ai.IsInRecovery() ? "recovery" : 
                                      ai.IsTelegraphing ? "telegraphing" : "unknown";
                        CombatDebugger.Instance.LogSystem($"{ai.Name} AI: Can't attack ({reason})", Color.Gray);
                    }
                    
                    // Block incoming attacks
                    if (target.IsHitActive() && _rng.NextDouble() < 0.4f)
                    {
                        ai.IsBlocking = true;
                        ai.TriggerParryWindow();
                    }
                    else
                    {
                        ai.IsBlocking = false;
                    }
                }
            }
            
            // Attack after telegraph
            if (ai.IsTelegraphing && ai.TelegraphTimer <= 0)
            {
                CombatDebugger.Instance.LogSystem($"{ai.Name}: Telegraph complete (timer:{ai.TelegraphTimer:F3}), executing attack", Color.Yellow);
                ai.StartAttack();
                
                if (ai.ComboCount > 1)
                {
                    CombatDebugger.Instance.LogCombo(ai.Name, ai.ComboCount);
                }
                else
                {
                    CombatDebugger.Instance.LogMovement(ai.Name, "AI ATTACK");
                }
                
                // Chain attacks for combos
                if (ai.ComboCount > 0 && _rng.NextDouble() < 0.3f * aggressionMultiplier)
                {
                    ai.ComboWindow = 0.4f;
                }
            }
            
            // Gravity for AI
            if (!ai.IsGrounded)
            {
                ai.Velocity = new Vector2(
                    ai.Velocity.X,
                    ai.Velocity.Y + ai.Gravity * dt
                );
            }
            
            ai.Position += ai.Velocity * dt;
            
            // Ground collision for AI
            if (ai.Position.Y >= GameConstants.GroundY)
            {
                if (!ai.IsGrounded && ai.Velocity.Y > 100)
                {
                    ai.Land();
                }
                ai.Position = new Vector2(ai.Position.X, GameConstants.GroundY);
                ai.Velocity = new Vector2(ai.Velocity.X, 0);
                ai.IsGrounded = true;
            }
            else
            {
                ai.IsGrounded = false;
            }
        }
        
        public void ResolveHits(Fighter attacker, Fighter defender)
        {
            if (!attacker.IsHitActive()) return;
            
            // Check if defender is invulnerable
            if (defender.IsInvulnerable) return;
            
            bool inRange = Math.Abs(defender.Position.X - attacker.Position.X) <= 
                           attacker.AttackRange + defender.HalfWidth;
            bool verticalRange = Math.Abs(defender.Position.Y - attacker.Position.Y) <= defender.Height + 20;
            bool facingCorrect = Math.Sign(defender.Position.X - attacker.Position.X) == attacker.Facing;
            
            if (inRange && verticalRange && facingCorrect && !attacker.WasHitThisSwing)
            {
                attacker.WasHitThisSwing = true;
                
                bool parried = defender.ConsumeParryIfActive();
                
                if (parried)
                {
                    // Parry effects
                    attacker.ApplyPostureDamage(55);
                    attacker.ApplyStun(0.6f);
                    defender.GainRage(12);
                    OnCameraShake?.Invoke(12f);
                    
                    CombatDebugger.Instance.LogAttack(attacker.Name, 0, false, false, true);
                    CombatDebugger.Instance.LogStun(attacker.Name, 0.6f);
                    
                    // Parry particle effect
                    var parryPos = defender.Position + new Vector2(defender.Facing * -6, -defender.Height + 24);
                    for (int i = 0; i < 24; i++)
                    {
                        float angle = (i / 24f) * MathF.PI * 2f;
                        var sparkPos = parryPos + new Vector2(MathF.Cos(angle), MathF.Sin(angle)) * 30f;
                        OnSpawnParticles?.Invoke(sparkPos, 2, new Color(255, 230, 90));
                    }
                    
                    OnSlowMotion?.Invoke(0.55f, 0.30f);
                    OnShowFeedback?.Invoke("PARRY!", 0.8f);
                    return;
                }
                
                float comboDamageBonus = 1f + (attacker.ComboCount - 1) * 0.15f;
                float hpDamage = attacker.AttackDamage * comboDamageBonus;
                float postureDamage = attacker.AttackPostureDamage * comboDamageBonus;
                
                if (defender.IsBlocking)
                {
                    hpDamage *= 0.2f;
                    postureDamage *= 1.6f;
                    defender.GainRage(6);
                    OnShowFeedback?.Invoke("BLOCKED", 0.5f);
                    CombatDebugger.Instance.LogAttack(attacker.Name, hpDamage, true, true, false);
                }
                else
                {
                    OnShowFeedback?.Invoke("HIT", 0.3f);
                    CombatDebugger.Instance.LogAttack(attacker.Name, hpDamage, true, false, false);
                }
                
                defender.HealthCurrent -= hpDamage;
                defender.ApplyPostureDamage(postureDamage);
                
                // Spawn damage number
                var damagePos = defender.Position + new Vector2(0, -defender.Height - 20);
                bool isCritical = attacker.ComboCount > 2;
                OnDamageDealt?.Invoke(damagePos, hpDamage, isCritical);
                
                // Log posture break if it happened
                if (defender.PostureCurrent <= 0 && !defender.IsStunned)
                {
                    CombatDebugger.Instance.LogSystem($"{defender.Name} posture broken!", Color.Purple);
                }
                
                // Knockback
                float knockback = defender.IsBlocking ? 150f : 300f;
                if (!defender.IsGrounded) knockback *= 1.3f;
                defender.Velocity = new Vector2(
                    attacker.Facing * knockback,
                    defender.IsGrounded ? -100f : defender.Velocity.Y - 200f
                );
                
                attacker.GainRage(10 + attacker.ComboCount * 2);
                defender.GainRage(4);
                
                if (!defender.IsStunned)
                {
                    defender.CurrentAnimation = AnimationState.HitReaction;
                    defender.AnimationTimer = 0f;
                }
                
                if (defender.HealthCurrent < 0) defender.HealthCurrent = 0;
                
                OnCameraShake?.Invoke(6f);
                OnSpawnParticles?.Invoke(
                    defender.Position + new Vector2(defender.Facing * -4, -defender.Height + 28), 
                    10, 
                    new Color(255, 190, 160)
                );
            }
        }
        
        public void UpdateFacing(Fighter player, Fighter enemy)
        {
            player.Facing = player.Position.X <= enemy.Position.X ? 1 : -1;
            enemy.Facing = -player.Facing;
        }
        
        public void ClampWorldBounds(Fighter fighter)
        {
            fighter.Position = new Vector2(
                Math.Clamp(fighter.Position.X, GameConstants.WorldBoundsLeft, GameConstants.WorldBoundsRight),
                fighter.Position.Y
            );
        }
        
        private bool Pressed(KeyboardState current, KeyboardState previous, Keys key)
        {
            return current.IsKeyDown(key) && !previous.IsKeyDown(key);
        }
    }
}