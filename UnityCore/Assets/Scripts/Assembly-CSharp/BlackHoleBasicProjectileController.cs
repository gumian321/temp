using UnityEngine;

public class BlackHoleBasicProjectileController : BasicPositionProjectileController
{
	private BlackHoleProjectile basicProjectile;

	public override void SetProjectile(Projectile projectile, DetectionType turretTargetDetectionType, ChipsContainer chipsContainer = null, Transform projectileTarget = null)
	{
		base.SetProjectile(projectile, turretTargetDetectionType, chipsContainer, projectileTarget);
		basicProjectile = (BlackHoleProjectile)projectile;
	}

	public override void TriggerProjectile(GameObject target)
	{
		SpawnBlackHole(base.transform.position);
	}

	private void SpawnBlackHole(Vector2 position)
	{
		MasterPool.GetPos(PrefabTypes.Object_BlackHole, position).GetComponent<BlackHoleController>().ActivateBlackHole(basicProjectile, projectileTargetDetectionType, chipsContainer);
	}
}
