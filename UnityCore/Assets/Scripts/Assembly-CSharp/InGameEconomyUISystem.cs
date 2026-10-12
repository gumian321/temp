using UnityEngine;
using UnityEngine.UI;

public class InGameEconomyUISystem : MonoBehaviour
{
	[SerializeField]
	private Slider XPSlider;

	private void OnEnable()
	{
		SceneSingleton<InGameEconomySystem>.Instance.OnScrapChange += UpdateXP;
	}

	public void SetMaxXP(int XP)
	{
		XPSlider.maxValue = XP;
	}

	public void UpdateXP(int XP)
	{
		TweenController.KillTweens(base.transform);
		if ((float)XP > XPSlider.value)
		{
			TweenController.DOFloat(XPSlider.value, XP, TweenDuration.Medium, (float floatValue) =>
			{
				XPSlider.value = floatValue;
			});
		}
		else
		{
			TweenController.DOFloat(0f, XP, TweenDuration.Medium, (float floatValue) =>
			{
				XPSlider.value = floatValue;
			});
		}
	}
}
