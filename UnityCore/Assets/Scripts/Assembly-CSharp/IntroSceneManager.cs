using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class IntroSceneManager : SceneSingleton<IntroSceneManager>
{
	[SerializeField]
	private TweenDuration animationDuration;

	[SerializeField]
	private List<IntroObject> IntroObjectsList;

	private bool MenuSceneLoaded;

	private void Start()
	{
		Singleton<InputDataStore>.Instance.SetLoadingActionMap();
		PlayerPrefs.SetInt("GoToLab", 0);
		Singleton<TestingManager>.Instance.DisableTestingManager();
		StartCoroutine(PlayIntroAnimation());
	}

	private IEnumerator PlayIntroAnimation()
	{
		int index = 0;
		foreach (IntroObject introObjects in IntroObjectsList)
		{
			introObjects.HideObject();
		}
		WaitForSeconds delay = new WaitForSeconds(TweenDataStore.GetTweenDuration(animationDuration) * 2f);
		do
		{
			IntroObjectsList[index].AnimateObject(animationDuration);
			yield return delay;
			index++;
		}
		while (index < IntroObjectsList.Count);
		LoadMainMenuScene();
	}

	public void LoadMainMenuScene()
	{
		if (!MenuSceneLoaded)
		{
			MenuSceneLoaded = true;
			Singleton<ScenesManager>.Instance.GoToMainMenuScene();
		}
	}
}
