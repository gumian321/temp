using UnityEngine;

[CreateAssetMenu(fileName = "New Basic Projectile", menuName = "ScriptableObjects/Projectiles/New Basic Projectile")]
public class BasicProjectile : Projectile
{
	[Space]
	[Header("Projectile Variables")]
	public float projectileSpeed;
}
