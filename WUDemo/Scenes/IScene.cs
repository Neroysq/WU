using Microsoft.Xna.Framework;
using Microsoft.Xna.Framework.Graphics;
using Microsoft.Xna.Framework.Input;

namespace WUDemo.Scenes
{
    public interface IScene
    {
        void Initialize();
        void Update(GameTime gameTime, KeyboardState kb, KeyboardState prevKb);
        void Draw(SpriteBatch spriteBatch);
        void OnEnter();
        void OnExit();
    }
    
    public enum SceneType
    {
        Map,
        Combat,
        Reward,
        GameOver
    }
}