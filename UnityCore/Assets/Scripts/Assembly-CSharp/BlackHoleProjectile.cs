using UnityEngine;

[CreateAssetMenu(fileName = "New BlackHole Projectile", menuName = "ScriptableObjects/Projectiles/New BlackHole Projectile")]
public class BlackHoleProjectile : AreaBasicProjectile
{
	public GameObject blackHoleObject;

	public float projectileEffectAreaDuration;

	public override float GetProjectileDamage(GameObject target, Damage damage = null)
	{
		return damage?.GetTickDamage(target) ?? projectileDamage.GetTickDamage(target);
	}
}
