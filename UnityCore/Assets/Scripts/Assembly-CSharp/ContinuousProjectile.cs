using UnityEngine;

[CreateAssetMenu(fileName = "New Continuous Projectile", menuName = "ScriptableObjects/Projectiles/New Continuous Projectile")]
public class ContinuousProjectile : Projectile
{
	public GameObject continuousParticleSystem;

	public override float GetProjectileDamage(GameObject target, Damage damage = null)
	{
		return damage?.GetTickDamage(target) ?? projectileDamage.GetTickDamage(target);
	}
}
