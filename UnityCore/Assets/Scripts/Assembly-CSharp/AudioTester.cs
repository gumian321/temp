using UnityEngine;

public class AudioTester : MonoBehaviour
{
	private float duration = 1f;

	private float timer;

	private void Awake()
	{
		timer = Time.time + duration;
	}

	private void Update()
	{
		if (timer < Time.time)
		{
			timer = Time.time + duration;
			Singleton<AudioManager>.Instance.PlaySFX(AudioClipTypes.Gun_Gatling, base.transform.position);
		}
	}
}
