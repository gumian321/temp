using System;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class ScenesManager : Singleton<ScenesManager>
{
	private static string mainMenuSceneName = "MainMenuScene";

	private static string gameSceneName = "GameScene";

	private static string introScene = "IntroScene";

	[SerializeField]
	private Image fadeSceneBackground;

	public void GoToScene(int sceneNumber)
	{
		FadeTranstion(() =>
		{
			SceneManager.LoadScene(sceneNumber);
		});
	}

	public void GoToSceneName(string sceneName)
	{
		FadeTranstion(() =>
		{
			SceneManager.LoadScene(sceneName);
		});
	}

	public void GoToMainMenuScene()
	{
		FadeTranstion(() =>
		{
			SceneManager.LoadScene(mainMenuSceneName);
		});
	}

	public void GoToGameScene()
	{
		FadeTranstion(() =>
		{
			SceneManager.LoadScene(gameSceneName);
		});
	}

	public void GoToIntroScene()
	{
		FadeTranstion(() =>
		{
			SceneManager.LoadScene(introScene);
		});
	}

	public static void ExitApplication()
	{
		Application.Quit();
	}

	private void FadeTranstion(Action OnComplete)
	{
		ImageSystem.Alphalizer(fadeSceneBackground, 1f, TweenDuration.Super_Short, IgnoreTimeScale: true, () =>
		{
			ImageSystem.Alphalizer(fadeSceneBackground, 0f, TweenDuration.Short, IgnoreTimeScale: true);
			OnComplete();
		});
	}
}
