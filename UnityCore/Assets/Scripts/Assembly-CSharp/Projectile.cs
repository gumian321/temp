using UnityEngine;

[CreateAssetMenu(fileName = "New Projectile", menuName = "ScriptableObjects/Projectiles/New Projectile")]
public class Projectile : ScriptableObject
{
	[Header("Projectile Look")]
	public Sprite projectileSprite;

	public PrefabTypes projectilePrefab;

	[Space]
	[Header("Projectile General Variables")]
	public int targetPiercingCount = 1;

	public float projectileLifeTime = 1f;

	public ChipsContainer activatableChips;

	[Space]
	[Header("Projectile Damage")]
	public Damage projectileDamage;

	public virtual float GetProjectileDamage(GameObject target, Damage overrideDamage = null)
	{
		return overrideDamage?.GetDamage(target) ?? projectileDamage.GetDamage(target);
	}
}
