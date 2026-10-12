public class BasicProjectileTurretController : ProjectileTurretController
{
	public override void ShootTurret(bool isFiring)
	{
		if (isFiring && TimeToShoot())
		{
			FireProjectile();
		}
	}
}
