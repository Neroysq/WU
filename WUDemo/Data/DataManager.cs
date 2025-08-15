using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using Microsoft.Xna.Framework;
using WUDemo.Data.Models;

namespace WUDemo.Data
{
    public static class DataManager
    {
        private static Dictionary<string, CharacterData> _characters = new Dictionary<string, CharacterData>();
        private static Dictionary<string, EnemyData> _enemies = new Dictionary<string, EnemyData>();
        private static GameSettings _gameSettings;
        
        private static readonly JsonSerializerOptions _jsonOptions = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true,
            ReadCommentHandling = JsonCommentHandling.Skip,
            AllowTrailingCommas = true
        };
        
        public static void Initialize()
        {
            LoadGameSettings();
            LoadCharacters();
            LoadEnemies();
        }
        
        private static void LoadGameSettings()
        {
            try
            {
                string path = Path.Combine("Data", "Settings", "GameSettings.json");
                if (File.Exists(path))
                {
                    string json = File.ReadAllText(path);
                    _gameSettings = JsonSerializer.Deserialize<GameSettings>(json, _jsonOptions);
                    Console.WriteLine("Loaded game settings");
                }
                else
                {
                    Console.WriteLine($"GameSettings.json not found at {path}, using defaults");
                    _gameSettings = GetDefaultGameSettings();
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error loading game settings: {ex.Message}");
                _gameSettings = GetDefaultGameSettings();
            }
        }
        
        private static void LoadCharacters()
        {
            string charactersPath = Path.Combine("Data", "Characters");
            if (!Directory.Exists(charactersPath))
            {
                Console.WriteLine($"Characters directory not found at {charactersPath}");
                return;
            }
            
            foreach (string file in Directory.GetFiles(charactersPath, "*.json"))
            {
                try
                {
                    string json = File.ReadAllText(file);
                    var character = JsonSerializer.Deserialize<CharacterData>(json, _jsonOptions);
                    if (character != null && !string.IsNullOrEmpty(character.Name))
                    {
                        _characters[character.Name] = character;
                        Console.WriteLine($"Loaded character: {character.Name}");
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Error loading character from {file}: {ex.Message}");
                }
            }
        }
        
        private static void LoadEnemies()
        {
            string enemiesPath = Path.Combine("Data", "Enemies");
            if (!Directory.Exists(enemiesPath))
            {
                Console.WriteLine($"Enemies directory not found at {enemiesPath}");
                return;
            }
            
            foreach (string file in Directory.GetFiles(enemiesPath, "*.json"))
            {
                try
                {
                    string json = File.ReadAllText(file);
                    var enemy = JsonSerializer.Deserialize<EnemyData>(json, _jsonOptions);
                    if (enemy != null && !string.IsNullOrEmpty(enemy.Type))
                    {
                        _enemies[enemy.Type] = enemy;
                        Console.WriteLine($"Loaded enemy type: {enemy.Type} - MoveSpeed: {enemy.MoveSpeed}");
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Error loading enemy from {file}: {ex.Message}");
                }
            }
        }
        
        public static CharacterData GetCharacter(string name)
        {
            if (_characters.TryGetValue(name, out var character))
            {
                return character;
            }
            
            Console.WriteLine($"Character '{name}' not found, returning default");
            return GetDefaultCharacterData();
        }
        
        public static EnemyData GetEnemy(string type)
        {
            if (_enemies.TryGetValue(type, out var enemy))
            {
                return enemy;
            }
            
            Console.WriteLine($"Enemy type '{type}' not found, returning default");
            return GetDefaultEnemyData();
        }
        
        public static GameSettings GetGameSettings()
        {
            return _gameSettings ?? GetDefaultGameSettings();
        }
        
        private static CharacterData GetDefaultCharacterData()
        {
            return new CharacterData
            {
                Name = "Default",
                Description = "Default character",
                MoveSpeed = 420f,
                JumpForce = 750f,
                Gravity = 2800f,
                DashSpeed = 1100f,
                AirDashSpeed = 950f,
                HealthMax = 100f,
                PostureMax = 100f,
                RageMax = 100f,
                PostureRecoveryRate = 12f,
                AttackDamage = 12f,
                AttackPostureDamage = 22f,
                AttackRange = 72f,
                AttackDuration = 0.35f,
                AttackActiveStart = 0.10f,
                AttackActiveEnd = 0.18f,
                DashDuration = 0.16f,
                DashCooldown = 0.60f,
                ParryWindow = 0.12f,
                StunDuration = 0.7f,
                ComboWindow = 0.5f,
                ColorBody = new Color(110, 185, 255),
                ColorAccent = new Color(60, 120, 210),
                HalfWidth = 22f,
                Height = 88f
            };
        }
        
        private static EnemyData GetDefaultEnemyData()
        {
            return new EnemyData
            {
                Type = "Basic",
                Name = "Enemy",
                Description = "Default enemy",
                MoveSpeed = 380f,
                JumpForce = 700f,
                Gravity = 2800f,
                HealthMax = 90f,
                PostureMax = 100f,
                PostureRecoveryRate = 10f,
                AttackDamage = 10f,
                AttackPostureDamage = 24f,
                AttackRange = 68f,
                AttackDuration = 0.40f,
                TelegraphDuration = 0.35f,
                AggressionLevel = 0.5f,
                ReactionTime = 0.3f,
                AttackCooldown = 1.2f,
                BlockChance = 0.25f,
                DodgeChance = 0.15f,
                ColorBody = new Color(255, 120, 120),
                ColorAccent = new Color(210, 60, 60),
                HalfWidth = 22f,
                Height = 88f
            };
        }
        
        private static GameSettings GetDefaultGameSettings()
        {
            return new GameSettings
            {
                ViewWidth = 1280,
                ViewHeight = 720,
                TargetFPS = 60,
                GroundY = 580f,
                WorldBoundsLeft = 80f,
                WorldBoundsRight = 1200f,
                DefaultPostureRecoveryRate = 12f,
                ParryWindow = 0.12f,
                StunDuration = 0.7f,
                CameraShakeDecay = 20f,
                TimeScaleRecovery = 0.08f,
                MaxParticles = 100,
                DamageNumberLifetime = 1f,
                DamageNumberSpeed = 60f,
                DamageNumberGravity = 120f
            };
        }
        
        public static void ReloadData()
        {
            _characters.Clear();
            _enemies.Clear();
            _gameSettings = null;
            Initialize();
        }
    }
}