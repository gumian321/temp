using System;
using UnityEngine;

public class CameraManager : SceneSingleton<CameraManager>
{
	[Header("Zooming")]
	[SerializeField]
	private Camera cam;

	[SerializeField]
	private float StartingZoomOut;

	[SerializeField]
	private float zoomOutPerOneSize;

	[Space]
	[SerializeField]
	private TweenDuration buildModeZoomTweenDuration = TweenDuration.Very_Short;

	[SerializeField]
	private TweenDuration radarZoomTweenDuration = TweenDuration.Very_Short;

	private Vector3 originalScale;

	[Space]
	[Header("Movement")]
	[SerializeField]
	private float lerpingSpeed;

	private Transform target;

	[SerializeField]
	private Vector3 delta;

	[Space]
	[SerializeField]
	private float buildModeHight;

	[SerializeField]
	private float radarOnHight;

	[SerializeField]
	private float radarOffHight;

	private float targetRadarHight;

	[SerializeField]
	private float radarTransitionHight;

	[Space]
	[Header("LayerMasks")]
	[SerializeField]
	private LayerMask radarOn;

	[SerializeField]
	private LayerMask radarOff;

	[SerializeField]
	private LayerMask buildingModeOn;

	private bool isBuildingMode;

	private Transform cameraTransform;

	private bool isRadarOn;

	public bool isFollowingTarget;

	private Action OnCameraTargetReached;

	private void Start()
	{
		originalScale = base.transform.localScale;
		cam.cullingMask = radarOff;
		target = SceneSingleton<PlayerManager>.Instance.GetPlayerTransform();
		targetRadarHight = radarOffHight;
		cameraTransform = base.transform;
		TweenController.DOFloat(targetRadarHight, StartingZoomOut, TweenDuration.Short, ChangeSize, ignoreTimeScale: true);
	}

	private void Update()
	{
		cameraTransform.position = Vector3.Lerp(cameraTransform.position, delta + target.position, lerpingSpeed * Time.unscaledDeltaTime);
		if (isFollowingTarget && Vector2.Distance(cameraTransform.position, target.position) < 0.1f)
		{
			CameraTargetReached();
		}
	}

	public void SetBuildingMode(bool flag)
	{
		if (!isFollowingTarget)
		{
			isBuildingMode = flag;
			if (flag)
			{
				targetRadarHight = buildModeHight;
				cam.cullingMask = buildingModeOn;
			}
			else
			{
				radarOffHight = GetCameraCurrentSize();
				targetRadarHight = radarOffHight;
				cam.cullingMask = radarOff;
			}
			TweenController.KillTweens(base.transform);
			base.transform.localScale = originalScale;
			TweenController.DOFloat(cam.orthographicSize, targetRadarHight, buildModeZoomTweenDuration, ChangeSize, ignoreTimeScale: true);
		}
	}

	public void SetRadarMode(bool x)
	{
		if (!Singleton<InputManager>.Instance.isPlayerInputOn)
		{
			x = false;
		}
		if (x == isRadarOn)
		{
			return;
		}
		isRadarOn = x;
		if (!isFollowingTarget)
		{
			if (x)
			{
				targetRadarHight = radarOnHight;
			}
			else
			{
				targetRadarHight = radarOffHight;
			}
			TweenController.KillTweens(base.transform);
			base.transform.localScale = originalScale;
			TweenController.DOFloat(cam.orthographicSize, targetRadarHight, radarZoomTweenDuration, ChangeSize, ignoreTimeScale: true);
		}
	}

	public void ChangeCameraTarget(Transform target, Action OnCameraTargetReached, float newSize = -1f)
	{
		if (!isFollowingTarget)
		{
			SetRadarMode(x: false);
			this.OnCameraTargetReached = OnCameraTargetReached.Invoke;
			isFollowingTarget = true;
			this.target = target;
			if (newSize != -1f)
			{
				TweenController.DOFloat(cam.orthographicSize, newSize, radarZoomTweenDuration, ChangePlainSize, ignoreTimeScale: true);
			}
		}
	}

	public void CameraTargetReached()
	{
		if (isFollowingTarget)
		{
			isFollowingTarget = false;
			OnCameraTargetReached();
		}
	}

	public void ResetCameraSize()
	{
		TweenController.DOFloat(cam.orthographicSize, GetCameraCurrentSize(), radarZoomTweenDuration, ChangePlainSize, ignoreTimeScale: true);
	}

	public void GameOverZoomOut()
	{
		TweenController.KillTweens(base.transform);
		base.transform.localScale = originalScale;
		TweenController.DOFloat(cam.orthographicSize, radarTransitionHight - 1f, TweenDuration.Medium, ChangeSize, ignoreTimeScale: true);
	}

	private void ChangePlainSize(float size)
	{
		cam.orthographicSize = size;
	}

	private void ChangeSize(float size)
	{
		cam.orthographicSize = size;
		if (isBuildingMode)
		{
			cam.cullingMask = buildingModeOn;
		}
		else if (cam.orthographicSize < radarTransitionHight)
		{
			cam.cullingMask = radarOff;
		}
		else
		{
			cam.cullingMask = radarOn;
		}
	}

	public void ShakeCamera(float duration)
	{
		TweenController.KillTweens(base.transform);
		base.transform.localScale = originalScale;
		TweenController.Shake(base.transform, originalScale, duration, ignoreTimeScale: true);
	}

	private float GetCameraCurrentSize()
	{
		return StartingZoomOut + zoomOutPerOneSize * SceneSingleton<PlayerManager>.Instance.GetPlayerShipSize();
	}
}
