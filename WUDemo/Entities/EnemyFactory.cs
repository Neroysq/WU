using Microsoft.Xna.Framework;
using WUDemo.Components;
using WUDemo.Core;
using WUDemo.Data;
using WUDemo.Data.Models;

using System;

namespace WUDemo.Entities
{
    public static class EnemyFactory
    {
        public static Fighter CreateEnemyForNode(MapNode node)
        {
            // Load enemy data based on node type
            string enemyType = node.Type switch
            {
                NodeType.Battle => "Basic",
                NodeType.Elite => "Elite",
                NodeType.Boss => "Boss",
                _ => "Basic"
            };
            
            EnemyData enemyData = DataManager.GetEnemy(enemyType);
            GameSettings settings = DataManager.GetGameSettings();
            
            Console.WriteLine($"Creating {enemyType} enemy with MoveSpeed: {enemyData.MoveSpeed}");
            
            return new Fighter
            {
                Name = enemyData.Name,
                Position = new Vector2(settings.ViewWidth - 360, settings.GroundY),
                Facing = -1,
                ColorBody = enemyData.ColorBody,
                ColorAccent = enemyData.ColorAccent,
                IsAI = true,
                HealthMax = enemyData.HealthMax,
                HealthCurrent = enemyData.HealthMax,
                PostureMax = enemyData.PostureMax,
                PostureCurrent = enemyData.PostureMax,
                AttackDamage = enemyData.AttackDamage,
                AttackPostureDamage = enemyData.AttackPostureDamage,
                AttackRange = enemyData.AttackRange,
                MoveSpeed = enemyData.MoveSpeed,
                JumpForce = enemyData.JumpForce,
                Gravity = enemyData.Gravity,
                HalfWidth = enemyData.HalfWidth,
                Height = enemyData.Height,
                AttackDuration = enemyData.AttackDuration,
                AttackActiveStart = 0.10f,
                AttackActiveEnd = 0.18f,
                ParryWindow = settings.ParryWindow,
                StunDuration = settings.StunDuration,
                Controls = FighterControls.None()
            };
        }
        
        public static Fighter CreatePlayer()
        {
            // Load Hu character data for the player
            CharacterData characterData = DataManager.GetCharacter("Hu");
            GameSettings settings = DataManager.GetGameSettings();
            
            return new Fighter
            {
                Name = characterData.Name,
                Position = new Vector2(360, settings.GroundY),
                Facing = 1,
                ColorBody = characterData.ColorBody,
                ColorAccent = characterData.ColorAccent,
                Controls = FighterControls.PlayerOne(),
                IsAI = false,
                HealthMax = characterData.HealthMax,
                HealthCurrent = characterData.HealthMax,
                PostureMax = characterData.PostureMax,
                PostureCurrent = characterData.PostureMax,
                RageMax = characterData.RageMax,
                RageCurrent = 0f,
                AttackDamage = characterData.AttackDamage,
                AttackPostureDamage = characterData.AttackPostureDamage,
                AttackRange = characterData.AttackRange,
                MoveSpeed = characterData.MoveSpeed,
                JumpForce = characterData.JumpForce,
                Gravity = characterData.Gravity,
                HalfWidth = characterData.HalfWidth,
                Height = characterData.Height,
                AttackDuration = characterData.AttackDuration,
                AttackActiveStart = characterData.AttackActiveStart,
                AttackActiveEnd = characterData.AttackActiveEnd,
                DashDuration = characterData.DashDuration,
                DashCooldown = characterData.DashCooldown,
                DashSpeed = characterData.DashSpeed,
                AirDashSpeed = characterData.AirDashSpeed,
                ParryWindow = characterData.ParryWindow,
                StunDuration = characterData.StunDuration,
                ComboWindowDuration = characterData.ComboWindow
            };
        }
    }
}