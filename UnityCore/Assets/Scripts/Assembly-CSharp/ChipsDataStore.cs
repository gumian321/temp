using System.Collections.Generic;
using UnityEngine;

public class ChipsDataStore : Singleton<ChipsDataStore>
{
	[Space]
	[Header("Mammoth")]
	[SerializeField]
	private List<float> MammothAreaPercentBoost;

	[SerializeField]
	private List<float> MammothDamagePercentBoost;

	[SerializeField]
	private List<float> MammothProjectileSizePercentBoost;

	[Space]
	[Header("Chain")]
	[SerializeField]
	private RadarConfiguration chainProjectileRCT;

	[SerializeField]
	private List<int> chainTargetJumpCount;

	[SerializeField]
	private List<float> chainTargetRange;

	[SerializeField]
	private List<float> chainDamagePercent;

	[Space]
	[Header("Piercing")]
	[SerializeField]
	private List<int> PiercingTargetCount;

	[Space]
	[Header("Shrapnel")]
	[SerializeField]
	private Projectile shrapnelProjectile;

	[SerializeField]
	private List<int> shrapnelProjectileCount;

	[SerializeField]
	private List<float> shrapnelDamagePercent;

	[Space]
	[Header("Explosion")]
	[SerializeField]
	private List<float> ExplosionEffectArea;

	[SerializeField]
	private List<float> ExplosionDamagePercent;

	public float GetMammothArea(float area, int chipLevel)
	{
		return area + area * ListSystem.GetClampObject(MammothAreaPercentBoost, chipLevel - 1);
	}

	public float GetMammothDamage(float damage, int chipLevel)
	{
		return damage + damage * ListSystem.GetClampObject(MammothDamagePercentBoost, chipLevel - 1);
	}

	public float GetMammothProjectileSize(float projectileSize, int chipLevel)
	{
		return projectileSize + projectileSize * ListSystem.GetClampObject(MammothProjectileSizePercentBoost, chipLevel - 1);
	}

	public int GetChainTargetJumpCount(int chipLevel)
	{
		return ListSystem.GetClampObject(chainTargetJumpCount, chipLevel - 1);
	}

	public float GetChainTargetRange(int chipLevel)
	{
		return ListSystem.GetClampObject(chainTargetRange, chipLevel - 1);
	}

	public float GetChainDamagePercent(int chipLevel)
	{
		return ListSystem.GetClampObject(chainDamagePercent, chipLevel - 1);
	}

	public void ActivateChain(GameObject ignoreTarget, DetectionType targetDT, Projectile projectile, int chainCount, ChipsContainer chipsContainer)
	{
		int chipLevel = chipsContainer?.GetChipLevel(ChipTypes.Chain) ?? 1;
		float range = GetChainTargetRange(chipLevel);
		if (chainCount != 0)
		{
			Transform target = SceneSingleton<PlayerCenterRadar>.Instance.GetTarget(ignoreTarget.transform, chainProjectileRCT, targetDT, ignoreTarget.transform, range);
			if (!(target == null))
			{
				ProjectileController component = MasterPool.GetPos(projectile.projectilePrefab, ignoreTarget.transform.position).GetComponent<ProjectileController>();
				component.RotateToTarget(target.position);
				component.SetProjectile(projectile, targetDT, chipsContainer, target);
				component.SetIgnoreTarget(ignoreTarget);
				chainCount--;
				component.SetChainTargetJumpCount(chainCount);
			}
		}
	}

	public int GetPiercingTargetCount(int chipLevel)
	{
		return ListSystem.GetClampObject(PiercingTargetCount, chipLevel - 1);
	}

	public float GetShrapnelDamagePercent(int chipLevel)
	{
		return ListSystem.GetClampObject(shrapnelDamagePercent, chipLevel - 1);
	}

	public void ActivateShrapnel(GameObject ignoreTarget, Damage damage, DetectionType targetDT, int chipLevel)
	{
		int num = Random.Range(1, ListSystem.GetClampObject(shrapnelProjectileCount, chipLevel - 1) + 1);
		float num2 = 360 / num;
		for (int i = 0; i < num; i++)
		{
			ProjectileController component = MasterPool.GetPos(shrapnelProjectile.projectilePrefab, ignoreTarget.transform.position).GetComponent<ProjectileController>();
			component.SetProjectile(shrapnelProjectile, targetDT);
			component.RotateAngle((float)i * num2);
			component.SetIgnoreTarget(ignoreTarget);
			component.OverrideProjectileDamage(damage, GetShrapnelDamageModifier(chipLevel));
		}
	}

	public float GetShrapnelDamageModifier(int chipLevel)
	{
		float num = UnityEngineSystem.CalcPercent(PlayerDataStore.GetDamageModifier(), Singleton<PlayerDataStore>.Instance.GetCoresDamagePercent());
		return GetShrapnelDamagePercent(chipLevel) * num;
	}

	public void ActivateExplosion(Vector2 centerPoint, Damage damage, DetectionType targetDT, int chipLevel)
	{
		float clampObject = ListSystem.GetClampObject(ExplosionEffectArea, chipLevel - 1);
		Damage explosionDamage = GetExplosionDamage(damage, chipLevel);
		ExplosionSystem.TriggerExplosion(clampObject, centerPoint, targetDT, explosionDamage);
	}

	public Damage GetExplosionDamage(Damage damage, int chipLevel)
	{
		float clampObject = ListSystem.GetClampObject(ExplosionDamagePercent, chipLevel - 1);
		float num = UnityEngineSystem.CalcPercent(PlayerDataStore.GetDamageModifier(), Singleton<PlayerDataStore>.Instance.GetCoresDamagePercent());
		float hullDamage = damage.hullDamage * clampObject * num;
		float shieldDamage = damage.shieldDamage * clampObject * num;
		return new Damage(hullDamage, shieldDamage);
	}
}
