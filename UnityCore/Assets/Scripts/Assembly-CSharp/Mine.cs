using UnityEngine;

[CreateAssetMenu(fileName = "New Mine", menuName = "ScriptableObjects/Projectiles/New mine")]
public class Mine : ScriptableObject
{
	public ChipsContainer activatableChips;

	[Header("Mine Look")]
	public Sprite mineSprite;

	public PrefabTypes minePrefab;

	[Space]
	[Header("Mine Damage")]
	public Damage mineDamage;

	public virtual float GetMineDamage(GameObject target)
	{
		return mineDamage.GetDamage(target);
	}
}
