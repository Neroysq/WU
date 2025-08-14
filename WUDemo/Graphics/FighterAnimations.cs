using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using System.Collections.Generic;
using WUDemo.Components;

namespace WUDemo.Graphics
{
    public static class FighterAnimations
    {
        public static AnimatedSprite CreateFighterSprite(Texture2D spriteSheet)
        {
            var sprite = new AnimatedSprite(spriteSheet, new Vector2(0.5f, 1f)); // Origin at bottom-center
            
            // For now, we'll use the full texture as a single frame for each animation
            // In a real implementation, you'd have a proper sprite sheet with multiple frames
            int width = spriteSheet.Width;
            int height = spriteSheet.Height;
            
            // Idle animation - slight bobbing effect with single frame
            sprite.AddAnimation("Idle", new Animation("Idle", 
                new List<Rectangle> { new Rectangle(0, 0, width, height) }, 
                0.1f, true));
            
            // Walking animation - would have multiple frames in a real sprite sheet
            sprite.AddAnimation("Walking", new Animation("Walking",
                new List<Rectangle> { new Rectangle(0, 0, width, height) },
                0.1f, true));
            
            // Jumping animation
            sprite.AddAnimation("Jumping", new Animation("Jumping",
                new List<Rectangle> { new Rectangle(0, 0, width, height) },
                0.1f, false));
            
            // Falling animation
            sprite.AddAnimation("Falling", new Animation("Falling",
                new List<Rectangle> { new Rectangle(0, 0, width, height) },
                0.1f, true));
            
            // Landing animation
            sprite.AddAnimation("Landing", new Animation("Landing",
                new List<Rectangle> { new Rectangle(0, 0, width, height) },
                0.05f, false));
            
            // Attack animation - quick strike
            sprite.AddAnimation("Attacking", new Animation("Attacking",
                new List<Rectangle> { new Rectangle(0, 0, width, height) },
                0.08f, false));
            
            // Block animation
            sprite.AddAnimation("Blocking", new Animation("Blocking",
                new List<Rectangle> { new Rectangle(0, 0, width, height) },
                0.1f, true));
            
            // Dash animation
            sprite.AddAnimation("Dashing", new Animation("Dashing",
                new List<Rectangle> { new Rectangle(0, 0, width, height) },
                0.05f, false));
            
            // Hit reaction animation
            sprite.AddAnimation("HitReaction", new Animation("HitReaction",
                new List<Rectangle> { new Rectangle(0, 0, width, height) },
                0.1f, false));
            
            // Stunned animation
            sprite.AddAnimation("Stunned", new Animation("Stunned",
                new List<Rectangle> { new Rectangle(0, 0, width, height) },
                0.15f, true));
            
            return sprite;
        }
        
        public static void UpdateFighterAnimation(Fighter fighter, float dt)
        {
            if (fighter.Sprite == null) return;
            
            // Map AnimationState to sprite animation names
            string targetAnimation = fighter.CurrentAnimation.ToString();
            
            // Only change animation if it's different
            if (fighter.Sprite.CurrentAnimationName != targetAnimation)
            {
                fighter.Sprite.PlayAnimation(targetAnimation);
            }
            
            // Update the sprite animation
            fighter.Sprite.Update(dt);
            
            // Apply dynamic effects based on state
            ApplyDynamicEffects(fighter, dt);
        }
        
        private static void ApplyDynamicEffects(Fighter fighter, float dt)
        {
            if (fighter.Sprite == null) return;
            
            // Dynamic tinting based on state
            switch (fighter.CurrentAnimation)
            {
                case AnimationState.Attacking:
                    Color attackColor = fighter.ComboCount > 2 ? Color.Orange : Color.Yellow;
                    fighter.Sprite.Tint = Color.Lerp(fighter.ColorBody, attackColor, 0.3f);
                    break;
                    
                case AnimationState.Blocking:
                    fighter.Sprite.Tint = Color.Lerp(fighter.ColorBody, Color.Cyan, 0.2f);
                    break;
                    
                case AnimationState.HitReaction:
                    fighter.Sprite.Tint = Color.Lerp(fighter.ColorBody, Color.Red, 0.4f);
                    break;
                    
                case AnimationState.Dashing:
                    fighter.Sprite.Tint = Color.Lerp(fighter.ColorBody, new Color(150, 200, 255), 0.4f);
                    break;
                    
                case AnimationState.Jumping:
                case AnimationState.Falling:
                    fighter.Sprite.Tint = Color.Lerp(fighter.ColorBody, new Color(200, 220, 255), 0.2f);
                    break;
                    
                default:
                    fighter.Sprite.Tint = fighter.ColorBody;
                    break;
            }
            
            // Flash effect when invulnerable
            if (fighter.IsInvulnerable)
            {
                float flash = (float)System.Math.Sin(fighter.AnimationTimer * 30f) * 0.3f + 0.7f;
                var currentTint = fighter.Sprite.Tint;
                fighter.Sprite.Tint = new Color(
                    (byte)(currentTint.R * flash),
                    (byte)(currentTint.G * flash),
                    (byte)(currentTint.B * flash),
                    currentTint.A
                );
            }
            
            // Dynamic scaling for squash and stretch
            float scaleX = 1f;
            float scaleY = 1f;
            
            if (!fighter.IsGrounded)
            {
                float velocityFactor = MathHelper.Clamp(fighter.Velocity.Y / 1000f, -0.3f, 0.3f);
                scaleY = 1f + velocityFactor;
                scaleX = 1f - velocityFactor * 0.5f;
            }
            else if (fighter.CurrentAnimation == AnimationState.Landing)
            {
                scaleY = 0.85f + fighter.AnimationTimer * 0.75f;
                scaleX = 1.15f - fighter.AnimationTimer * 0.75f;
            }
            else if (fighter.CurrentAnimation == AnimationState.Dashing)
            {
                scaleX = 1.3f;
                scaleY = 0.8f;
            }
            else if (fighter.CurrentAnimation == AnimationState.Attacking)
            {
                float attackProgress = fighter.AnimationTimer / 0.3f; // Assuming 0.3s attack duration
                scaleX = 1f + System.MathF.Sin(attackProgress * System.MathF.PI) * 0.2f;
                scaleY = 1f - System.MathF.Sin(attackProgress * System.MathF.PI) * 0.1f;
            }
            
            // Apply composite scale
            fighter.Sprite.Scale = (scaleX + scaleY) / 2f; // Average for uniform scaling
            
            // Rotation for dramatic effects
            if (fighter.CurrentAnimation == AnimationState.Stunned)
            {
                fighter.Sprite.Rotation = System.MathF.Sin(fighter.AnimationTimer * 8f) * 0.1f;
            }
            else
            {
                fighter.Sprite.Rotation = 0f;
            }
        }
    }
}