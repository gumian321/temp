using UnityEngine;

public class FlakProjectileTurretController : BasicProjectileTurretController
{
	[SerializeField]
	private float projectileSensitivity = 1.75f;

	public override GameObject FireProjectile()
	{
		GameObject gameObject = base.FireProjectile();
		Vector2 offset = ObjectSystem.GetRandomPosInCircle(Vector2.zero, 1f);
		if (IsPlayerControlled)
		{
			gameObject.GetComponent<BasicPositionProjectileController>().SetTargetPosition(targetPosition, offset, projectileSensitivity);
		}
		else
		{
			gameObject.GetComponent<BasicPositionProjectileController>().SetTargetPosition(targetTransform, offset, projectileSensitivity);
		}
		return null;
	}
}
