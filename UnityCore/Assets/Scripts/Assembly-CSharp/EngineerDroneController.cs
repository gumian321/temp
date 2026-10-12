using System.Collections.Generic;
using UnityEngine;

public class EngineerDroneController : DroneController
{
	[SerializeField]
	private LineRenderer SparksParticles;

	[SerializeField]
	private List<Vector2> SparksPositionsList;

	private IRepairable iRepairable;

	private float droneRepairAmount;

	private EngineerDrone engineerDrone;

	private bool isRepairing;

	private float lineDelay;

	[SerializeField]
	private float lineDelayTimer = 0.15f;

	private int index;

	public override void SetDrone(Transform dockPoint, Drone drone, ChipsContainer droneChipsContainer, DetectionType droneTargetDetectionType)
	{
		droneTargetDetectionType = Singleton<DetectionDataStore>.Instance.GetVSDetectionType(droneTargetDetectionType);
		base.SetDrone(dockPoint, drone, droneChipsContainer, droneTargetDetectionType);
		engineerDrone = (EngineerDrone)drone;
		droneRepairAmount = engineerDrone.GetDroneRepairAmount();
		SparksParticles.gameObject.SetActive(value: false);
	}

	public override Transform RefreshTarget()
	{
		return playerCenterRadar.GetTarget(droneTransform, droneRadarConfiguration, droneTargetDetectionType, null, droneRange);
	}

	public override void SetDroneTarget(Transform targetTransform)
	{
		base.SetDroneTarget(targetTransform);
		if (moveTargetTransform != null)
		{
			iRepairable = moveTargetTransform.GetComponent<IRepairable>();
			iRepairable.SetRepairStatue(statue: true);
		}
		else
		{
			GetBackToTurret();
		}
	}

	public override void RefreshDrone(ChipsContainer droneChipsContainer)
	{
		base.RefreshDrone(droneChipsContainer);
		DroneLevelUpReward levelUpReward = Singleton<PlayerDataStore>.Instance.GetLevelUpReward(drone);
		if (levelUpReward != null)
		{
			float num = Singleton<PlayerDataStore>.Instance.GetLevelUpRewardsCount(levelUpReward);
			float percent = levelUpReward.efficiencyPercent * num;
			droneRepairAmount = engineerDrone.GetDroneRepairAmount(percent);
		}
	}

	public override void StartDroneAction()
	{
		if (!isRepairing)
		{
			SparksParticles.gameObject.SetActive(value: true);
			isRepairing = true;
			SetDroneMovement(flag: false);
			TweenController.KillTweens(droneTransform);
			ObjectSystem.ReScale(droneTransform, droneSize);
		}
	}

	public override void StopDroneAction()
	{
		if (isRepairing)
		{
			SparksParticles.gameObject.SetActive(value: false);
			TweenController.KillTweens(droneTransform);
			ObjectSystem.ReScale(droneTransform, droneSize);
			isRepairing = false;
			iRepairable.SetRepairStatue(statue: false);
			SetDroneMovement(flag: true);
		}
	}

	public override void PlayDroneAction()
	{
		if (isRepairing)
		{
			if (moveTargetTransform == null || iRepairable == null)
			{
				GetBackToTurret();
				return;
			}
			droneTransform.position = moveTargetTransform.position;
			Repair();
		}
	}

	private void Repair()
	{
		if (iRepairable.CanRepair())
		{
			if (lineDelay < Time.time)
			{
				TweenSparklePosition();
				audioManager.PlaySFX(audioClipType);
			}
			iRepairable.Repair(droneRepairAmount);
		}
		else
		{
			GetBackToTurret();
		}
	}

	private void TweenSparklePosition()
	{
		lineDelay = Time.time + lineDelayTimer;
		index++;
		if (index >= SparksPositionsList.Count)
		{
			index = 0;
		}
		SparksParticles.SetPosition(1, SparksPositionsList[index]);
	}
}
