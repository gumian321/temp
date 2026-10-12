using UnityEngine;

public class HeartBeatAudioController : MonoBehaviour
{
	private AudioSource audioSource;

	private void Awake()
	{
		audioSource = GetComponent<AudioSource>();
	}

	public void StartHeatBeat()
	{
		if (!audioSource.isPlaying)
		{
			audioSource.Play();
		}
	}

	public void StopHeartBeat()
	{
		audioSource.Stop();
	}

	public static float GetHeartBeatStartPercent()
	{
		return 2f;
	}
}
