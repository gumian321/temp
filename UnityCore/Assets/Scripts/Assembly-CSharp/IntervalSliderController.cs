using System;
using UnityEngine;
using UnityEngine.UI;

public class IntervalSliderController : MonoBehaviour
{
	private Slider slider;

	private Action<int> OnSliderChange;

	private void Awake()
	{
		slider = GetComponent<Slider>();
	}

	public void SetSlider(int valuesCount, int currentValue, Action<int> OnSliderChange)
	{
		slider.maxValue = valuesCount;
		slider.value = currentValue;
		this.OnSliderChange = OnSliderChange.Invoke;
	}

	public void SliderChangedValue()
	{
		if (OnSliderChange != null)
		{
			OnSliderChange((int)slider.value);
		}
		SceneSingleton<PlayUIManager>.Instance.RefreshSlidersText();
	}
}
