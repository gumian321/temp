using System;
using System.Collections.Generic;
using DG.Tweening;
using UnityEngine;

public class BackgroundAudioManager : Singleton<BackgroundAudioManager>
{
	private List<AudioClip> audioClipsList;

	[SerializeField]
	private AudioSource audioSource;

	[SerializeField]
	private float MaxVolume = 0.5f;

	private float currentVolume;

	private int index;

	private void Start()
	{
		MuteSource();
		RefreshAudio();
		PlayBackgroundAudio(Singleton<AudioDataStore>.Instance.MainMenuBackgroundAudioClipsList, FadeAudio: false);
		FadeInAudioSource();
		AudioSlidersController audioSlidersController = Singleton<AudioSlidersController>.Instance;
		audioSlidersController.OnSlidersChange = (Action)Delegate.Combine(audioSlidersController.OnSlidersChange, new Action(RefreshAudio));
	}

	private void OnDisable()
	{
		AudioSlidersController audioSlidersController = Singleton<AudioSlidersController>.Instance;
		audioSlidersController.OnSlidersChange = (Action)Delegate.Remove(audioSlidersController.OnSlidersChange, new Action(RefreshAudio));
	}

	private void Update()
	{
		if (!audioSource.isPlaying && audioClipsList != null)
		{
			PlayNextAudioClip();
		}
	}

	public void RefreshAudio()
	{
		currentVolume = AudioSlidersController.GetMusicVolume() * MaxVolume;
		audioSource.volume = currentVolume;
	}

	public void PlayBackgroundAudio(List<AudioClip> audioClipsList, bool FadeAudio = true)
	{
		if (this.audioClipsList == null || !(this.audioClipsList[0] == audioClipsList[0]))
		{
			this.audioClipsList = new List<AudioClip>(audioClipsList);
			if (FadeAudio)
			{
				FadeAudioSource();
			}
		}
	}

	public void PlayNextAudioClip()
	{
		index = UnityEngine.Random.Range(0, audioClipsList.Count);
		audioSource.clip = audioClipsList[index];
		audioSource.Play();
	}

	public void FadeAudioSource()
	{
		FadeOutAudioSource(() =>
		{
			index = 0;
			audioSource.clip = audioClipsList[0];
			audioSource.Play();
			FadeInAudioSource();
		});
	}

	private void FadeInAudioSource(TweenCallback callBack = null)
	{
		TweenController.DOFloat(0f, currentVolume, TweenDuration.Medium, (float volume) =>
		{
			audioSource.volume = volume;
		}, ignoreTimeScale: true, callBack);
	}

	private void FadeOutAudioSource(TweenCallback callBack = null)
	{
		TweenController.DOFloat(currentVolume, 0f, TweenDuration.Medium, (float volume) =>
		{
			audioSource.volume = volume;
		}, ignoreTimeScale: true, callBack);
	}

	private void MuteSource()
	{
		audioSource.volume = 0f;
	}
}
