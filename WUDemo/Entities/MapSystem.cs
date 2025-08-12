using System;
using System.Collections.Generic;
using System.Linq;

namespace WUDemo.Entities
{
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
        public List<int> Next { get; set; } = new List<int>();
    }
    
    public class RunState
    {
        public List<MapNode> Nodes { get; private set; } = new List<MapNode>();
        public int CurrentNodeId { get; private set; }
        public int MaxTier { get; private set; }
        
        public static RunState CreateSimpleThreeTier()
        {
            var run = new RunState();
            run.Nodes = new List<MapNode>
            {
                new MapNode { Id = 0, Tier = 0, Type = NodeType.Event, Next = { 1, 2 } },
                new MapNode { Id = 1, Tier = 1, Type = NodeType.Battle, Next = { 3 } },
                new MapNode { Id = 2, Tier = 1, Type = NodeType.Battle, Next = { 4 } },
                new MapNode { Id = 3, Tier = 2, Type = NodeType.Elite, Next = { 5 } },
                new MapNode { Id = 4, Tier = 2, Type = NodeType.Treasure, Next = { 5 } },
                new MapNode { Id = 5, Tier = 3, Type = NodeType.Boss, Next = { } },
            };
            run.CurrentNodeId = 0;
            run.MaxTier = 3;
            return run;
        }
        
        public MapNode GetNode(int id)
        {
            return Nodes.FirstOrDefault(n => n.Id == id);
        }
        
        public MapNode GetCurrentNode()
        {
            return GetNode(CurrentNodeId);
        }
        
        public List<MapNode> GetAvailableNext()
        {
            var current = GetCurrentNode();
            var list = new List<MapNode>();
            foreach (var id in current.Next)
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
            GetCurrentNode().Cleared = true;
        }
        
        public int CountInTier(int tier)
        {
            return Nodes.Count(n => n.Tier == tier);
        }
        
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
        
        public void Apply(Components.Fighter fighter)
        {
            switch (Id)
            {
                case "atk_up":
                    fighter.AttackDamage += 4f;
                    break;
                case "posture_up":
                    fighter.PostureMax += 25f;
                    fighter.PostureCurrent += 25f;
                    break;
                case "rage_gain":
                    fighter.AttackPostureDamage += 6f;
                    break;
                case "dash_cd":
                    fighter.MoveSpeed += 40f;
                    break;
            }
        }
        
        public static RewardOption Random(string exclude = null)
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
}