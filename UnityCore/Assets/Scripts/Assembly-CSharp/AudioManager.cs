using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AudioManager : Singleton<AudioManager>
{
	private readonly string AudioClipObjectPath = "Scriptable Objects/AudioClipObjects";

	[SerializeField]
	private int audioSourceCounts = 5;

	private List<AudioSource> AudioSources = new List<AudioSource>();

	private List<AudioClipObject> audioClipObjectsList;

	private List<AudioClipTypes> AudioClipEnums;

	private Dictionary<AudioClipTypes, int> AudioClipDict;

	private Transform gameCenter;

	[Space]
	[SerializeField]
	private float audioFullVolumeRange = 10f;

	[SerializeField]
	private float audioFadeVolumeRange = 10f;

	private float volumePercent = 1f;

	private void Start()
	{
		AudioClipDict = new Dictionary<AudioClipTypes, int>();
		InitiateAudioSources();
		LoadAudioFiles();
		AudioSlidersController audioSlidersController = Singleton<AudioSlidersController>.Instance;
		audioSlidersController.OnSlidersChange = (Action)Delegate.Combine(audioSlidersController.OnSlidersChange, new Action(RefreshAudio));
	}

	private void OnDisable()
	{
		AudioSlidersController audioSlidersController = Singleton<AudioSlidersController>.Instance;
		audioSlidersController.OnSlidersChange = (Action)Delegate.Remove(audioSlidersController.OnSlidersChange, new Action(RefreshAudio));
	}

	public void Reset(Transform gameCenter)
	{
		ResetSources();
		this.gameCenter = gameCenter;
	}

	public void ResetSources()
	{
		foreach (AudioSource audioSource in AudioSources)
		{
			audioSource.Stop();
		}
	}

	private void InitiateAudioSources()
	{
		AudioSources = new List<AudioSource>();
		for (int i = 0; i < audioSourceCounts; i++)
		{
			AudioSource audioSource = base.gameObject.AddComponent<AudioSource>();
			audioSource.playOnAwake = false;
			audioSource.volume = AudioSlidersController.GetSFXSlider();
			AudioSources.Add(audioSource);
		}
	}

	private void LoadAudioFiles()
	{
		audioClipObjectsList = new List<AudioClipObject>();
		audioClipObjectsList.AddRange(Resources.LoadAll<AudioClipObject>(AudioClipObjectPath));
		AudioClipEnums = new List<AudioClipTypes>();
		foreach (AudioClipObject audioClipObjects in audioClipObjectsList)
		{
			AudioClipEnums.Add(audioClipObjects.audioClipEnum);
		}
	}

	public void RefreshAudio()
	{
		volumePercent = AudioSlidersController.GetSFXVolume();
		foreach (AudioSource audioSource in AudioSources)
		{
			audioSource.volume *= volumePercent;
		}
	}

	public AudioSource PlaySFX(AudioClipTypes audioClipType, Vector2 AudioSourcePosition = default(Vector2))
	{
		if (audioClipType == AudioClipTypes.None)
		{
			return null;
		}
		AudioSource unusedSource = GetUnusedSource();
		if (unusedSource == null)
		{
			return null;
		}
		AudioClipObject audioClipObject = audioClipObjectsList[AudioClipEnums.IndexOf(audioClipType)];
		if (!AudioClipDict.ContainsKey(audioClipType))
		{
			AudioClipDict.Add(audioClipType, 0);
		}
		if (AudioClipDict[audioClipType] >= audioClipObject.copiesPlayedAtOnce)
		{
			return null;
		}
		AudioClipDict[audioClipType]++;
		unusedSource.clip = audioClipObject.GetAudioClip();
		unusedSource.volume = audioClipObject.volume * volumePercent;
		if (AudioSourcePosition != default(Vector2))
		{
			unusedSource.volume = CalculateVolume(unusedSource.volume, AudioSourcePosition);
		}
		unusedSource.loop = audioClipObject.isLoopable;
		unusedSource.mute = false;
		unusedSource.Play();
		if (base.gameObject.activeInHierarchy)
		{
			StartCoroutine(ReleaseAudioSource(unusedSource, audioClipType));
		}
		return unusedSource;
	}

	public void StopLoopedAudioSource(AudioSource audioSource)
	{
		audioSource.loop = false;
		audioSource.Stop();
	}

	private float CalculateVolume(float currentVolume, Vector2 AudioSourcePosition)
	{
		float num = Vector3.Distance(AudioSourcePosition, gameCenter.position);
		float num2 = 1f;
		if (num <= audioFullVolumeRange)
		{
			num2 = 1f;
		}
		else
		{
			if (!(num > audioFullVolumeRange + audioFadeVolumeRange))
			{
				num -= audioFullVolumeRange;
				num2 = num / audioFadeVolumeRange;
				return currentVolume - currentVolume * num2;
			}
			num2 = 0f;
		}
		return currentVolume * num2;
	}

	private void StopSource(AudioSource audioSource)
	{
		audioSource.Stop();
	}

	private IEnumerator ReleaseAudioSource(AudioSource audioSource, AudioClipTypes audioClipType)
	{
		while (audioSource.isPlaying)
		{
			yield return null;
		}
		AudioClipDict[audioClipType]--;
	}

	private AudioSource GetUnusedSource()
	{
		foreach (AudioSource audioSource in AudioSources)
		{
			if (!audioSource.isPlaying)
			{
				return audioSource;
			}
		}
		return null;
	}

	public void MuteLoopedMusic(bool flag)
	{
		if (AudioSources.Count <= 0)
		{
			return;
		}
		foreach (AudioSource audioSource in AudioSources)
		{
			if (audioSource.loop)
			{
				audioSource.mute = flag;
			}
		}
	}
}
