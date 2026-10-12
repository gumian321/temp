using System;
using UnityEngine;

public class GameCameraManager : SceneSingleton<GameCameraManager>
{
	private PauseMenuManager pauseMenuManager;

	private Action OnCompleteTargeting;

	private float delayOnTarget = 2f;

	private void Start()
	{
		pauseMenuManager = UnityEngine.Object.FindObjectOfType<PauseMenuManager>();
	}

	public void SetCameraTarget(Transform target, Action OnCompleteTargeting = null, float newSize = -1f)
	{
		SceneSingleton<GameManager>.Instance.IsCameraTargeting(isCameraTargeting: true);
		Singleton<InputManager>.Instance.isPlayerInputOn = false;
		Singleton<TimeScaleManager>.Instance.PauseGame();
		this.OnCompleteTargeting = null;
		if (OnCompleteTargeting != null)
		{
			this.OnCompleteTargeting = OnCompleteTargeting.Invoke;
		}
		SceneSingleton<CameraManager>.Instance.ChangeCameraTarget(target, GetBackToPlayer, newSize);
		SceneSingleton<CameraManager>.Instance.ShakeCamera(1f);
	}

	public void GetBackToPlayer()
	{
		TweenController.DelayedCall(delayOnTarget, () =>
		{
			SceneSingleton<CameraManager>.Instance.ChangeCameraTarget(SceneSingleton<PlayerManager>.Instance.GetPlayerTransform(), CompleteBackToPlayer);
			SceneSingleton<CameraManager>.Instance.ResetCameraSize();
		}, ignoreTimeScale: true);
	}

	private void CompleteBackToPlayer()
	{
		Singleton<InputManager>.Instance.isPlayerInputOn = true;
		Singleton<TimeScaleManager>.Instance.UnpauseGame();
		SceneSingleton<GameManager>.Instance.IsCameraTargeting(isCameraTargeting: false);
		if (OnCompleteTargeting != null)
		{
			OnCompleteTargeting();
		}
	}
}
