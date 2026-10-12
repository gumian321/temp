using System;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public class AudioUISlider : MonoBehaviour
{
	[SerializeField]
	private TextMeshProUGUI sliderPercent;

	[SerializeField]
	private Slider slider;

	[SerializeField]
	private GameObject HandSelector;

	private void OnEnable()
	{
		HandSelector.SetActive(value: false);
	}

	private void Start()
	{
		if (sliderPercent != null)
		{
			AudioSlidersController instance = Singleton<AudioSlidersController>.Instance;
			instance.OnSlidersChange = (Action)Delegate.Combine(instance.OnSlidersChange, new Action(OnSliderChange));
		}
	}

	private void OnDisable()
	{
		if (sliderPercent != null)
		{
			AudioSlidersController instance = Singleton<AudioSlidersController>.Instance;
			instance.OnSlidersChange = (Action)Delegate.Remove(instance.OnSlidersChange, new Action(OnSliderChange));
		}
	}

	public void OnSliderChange()
	{
		int num = Mathf.RoundToInt(slider.value * 100f);
		if (sliderPercent != null)
		{
			sliderPercent.text = num + "%";
		}
	}
}
