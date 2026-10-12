using UnityEngine;

public class TutorialMenuController : SceneSingleton<TutorialMenuController>
{
	[SerializeField]
	private bool ShowTutorial = true;

	[SerializeField]
	private int tutorialShowCount = 2;

	[SerializeField]
	private int tutorialOnScreenDuration = 3;

	[SerializeField]
	private TweenDuration tutorialTweenDuration = TweenDuration.Very_Short;

	[Space]
	[SerializeField]
	private GameObject moveTutorial;

	[SerializeField]
	private GameObject shootTutorial;

	[SerializeField]
	private GameObject boostTutorial;

	[SerializeField]
	private GameObject radarTutorial;

	[SerializeField]
	private GameObject buildTutorial;

	[SerializeField]
	private GameObject runTutorial;

	private void Start()
	{
		moveTutorial.SetActive(value: false);
		shootTutorial.SetActive(value: false);
		boostTutorial.SetActive(value: false);
		radarTutorial.SetActive(value: false);
		buildTutorial.SetActive(value: false);
		runTutorial.SetActive(value: false);
	}

	public void StartTutorial()
	{
		ShowMoveTutorial();
		ShowShootTutorial();
		TweenController.DelayedCall(20f, () =>
		{
			ShowRadarTutorial();
		});
	}

	public void ShowMoveTutorial()
	{
		AnimateTutoiral(moveTutorial, "MoveTutorial");
	}

	public void ShowShootTutorial()
	{
		AnimateTutoiral(shootTutorial, "ShootTutorial");
	}

	public void ShowBuildTutorial()
	{
		AnimateTutoiral(buildTutorial, "BuildTutorial");
	}

	public void ShowBoostTutorial()
	{
		AnimateTutoiral(boostTutorial, "BoostTutorial");
	}

	public void ShowRadarTutorial()
	{
		AnimateTutoiral(radarTutorial, "RadarTutorial");
	}

	public void ShowRunTutorial()
	{
		AnimateTutoiral(runTutorial, "RunTutorial");
	}

	private void AnimateTutoiral(GameObject obj, string text)
	{
		if (obj.activeInHierarchy || !CanShowTutorial(text))
		{
			return;
		}
		obj.SetActive(value: true);
		TweenController.ScaleV3(obj.transform, 0f, 1f, tutorialTweenDuration, ignoreTimeScale: true, () =>
		{
			TweenController.DelayedCall(tutorialOnScreenDuration, () =>
			{
				TweenController.ScaleV3(obj.transform, 1f, 0f, tutorialTweenDuration, ignoreTimeScale: true, () =>
				{
					obj.SetActive(value: false);
				});
			}, ignoreTimeScale: true);
		});
	}

	private bool CanShowTutorial(string text)
	{
		int num = FBPP.GetInt(text);
		num++;
		FBPP.SetInt(text, num);
		SaveSystem.SaveGame();
		return num <= tutorialShowCount;
	}
}
