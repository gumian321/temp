using System;
using System.Collections;
using UnityEngine;

public class GameHeatManager : SceneSingleton<GameHeatManager>
{
	private float MaxHeat = 100f;

	private float gameTime = 20f;

	private float currentGameTime;

	private WaitForSeconds oneSecdelay;

	private int updateTick = 5;

	private RatingSystemManager ratingSystemManager;

	private float highestHeat;

	private float currentHeat;

	public event Action<float> OnHeatTimerChange;

	public event Action OnPlayerHeatChange;

	public float GetGameTime()
	{
		return gameTime;
	}

	protected override void Awake()
	{
		base.Awake();
		oneSecdelay = new WaitForSeconds(1f);
		OnHeatTimerChange += Singleton<AIDataStore>.Instance.UpdateAIPools;
		MaxHeat = Singleton<AIDataStore>.Instance.MaxHeat;
	}

	public void StartTimer(float timer)
	{
		ratingSystemManager = SceneSingleton<RatingSystemManager>.Instance;
		gameTime = timer;
		currentGameTime = 0f;
		StartCoroutine(Timer());
	}

	private void OnDisable()
	{
		OnHeatTimerChange -= Singleton<AIDataStore>.Instance.UpdateAIPools;
	}

	private IEnumerator Timer()
	{
		while (true)
		{
			yield return oneSecdelay;
			currentGameTime++;
			SceneSingleton<GameTimeManager>.Instance.SetCurrentTime(currentGameTime);
			if (OnHeatTimerChange != null)
			{
				OnHeatTimerChange(GetTimerHeatPercent());
			}
		}
	}

	public string GetTimer()
	{
		int num = (int)currentGameTime / 60;
		currentGameTime %= 60f;
		int num2 = (int)currentGameTime;
		string arg = ((num < 10) ? ("0" + num) : num.ToString());
		string arg2 = ((num2 < 10) ? ("0" + num2) : num2.ToString());
		return $"({arg}:{arg2}:00)";
	}

	public float GetSecondsSurvived()
	{
		return currentGameTime;
	}

	public bool IsEarlyHunt()
	{
		return gameTime - currentGameTime > 0f;
	}

	public float GetTimerHeatPercent()
	{
		return currentGameTime / gameTime;
	}

	public void ChangeHeat(float heat)
	{
		if (OnPlayerHeatChange != null)
		{
			OnPlayerHeatChange();
		}
	}
}
