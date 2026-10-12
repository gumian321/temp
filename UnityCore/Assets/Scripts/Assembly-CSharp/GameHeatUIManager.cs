using UnityEngine;
using UnityEngine.UI;

public class GameHeatUIManager : MonoBehaviour
{
	[SerializeField]
	private Image heatBarsImage;

	private void Awake()
	{
		SceneSingleton<GameHeatManager>.Instance.OnHeatTimerChange += ChangeHeat;
		ChangeHeat(0f);
	}

	private void OnDisable()
	{
		if (SceneSingleton<GameHeatManager>.Instance != null)
		{
			SceneSingleton<GameHeatManager>.Instance.OnHeatTimerChange -= ChangeHeat;
		}
	}

	public void ChangeHeat(float heatPercent)
	{
		if (heatPercent > 1f)
		{
			heatPercent = 1f;
		}
		heatBarsImage.fillAmount = heatPercent;
	}
}
