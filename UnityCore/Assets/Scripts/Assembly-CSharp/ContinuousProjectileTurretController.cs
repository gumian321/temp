using UnityEngine;

public class ContinuousProjectileTurretController : ProjectileTurretController
{
	private GameObject projectileObject;

	private ContinuousProjectileContoller continuousProjectileContoller;

	private AudioSource projectileAudioSource;

	public override void DestroyTurret()
	{
		base.DestroyTurret();
		if (projectileAudioSource != null)
		{
			projectileAudioSource.Stop();
			projectileAudioSource = null;
		}
	}

	public override void DisableTurret()
	{
		base.DisableTurret();
		StopProjectile();
	}

	public override void SetTurret(Core core)
	{
		base.SetTurret(core);
		SetUpProjectile();
	}

	private void SetUpProjectile()
	{
		projectileObject = MasterPool.CreateNew(turretProjectile.projectilePrefab);
		projectileObject.transform.parent = base.transform;
		projectileObject.transform.localRotation = Quaternion.identity;
		Vector2 vector = GetBarrelTransform().localPosition;
		vector.y++;
		projectileObject.transform.localPosition = vector;
		continuousProjectileContoller = projectileObject.GetComponent<ContinuousProjectileContoller>();
		continuousProjectileContoller.SetProjectile(turretProjectile, turretTargetDetectionType);
		continuousProjectileContoller.UpdateRange(turretCore.GetTurretRange());
		StopProjectile();
	}

	public override void ShootTurret(bool isFiring)
	{
		if (isFiring)
		{
			FireProjectile();
		}
		else
		{
			StopProjectile();
		}
	}

	public override GameObject FireProjectile()
	{
		if (projectileAudioSource == null)
		{
			projectileAudioSource = audioManager.PlaySFX(fireAudioClipType, turretTransform.position);
		}
		continuousProjectileContoller.ActivatePorjectile();
		return null;
	}

	public void StopProjectile()
	{
		if (projectileAudioSource != null)
		{
			audioManager.StopLoopedAudioSource(projectileAudioSource);
			projectileAudioSource = null;
		}
		continuousProjectileContoller.DeactivatePorjectile();
	}

	public override void RefreshTurret()
	{
		base.RefreshTurret();
		continuousProjectileContoller.UpdateProjectileChipsContainer(turretChipsContainer);
		if (continuousProjectileContoller.IsChipActive(ChipTypes.Mammoth))
		{
			continuousProjectileContoller.UpdateRange(Singleton<ChipsDataStore>.Instance.GetMammothArea(turretRange, turretChipsContainer.GetChipLevel(ChipTypes.Mammoth)));
		}
		else
		{
			continuousProjectileContoller.UpdateRange(turretRange);
		}
	}

	public override void UpdateRange(float percent)
	{
		base.UpdateRange(percent);
		continuousProjectileContoller.UpdateRange(turretRange);
	}
}
