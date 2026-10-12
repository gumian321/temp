using UnityEngine;

public class LineProjectileTurretController : BasicProjectileTurretController
{
	[SerializeField]
	private LayerMask enemyLayerMask;

	private bool isLineOn;

	public override GameObject FireProjectile()
	{
		if (IsPlayerControlled)
		{
			targetTransform = RaycastTarget();
			if (targetTransform == null)
			{
				return null;
			}
			return base.FireProjectile();
		}
		isLineOn = true;
		Invoke("disableProjectile", turretProjectile.projectileLifeTime);
		return base.FireProjectile();
	}

	private void disableProjectile()
	{
		isLineOn = false;
	}

	public override void RotateToTarget(Vector2 targetPosition)
	{
		if (!isLineOn)
		{
			base.RotateToTarget(targetPosition);
		}
	}

	private Transform RaycastTarget()
	{
		Vector3 position = turretTransform.position;
		Vector3 normalized = ((Vector3)targetPosition - position).normalized;
		RaycastHit2D raycastHit2D = Physics2D.CircleCast(position, 1f, normalized, turretRange * 2f, enemyLayerMask);
		if (raycastHit2D.collider != null)
		{
			IDetectable component = raycastHit2D.collider.GetComponent<IDetectable>();
			if (component == null)
			{
				return null;
			}
			if (component.IsDetectionType(turretTargetDetectionType))
			{
				return raycastHit2D.collider.transform;
			}
		}
		return null;
	}
}
