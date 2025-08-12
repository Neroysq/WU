using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Input;
using System;
using WUDemo.Components;
using WUDemo.Core;

namespace WUDemo.Systems
{
    public class CombatSystem
    {
        private readonly Random _rng = new Random();
        
        public event Action<Vector2, int, Color> OnSpawnParticles;
        public event Action<float> OnCameraShake;
        public event Action<float, float> OnSlowMotion;
        public event Action<string, float> OnShowFeedback;
        
        public void UpdatePlayer(Fighter fighter, KeyboardState kb, KeyboardState prevKb, float dt)
        {
            // Movement
            float move = 0f;
            if (kb.IsKeyDown(fighter.Controls.Left)) move -= 1f;
            if (kb.IsKeyDown(fighter.Controls.Right)) move += 1f;
            bool isTryingToMove = Math.Abs(move) > 0.01f;
            
            float targetSpeed = isTryingToMove ? move * fighter.MoveSpeed : 0f;
            fighter.Velocity = new Vector2(
                MathHelper.Lerp(fighter.Velocity.X, targetSpeed, 0.25f),
                fighter.Velocity.Y
            );
            
            // Update movement animation
            if (isTryingToMove && fighter.CurrentAnimation == AnimationState.Idle)
            {
                fighter.CurrentAnimation = AnimationState.Walking;
                fighter.AnimationTimer = 0f;
            }
            
            // Dash
            if (Pressed(kb, prevKb, fighter.Controls.Dash) && fighter.CanDash())
            {
                fighter.StartDash();
                OnSpawnParticles?.Invoke(fighter.Position, 8, new Color(200, 200, 255));
                OnCameraShake?.Invoke(3f);
            }
            
            // Attack
            if (Pressed(kb, prevKb, fighter.Controls.Attack) && fighter.CanAttack())
            {
                fighter.StartAttack();
                var attackPos = new Vector2(
                    fighter.Position.X + fighter.Facing * fighter.HalfWidth,
                    fighter.Position.Y - fighter.Height * 0.4f
                );
                OnSpawnParticles?.Invoke(attackPos, 6, new Color(255, 255, 200));
                OnCameraShake?.Invoke(2f);
            }
            
            // Block/Parry
            fighter.IsBlocking = kb.IsKeyDown(fighter.Controls.Block);
            if (Pressed(kb, prevKb, fighter.Controls.Block))
            {
                fighter.TriggerParryWindow();
                fighter.CurrentAnimation = AnimationState.Blocking;
                fighter.AnimationTimer = 0f;
            }
            else if (fighter.IsBlocking && fighter.CurrentAnimation == AnimationState.Idle)
            {
                fighter.CurrentAnimation = AnimationState.Blocking;
                fighter.AnimationTimer = 0f;
            }
            
            fighter.UpdateTimers(dt);
            fighter.Position += fighter.Velocity * dt;
            fighter.Position = new Vector2(fighter.Position.X, GameConstants.GroundY);
        }
        
        public void UpdateAI(Fighter ai, Fighter target, float dt)
        {
            if (!ai.IsAI) return;
            
            ai.UpdateTimers(dt);
            
            float distance = target.Position.X - ai.Position.X;
            float abs = Math.Abs(distance);
            float direction = Math.Sign(distance);
            
            if (ai.IsInRecovery() || ai.IsStunned)
            {
                ai.Velocity = new Vector2(
                    MathHelper.Lerp(ai.Velocity.X, 0, 0.2f),
                    ai.Velocity.Y
                );
            }
            else
            {
                if (abs > ai.AttackRange * 0.85f)
                {
                    ai.Velocity = new Vector2(
                        MathHelper.Lerp(ai.Velocity.X, direction * ai.MoveSpeed * 0.6f, 0.2f),
                        ai.Velocity.Y
                    );
                }
                else
                {
                    ai.Velocity = new Vector2(
                        MathHelper.Lerp(ai.Velocity.X, 0, 0.3f),
                        ai.Velocity.Y
                    );
                    if (ai.CanAttack()) ai.StartTelegraph();
                }
            }
            
            // Attack after telegraph
            if (ai.IsTelegraphing && ai.TelegraphTimer <= 0)
            {
                ai.StartAttack();
            }
            
            ai.Position += ai.Velocity * dt;
            ai.Position = new Vector2(ai.Position.X, GameConstants.GroundY);
        }
        
        public void ResolveHits(Fighter attacker, Fighter defender)
        {
            if (!attacker.IsHitActive()) return;
            
            bool inRange = Math.Abs(defender.Position.X - attacker.Position.X) <= 
                           attacker.AttackRange + defender.HalfWidth;
            bool facingCorrect = Math.Sign(defender.Position.X - attacker.Position.X) == attacker.Facing;
            
            if (inRange && facingCorrect && !defender.WasHitThisSwing)
            {
                defender.WasHitThisSwing = true;
                
                bool parried = defender.ConsumeParryIfActive();
                
                if (parried)
                {
                    // Parry effects
                    attacker.ApplyPostureDamage(55);
                    attacker.ApplyStun(0.6f);
                    defender.GainRage(12);
                    OnCameraShake?.Invoke(12f);
                    
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
                
                float hpDamage = attacker.AttackDamage;
                float postureDamage = attacker.AttackPostureDamage;
                
                if (defender.IsBlocking)
                {
                    hpDamage *= 0.2f;
                    postureDamage *= 1.6f;
                    defender.GainRage(6);
                    OnShowFeedback?.Invoke("BLOCKED", 0.5f);
                }
                else
                {
                    OnShowFeedback?.Invoke("HIT", 0.3f);
                }
                
                defender.HealthCurrent -= hpDamage;
                defender.ApplyPostureDamage(postureDamage);
                
                attacker.GainRage(10);
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