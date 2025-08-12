using Microsoft.Xna.Framework;
using WUDemo.Components;
using WUDemo.Core;

using System;

namespace WUDemo.Entities
{
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
            
            Color bodyColor = node.Type switch
            {
                NodeType.Boss => new Color(255, 90, 130),
                NodeType.Elite => new Color(255, 170, 110),
                _ => new Color(255, 120, 120)
            };
            
            string name = node.Type switch
            {
                NodeType.Boss => "Boss",
                NodeType.Elite => "Elite",
                _ => "Enemy"
            };
            
            return new Fighter
            {
                Name = name,
                Position = new Vector2(GameConstants.ViewWidth - 360, GameConstants.GroundY),
                Facing = -1,
                ColorBody = bodyColor,
                ColorAccent = new Color(210, 60, 60),
                IsAI = true,
                HealthMax = hp,
                HealthCurrent = hp,
                AttackDamage = dmg,
                PostureMax = posture,
                PostureCurrent = posture,
                AttackPostureDamage = 24f,
                MoveSpeed = 380f,
                Controls = FighterControls.None()
            };
        }
        
        public static Fighter CreatePlayer()
        {
            return new Fighter
            {
                Name = "Player",
                Position = new Vector2(360, GameConstants.GroundY),
                Facing = 1,
                ColorBody = new Color(110, 185, 255),
                ColorAccent = new Color(60, 120, 210),
                Controls = FighterControls.PlayerOne(),
                IsAI = false
            };
        }
    }
}