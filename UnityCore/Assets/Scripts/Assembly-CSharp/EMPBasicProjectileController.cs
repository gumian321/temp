using UnityEngine;

public class EMPBasicProjectileController : BasicProjectileController
{
	private float projectileStunDuration;

	public override void SetProjectile(Projectile projectile, DetectionType turretTargetDetectionType, ChipsContainer chipsContainer = null, Transform projectileTarget = null)
	{
		base.SetProjectile(projectile, turretTargetDetectionType, chipsContainer, projectileTarget);
		EMPBasicProjectile eMPBasicProjectile = (EMPBasicProjectile)projectile;
		projectileStunDuration = eMPBasicProjectile.stunDuration;
	}

	public override void TriggerProjectile(GameObject target)
	{
		IDamageable component = target.GetComponent<IDamageable>();
		if (component != null)
		{
			component.TakeDamage(GetProjectileDamage(target));
			StunTarget(target.gameObject);
		}
	}

	private void StunTarget(GameObject target)
	{
		target.GetComponent<IStunnable>()?.Stun(projectileStunDuration);
	}
}
