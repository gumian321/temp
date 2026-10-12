using UnityEngine;

public class ScraperDroneController : DroneController
{
	private bool isHoldingPickable;

	private Transform pickableTransform;

	private IPickable iPickable;

	[SerializeField]
	private Vector2 pickablePos;

	public void SetCollectingState(bool flag)
	{
		if (!flag)
		{
			DisableDrone();
		}
		else
		{
			ActivateDrone();
		}
	}

	public override void SetDrone(Transform dockPoint, Drone drone, ChipsContainer droneChipsContainer, DetectionType droneTargetDetectionType)
	{
		base.SetDrone(dockPoint, drone, droneChipsContainer, droneTargetDetectionType);
	}

	public override void DisableDrone()
	{
		ReleasePickable();
		base.DisableDrone();
	}

	public override Transform RefreshTarget()
	{
		if (pickableTransform != null)
		{
			return pickableTransform;
		}
		iPickable = SceneSingleton<RewardSystemManager>.Instance.GetComponent<IPickable>();
		Transform transform = iPickable?.GetPickable(droneTransform.position, droneRange);
		if (transform != null)
		{
			return transform;
		}
		iPickable = SceneSingleton<ScrapsManager>.Instance.GetComponent<IPickable>();
		return iPickable?.GetPickable(droneTransform.position, droneRange);
	}

	public override void StartDroneAction()
	{
		ParticlesSystem.PlayParticle(moveTargetTransform.position, PrefabTypes.Particle_PickableCollected);
		pickableTransform = moveTargetTransform;
		pickableTransform.SetParent(base.transform);
		TweenController.KillTweens(pickableTransform);
		pickableTransform.localPosition = pickablePos;
		ObjectSystem.ReScale(pickableTransform, 1f);
		isHoldingPickable = true;
		GetBackToTurret(searchForTarget: false);
	}

	public override void StopDroneAction()
	{
	}

	public override void DroneIsDocked(bool searchForTarget = false)
	{
		base.DroneIsDocked(searchForTarget: true);
		if (isHoldingPickable)
		{
			iPickable?.CollectPickable(pickableTransform);
			ClearPickable();
			audioManager.PlaySFX(audioClipType);
		}
	}

	public override void DestroyDrone()
	{
		ReleasePickable();
		base.DestroyDrone();
	}

	private void ClearPickable()
	{
		pickableTransform = null;
		isHoldingPickable = false;
		iPickable = null;
	}

	private void ReleasePickable()
	{
		if (isFollowingTarget)
		{
			if (moveTargetTransform != null)
			{
				iPickable?.ReturnPickable(moveTargetTransform);
			}
		}
		else if (isHoldingPickable && pickableTransform != null)
		{
			iPickable?.ReturnPickable(pickableTransform);
		}
		ClearPickable();
	}
}
