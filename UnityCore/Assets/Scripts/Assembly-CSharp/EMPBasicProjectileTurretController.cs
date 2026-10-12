using UnityEngine;

public class EMPBasicProjectileTurretController : BasicProjectileTurretController
{
	public override GameObject FireProjectile()
	{
		GameObject result = base.FireProjectile();
		RefreshTarget();
		return result;
	}
}
