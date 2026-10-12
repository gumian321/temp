using UnityEngine;

public class BasicPositionProjectileController : BasicProjectileController
{
	private Vector2 targetPos;

	private Transform projectileTargetTransform;

	private float projectileSensitivity = 0.5f;

	public void SetTargetPosition(Transform target, Vector2 offset = default(Vector2), float projectileSensitivity = 0.5f)
	{
		projectileTargetTransform = target;
		SetTargetPosition(projectileTargetTransform.position, offset, projectileSensitivity);
	}

	public void SetTargetPosition(Vector2 targetPos, Vector2 offset = default(Vector2), float projectileSensitivity = 0.5f)
	{
		this.projectileSensitivity = projectileSensitivity;
		if (offset == default(Vector2))
		{
			offset = Vector2.zero;
		}
		this.targetPos = targetPos + offset;
		projectileTransform = base.transform;
	}

	public override void FixedUpdate()
	{
		base.FixedUpdate();
		if (projectileTransform == null)
		{
			DisableProjectile();
		}
		else if (Vector2.Distance(projectileTransform.position, targetPos) < projectileSensitivity)
		{
			if (projectileTargetTransform != null)
			{
				TriggerProjectile(projectileTargetTransform.gameObject);
				DestroyProjectile(projectileTargetTransform.gameObject);
			}
			else
			{
				TriggerProjectile(null);
				DestroyProjectile(null);
			}
		}
	}
}
