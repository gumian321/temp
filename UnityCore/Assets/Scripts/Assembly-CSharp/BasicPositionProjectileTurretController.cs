using UnityEngine;

public class BasicPositionProjectileTurretController : BasicProjectileTurretController
{
	public override GameObject FireProjectile()
	{
		GameObject gameObject = base.FireProjectile();
		if (IsPlayerControlled)
		{
			gameObject.GetComponent<BasicPositionProjectileController>().SetTargetPosition(targetPosition);
		}
		else
		{
			gameObject.GetComponent<BasicPositionProjectileController>().SetTargetPosition(targetTransform);
		}
		return null;
	}
}
