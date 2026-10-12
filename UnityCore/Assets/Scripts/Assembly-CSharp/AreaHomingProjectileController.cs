using UnityEngine;

public class AreaHomingProjectileController : HomingProjectileController
{
	private float projectileEffectArea;

	public override void SetProjectile(Projectile projectile, DetectionType turretTargetDetectionType, ChipsContainer chipsContainer = null, Transform projectileTarget = null)
	{
		base.SetProjectile(projectile, turretTargetDetectionType, chipsContainer, projectileTarget);
		AreaHomingProjectile areaHomingProjectile = (AreaHomingProjectile)projectile;
		if (IsChipActive(ChipTypes.Mammoth))
		{
			projectileEffectArea = Singleton<ChipsDataStore>.Instance.GetMammothArea(areaHomingProjectile.projectileEffectArea, chipsContainer.GetChipLevel(ChipTypes.Mammoth));
		}
		else
		{
			projectileEffectArea = areaHomingProjectile.projectileEffectArea;
		}
	}

	public override void TriggerProjectile(GameObject target)
	{
		bool isShieldHit = Singleton<DetectionDataStore>.Instance.IsShieldLayer(target);
		foreach (GameObject item in ExplosionSystem.TriggerExplosion(projectileEffectArea, base.transform.position, projectileTargetDetectionType, projectile.projectileDamage, isShieldHit))
		{
			ActivateChips(item);
		}
	}
}
