using System;
using System.Collections.Generic;
using UnityEngine;

public class AIWarpManager : MonoBehaviour
{
	[SerializeField]
	private List<int> PartsCountWarp;

	[SerializeField]
	private int warpRadius;

	[SerializeField]
	private bool activateWarping;

	[SerializeField]
	private bool isWarping;

	private Action OnWarpEndAction;

	private Transform warpCenter;

	public void SetActivateWarping(bool x)
	{
		activateWarping = x;
	}

	public void CheckWarp(int currentParts, Transform warpCenter, Action warpStartAction, Action warpEndAction)
	{
		this.warpCenter = warpCenter;
		if (!activateWarping || isWarping)
		{
			return;
		}
		foreach (int item in PartsCountWarp)
		{
			if (item == currentParts)
			{
				isWarping = true;
				warpStartAction();
				OnWarpEndAction = warpEndAction.Invoke;
				TweenController.Scale(base.transform, 1f, 0f, TweenDuration.Short, ignoreTimeScale: false, WarpJump);
			}
		}
	}

	private void WarpJump()
	{
		isWarping = false;
		ObjectSystem.SetOnRandomEdgePos(base.transform, warpCenter, warpRadius);
		MasterPool.GetPos(PrefabTypes.Particle_Warp, base.transform.position);
		TweenController.Scale(base.transform, 0f, 1f, TweenDuration.Short, ignoreTimeScale: false, WarpEnded);
	}

	private void WarpEnded()
	{
		Singleton<AudioManager>.Instance.PlaySFX(AudioClipTypes.AI_Warp);
		OnWarpEndAction();
	}
}
