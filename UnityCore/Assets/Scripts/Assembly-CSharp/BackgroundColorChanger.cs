using System.Collections.Generic;
using UnityEngine;

public class BackgroundColorChanger : SceneSingleton<BackgroundColorChanger>
{
	[SerializeField]
	private Camera mainCamera;

	[SerializeField]
	private List<BackgroundColorPreset> backgroundColorPresetsList;

	private List<Color> colorsList;

	private int index = -1;

	private float delay;

	public void SetBackgroundColor()
	{
		colorsList = backgroundColorPresetsList[Random.Range(0, backgroundColorPresetsList.Count)].colorsList;
		mainCamera.backgroundColor = colorsList[0];
	}

	public void StartBackgroundColorChange(float gameTime)
	{
		delay = gameTime / (float)(colorsList.Count - 1);
		index = 0;
		LoadNextColor();
	}

	public void ResetBackgroundColor()
	{
		colorsList = backgroundColorPresetsList[Random.Range(0, backgroundColorPresetsList.Count)].colorsList;
		index = 0;
		LoadNextColor();
	}

	public void LoadNextColor()
	{
		index++;
		if (index < colorsList.Count)
		{
			TweenController.DOCameraColor(mainCamera, colorsList[index], delay, ignoreTimeScale: false, () =>
			{
				LoadNextColor();
			});
		}
	}
}
