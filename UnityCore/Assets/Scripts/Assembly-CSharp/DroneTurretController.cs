using System.Collections.Generic;
using UnityEngine;

public class DroneTurretController : TurretController
{
	private List<DroneController> droneControllersList = new List<DroneController>();

	[SerializeField]
	private List<Transform> dronesSpawnPointsList;

	[SerializeField]
	private DetectionType turretTargetDetectionType;

	private Drone turretDrone;

	private Transform targetTransfrom;

	private float dronesRange;

	private DroneCore droneCore;

	private bool isDisabled;

	private bool isStunned;

	private int index;

	private void OnEnable()
	{
		TweenController.Scale(base.transform, 0f, 1f, TweenDuration.Short, ignoreTimeScale: true);
		isDisabled = false;
		isStunned = false;
	}

	private void FixedUpdate()
	{
		if (turretTargetDetectionType == DetectionType.Player && !isStunned && targetTransfrom != null)
		{
			if (Vector3.Distance(turretTransform.position, targetTransfrom.position) > dronesRange)
			{
				DisableTurret();
			}
			else if (isDisabled)
			{
				ActivateTurret();
			}
		}
	}

	public override void StunTurret(bool isStunned)
	{
		if (this.isStunned != isStunned)
		{
			this.isStunned = isStunned;
			if (isStunned)
			{
				DisableTurret();
			}
			else
			{
				ActivateTurret();
			}
		}
	}

	public override void DisableTurret()
	{
		if (isDisabled)
		{
			return;
		}
		isDisabled = true;
		foreach (DroneController droneControllers in droneControllersList)
		{
			droneControllers.DisableDrone();
		}
	}

	public override void ActivateTurret()
	{
		if (!isDisabled)
		{
			return;
		}
		isDisabled = false;
		foreach (DroneController droneControllers in droneControllersList)
		{
			droneControllers.ActivateDrone();
		}
	}

	public override void DestroyTurret()
	{
		foreach (DroneController droneControllers in droneControllersList)
		{
			if (droneControllers != null)
			{
				droneControllers.DestroyDrone();
			}
		}
		droneControllersList.Clear();
	}

	public override void SetTurret(Core core)
	{
		droneCore = (DroneCore)core;
		targetTransfrom = SceneSingleton<GameMissionManager>.Instance.GetMissionTarget();
		turretTargetDetectionType = coreController.GetCoreTargetDetectionType();
		AddDrones();
		ActivateDrones();
		dronesRange = turretDrone.GetDroneRange();
	}

	public void AddDrones()
	{
		turretDrone = droneCore.coreDrone;
		droneControllersList = new List<DroneController>();
		for (int i = 0; i < droneCore.DroneCount; i++)
		{
			BuileDrone(turretDrone);
		}
	}

	public void AddDrone(Drone d)
	{
		if (droneControllersList == null)
		{
			droneControllersList = new List<DroneController>();
		}
		BuileDrone(d);
	}

	public void BuileDrone(Drone d)
	{
		Transform spawnPoint = GetSpawnPoint();
		DroneController component = MasterPool.Get(d.dronePrefab, spawnPoint).GetComponent<DroneController>();
		component.SetDrone(spawnPoint, d, turretChipsContainer, turretTargetDetectionType);
		droneControllersList.Add(component);
	}

	public override void RefreshTurret()
	{
		base.RefreshTurret();
		UpdateDronesRange(Singleton<PlayerDataStore>.Instance.GetCoresRangePercent());
		DroneLevelUpReward droneLevelUpReward = (DroneLevelUpReward)Singleton<PlayerDataStore>.Instance.GetLevelUpReward(droneCore);
		if (droneLevelUpReward != null)
		{
			int num = Singleton<PlayerDataStore>.Instance.GetLevelUpRewardsCount(droneLevelUpReward) * droneLevelUpReward.addDronesCount + droneCore.DroneCount;
			int count = droneControllersList.Count;
			if (num > count && num <= droneCore.maxDronesCount)
			{
				for (int i = 0; i < num - count; i++)
				{
					BuileDrone(turretDrone);
				}
				ActivateDrones();
			}
		}
		RefreshDrones();
	}

	public float GetDroneRangePercent(float percent)
	{
		DroneLevelUpReward droneLevelUpReward = (DroneLevelUpReward)Singleton<PlayerDataStore>.Instance.GetLevelUpReward(droneCore);
		if (droneLevelUpReward != null)
		{
			float num = Singleton<PlayerDataStore>.Instance.GetLevelUpRewardsCount(droneLevelUpReward);
			percent += droneLevelUpReward.rangePercent * num;
		}
		return percent;
	}

	public void UpdateDronesRange(float percent = 0f)
	{
		dronesRange = turretDrone.GetDroneRange(GetDroneRangePercent(percent));
	}

	public void ActivateDrones()
	{
		foreach (DroneController droneControllers in droneControllersList)
		{
			droneControllers.ActivateDrone();
		}
	}

	public void RefreshDrones()
	{
		foreach (DroneController droneControllers in droneControllersList)
		{
			droneControllers.RefreshDrone(turretChipsContainer);
		}
	}

	public Transform GetSpawnPoint()
	{
		int num = index;
		index++;
		if (index >= dronesSpawnPointsList.Count)
		{
			index = 0;
		}
		return dronesSpawnPointsList[num];
	}
}
