using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
[InitializeOnLoad]
public static class RecoveryProjectStartup
{
    static RecoveryProjectStartup()
    {
        EditorApplication.delayCall += () => {
            var intro=AssetDatabase.LoadAssetAtPath<SceneAsset>("Assets/Scenes/IntroScene.unity");
            if(intro!=null) EditorSceneManager.playModeStartScene=intro;
        };
    }
    [MenuItem("Recovery/Open Startup Scene")]
    static void OpenStartup() { EditorSceneManager.OpenScene("Assets/Scenes/IntroScene.unity"); }
}
