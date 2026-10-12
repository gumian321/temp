using System;
using TMPro;
using UnityEngine;

public class GameTimeManager : SceneSingleton<GameTimeManager>
{
	private float MaxTimeSec = 100f;

	private float currentTimeSec = 100f;

	private bool isCountingDown;

	[SerializeField]
	private TextMeshProUGUI inGameTimer;

	private DateTime startTime;

	private TimeSpan currentTime;

	private DateTime startPauseTime;

	private TimeSpan pausedTime;

	private bool isTimerRunning;

	private bool isTimerPaused;

	public void SetCurrentTime(float currentTimeSec)
	{
		this.currentTimeSec = currentTimeSec;
		if (isCountingDown)
		{
			if (MaxTimeSec - currentTimeSec >= 0f)
			{
				inGameTimer.text = GetTimeString(MaxTimeSec - currentTimeSec);
			}
			else
			{
				inGameTimer.text = GetTimeString(0f);
			}
		}
		else
		{
			inGameTimer.text = GetTimeString(currentTimeSec);
		}
		if (isCountingDown && MaxTimeSec - currentTimeSec == 0f)
		{
			SceneSingleton<GameMissionManager>.Instance.MissionTimerRunOut();
		}
	}

	public void StartTimer()
	{
		MaxTimeSec = SceneSingleton<GameMissionManager>.Instance.GetGameTimeSec();
		isCountingDown = SceneSingleton<GameMissionManager>.Instance.isCountingDown;
		SetCurrentTime(0f);
		startTime = DateTime.Now;
		isTimerRunning = true;
	}

	public void StopTimer()
	{
		isTimerRunning = false;
	}

	public void PauseTimer()
	{
		startPauseTime = DateTime.Now;
		isTimerPaused = true;
	}

	public void ResumeTimer()
	{
		startTime += pausedTime;
		isTimerPaused = false;
	}

	private void Update()
	{
		if (isTimerRunning)
		{
			currentTime = DateTime.Now - startTime;
		}
		if (isTimerRunning)
		{
			pausedTime = DateTime.Now - startPauseTime;
		}
	}

	public string GetTimerString()
	{
		return string.Format("({0}:{1}.{2})", currentTime.Minutes.ToString("D2"), currentTime.Seconds.ToString("D2"), (currentTime.Milliseconds / 10).ToString("D2"));
	}

	public float GetTimerSeconds()
	{
		return (float)(currentTime.Minutes * 60 + currentTime.Seconds) + (float)currentTime.Milliseconds / 100f;
	}

	public int GetGameMinutesSurvived()
	{
		return currentTime.Minutes;
	}

	public string GetTimeSurvived()
	{
		return string.Format("({0}:{1})", currentTime.Minutes.ToString("D2"), currentTime.Seconds.ToString("D2"));
	}

	public string GetTimeString(float seconds)
	{
		int num = (int)seconds;
		int num2 = num / 60;
		if (num2 / 60 < 1)
		{
			num -= num2 * 60;
			return string.Format("{0}:{1}", num2.ToString("D2"), num.ToString("D2"));
		}
		int num3 = num2 / 60;
		num -= num3 * 3600;
		num2 -= num3 * 60;
		num -= num2 * 60;
		return string.Format("{0}:{1}:{2}", num3.ToString("D2"), num2.ToString("D2"), num.ToString("D2"));
	}
}
