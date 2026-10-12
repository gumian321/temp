using UnityEngine;

public class TimeScaleManager : Singleton<TimeScaleManager>
{
	private bool isPaused;

	private bool canPause;

	public void StartGame()
	{
		canPause = true;
		UnpauseGame();
	}

	public void EndGame()
	{
		canPause = false;
		PauseGame();
	}

	public bool CanPause()
	{
		return canPause;
	}

	public bool IsPaused()
	{
		return isPaused;
	}

	public float GetTimeScale()
	{
		return Time.timeScale;
	}

	public void PauseGame()
	{
		isPaused = true;
		Time.timeScale = 0f;
		Singleton<AudioManager>.Instance.MuteLoopedMusic(flag: true);
		SceneSingleton<PlayerEngineBoostController>.Instance.StopUsingEngine();
	}

	public void UnpauseGame()
	{
		isPaused = false;
		Time.timeScale = 1f;
		Singleton<AudioManager>.Instance.MuteLoopedMusic(flag: false);
	}
}
