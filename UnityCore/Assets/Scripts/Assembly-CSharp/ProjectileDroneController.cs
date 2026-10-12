using UnityEngine;

public class ProjectileDroneController : DroneController
{
	private bool isShooting;

	private float timer;

	private float droneRateOfFire;

	private Projectile droneProjectile;

	private ProjectileDrone projectileDrone;

	private float damageModifier = 1f;

	private RadarSystem radarSystem;

	public override void SetDrone(Transform dockPoint, Drone drone, ChipsContainer droneChipsContainer, DetectionType droneTargetDetectionType)
	{
		base.SetDrone(dockPoint, drone, droneChipsContainer, droneTargetDetectionType);
		projectileDrone = (ProjectileDrone)drone;
		droneRateOfFire = projectileDrone.GetDroneRateOfFire();
		if (Singleton<DetectionDataStore>.Instance.IsPlayerLayer(droneTargetDetectionType))
		{
			damageModifier = SceneSingleton<GameMissionManager>.Instance.enemiesDamageModifier;
		}
		else
		{
			damageModifier = PlayerDataStore.GetDamageModifier();
		}
		droneProjectile = projectileDrone.droneProjectile;
		radarSystem = playerCenterRadar.GetRadarSystem(droneTargetDetectionType);
	}

	public override Transform RefreshTarget()
	{
		return radarSystem.GetTarget(droneTransform.position, droneRadarConfiguration, null, droneRange);
	}

	public override void RefreshDrone(ChipsContainer droneChipsContainer)
	{
		base.RefreshDrone(droneChipsContainer);
		float num = Singleton<PlayerDataStore>.Instance.GetCoresDamagePercent();
		float num2 = Singleton<PlayerDataStore>.Instance.GetCoresRateOfFirePercent();
		DroneLevelUpReward levelUpReward = Singleton<PlayerDataStore>.Instance.GetLevelUpReward(drone);
		if (levelUpReward != null)
		{
			float num3 = Singleton<PlayerDataStore>.Instance.GetLevelUpRewardsCount(levelUpReward);
			float num4 = levelUpReward.efficiencyPercent * num3;
			num += num4;
			num2 += num4;
		}
		damageModifier = UnityEngineSystem.CalcPercent(PlayerDataStore.GetDamageModifier(), num);
		droneRateOfFire = projectileDrone.GetDroneRateOfFire(num2);
	}

	public override void StartDroneAction()
	{
		isShooting = true;
	}

	public override void StopDroneAction()
	{
		isShooting = false;
	}

	public override void PlayDroneAction()
	{
		ShootTurret();
		if (Vector3.Distance(moveTargetTransform.position, dockPoint.position) > droneRange)
		{
			GetBackToTurret();
		}
	}

	public void ShootTurret()
	{
		if (isShooting && TimeToShoot())
		{
			FireProjectile();
		}
	}

	public void FireProjectile()
	{
		if (moveTargetTransform == null)
		{
			StartTargetRefreshingCoroutines();
			return;
		}
		audioManager.PlaySFX(audioClipType);
		ProjectileController component = MasterPool.GetPos(droneProjectile.projectilePrefab, droneTransform.position).GetComponent<ProjectileController>();
		component.SetProjectile(droneProjectile, droneTargetDetectionType, droneChipsContainer);
		component.SetDamageModifier(damageModifier);
		component.RotateToTarget(moveTargetTransform.position);
	}

	private bool TimeToShoot()
	{
		if (timer < Time.time)
		{
			timer = Time.time + droneRateOfFire;
			return true;
		}
		return false;
	}
}
