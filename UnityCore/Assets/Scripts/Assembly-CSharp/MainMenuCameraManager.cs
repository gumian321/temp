using System;
using UnityEngine;

public class MainMenuCameraManager : SceneSingleton<MainMenuCameraManager>
{
	[Space]
	[Header("Moving Camera")]
	[SerializeField]
	private Camera cam;

	[SerializeField]
	private float zoomOutSize = 9f;

	private float targetZoom;

	[SerializeField]
	private float movingSpeed = 4f;

	[SerializeField]
	private float zoomingSpeed = 4f;

	private Vector3 tp;

	private Action OnCameraTargetArrived;

	private bool isMoving;

	private Vector3 targetPos
	{
		get
		{
			return tp;
		}
		set
		{
			tp = value;
			tp.z = -10f;
		}
	}

	private void Update()
	{
		if (Vector3.Distance(cam.transform.position, targetPos) > 0.1f)
		{
			cam.transform.position = Vector3.Lerp(cam.transform.position, targetPos, movingSpeed * Time.deltaTime);
		}
		else
		{
			if (OnCameraTargetArrived != null && isMoving)
			{
				OnCameraTargetArrived();
			}
			isMoving = false;
		}
		if (cam.orthographicSize != targetZoom)
		{
			cam.orthographicSize = Mathf.Lerp(cam.orthographicSize, targetZoom, zoomingSpeed * Time.deltaTime);
		}
	}

	public void SetCamTargetPos(Vector3 pos, Action OnCameraTargetArrived = null)
	{
		targetPos = pos;
		isMoving = true;
		this.OnCameraTargetArrived = OnCameraTargetArrived;
	}

	public void SetCamTargetZoom(float zoom = -1f)
	{
		if (zoom != -1f)
		{
			targetZoom = zoom;
		}
		else
		{
			targetZoom = zoomOutSize;
		}
	}

	public void SetCamMask(LayerMask layerMask)
	{
		cam.cullingMask = layerMask;
	}
}
