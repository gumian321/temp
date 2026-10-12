using UnityEngine;
using UnityEngine.UI;

public class BossTimerUIController : SceneSingleton<BossTimerUIController>
{
	[SerializeField]
	private Image bossFillerImage;

	private float lastBossPercent;

	private float nextBossPercent;

	private bool endTimer;

	private void OnEnable()
	{
		SceneSingleton<GameHeatManager>.Instance.OnHeatTimerChange += ChangeBarValue;
	}

	private void OnDisable()
	{
		if (SceneSingleton<GameHeatManager>.Instance != null)
		{
			SceneSingleton<GameHeatManager>.Instance.OnHeatTimerChange -= ChangeBarValue;
		}
	}

	public void SetBossTimer(float nextPercent)
	{
		lastBossPercent = nextBossPercent;
		nextBossPercent = nextPercent;
	}

	public void EndBossTimer()
	{
		endTimer = true;
		bossFillerImage.fillAmount = 1f;
	}

	public void ChangeBarValue(float timePercent)
	{
		if (!endTimer)
		{
			timePercent -= lastBossPercent;
			float num = nextBossPercent - lastBossPercent;
			bossFillerImage.fillAmount = timePercent / num;
		}
	}
}
