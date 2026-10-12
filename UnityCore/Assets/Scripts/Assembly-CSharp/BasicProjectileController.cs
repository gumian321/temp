using UnityEngine;

public class BasicProjectileController : ProjectileController
{
	private float projectileSpeed;

	public override void SetProjectile(Projectile projectile, DetectionType turretTargetDetectionType, ChipsContainer chipsContainer = null, Transform projectileTarget = null)
	{
		base.SetProjectile(projectile, turretTargetDetectionType, chipsContainer, projectileTarget);
		BasicProjectile basicProjectile = (BasicProjectile)projectile;
		projectileSpeed = basicProjectile.projectileSpeed;
	}

	public override void FixedUpdate()
	{
		base.FixedUpdate();
		MoveProjectile();
	}

	public virtual void MoveProjectile()
	{
		base.transform.Translate(Vector3.up * projectileSpeed * Time.fixedDeltaTime);
	}
}
