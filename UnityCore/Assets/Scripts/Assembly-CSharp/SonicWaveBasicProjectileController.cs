using UnityEngine;

public class SonicWaveBasicProjectileController : BasicProjectileController
{
	private float pushBackForce;

	public override void SetProjectile(Projectile projectile, DetectionType turretTargetDetectionType, ChipsContainer chipsContainer = null, Transform projectileTarget = null)
	{
		base.SetProjectile(projectile, turretTargetDetectionType, chipsContainer, projectileTarget);
		SonicBasicProjectile sonicBasicProjectile = (SonicBasicProjectile)projectile;
		pushBackForce = sonicBasicProjectile.pushBackForce;
		float num = sonicBasicProjectile.sonicWaveLength;
		if (IsChipActive(ChipTypes.Mammoth))
		{
			num = Singleton<ChipsDataStore>.Instance.GetMammothArea(num, chipsContainer.GetChipLevel(ChipTypes.Mammoth));
		}
		TweenController.KillTweens(base.transform);
		TweenController.Scale(base.transform, 0f, num, TweenDuration.Long);
	}

	public override void TriggerProjectile(GameObject target)
	{
		base.TriggerProjectile(target);
		PushTarget(target.gameObject);
	}

	private void PushTarget(GameObject target)
	{
		IMovable component = target.GetComponent<IMovable>();
		if (component != null)
		{
			Vector2 vector = (target.transform.position - base.transform.position).normalized;
			component.SonicWavePush((Vector2)target.transform.position + vector * pushBackForce);
		}
	}
}
