using System;

public class AudioSlidersController : Singleton<AudioSlidersController>
{
	public Action OnSlidersChange;

	public static float GetMasterSlider()
	{
		return FBPP.GetFloat("MasterSliderSetting", 1f);
	}

	public static void SetMasterSlider(float vol)
	{
		FBPP.SetFloat("MasterSliderSetting", vol);
	}

	public static float GetMusicVolume()
	{
		return GetMusicSlider() * GetMasterSlider();
	}

	public static float GetMusicSlider()
	{
		return FBPP.GetFloat("MusicSliderSetting", 1f);
	}

	public static void SetMusicSlider(float vol)
	{
		FBPP.SetFloat("MusicSliderSetting", vol);
	}

	public static float GetSFXVolume()
	{
		return GetSFXSlider() * GetMasterSlider();
	}

	public static float GetSFXSlider()
	{
		return FBPP.GetFloat("SFXSliderSetting", 1f);
	}

	public static void SetSFXSlider(float vol)
	{
		FBPP.SetFloat("SFXSliderSetting", vol);
	}
}
