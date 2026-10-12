using System;
using UnityEngine;

[Serializable]
public class Damage
{
	public float hullDamage = 1f;

	public float shieldDamage = 1f;

	public float shieldHitDamageReduction = 0.25f;

	public Damage(float hullDamage, float shieldDamage)
	{
		this.hullDamage = hullDamage;
		this.shieldDamage = shieldDamage;
	}

	public float GetDamage(GameObject target)
	{
		if (Singleton<DetectionDataStore>.Instance.IsShieldLayer(target))
		{
			return shieldDamage;
		}
		return hullDamage;
	}

	public float GetTickDamage(GameObject target)
	{
		if (Singleton<DetectionDataStore>.Instance.IsShieldLayer(target))
		{
			return UnityEngineSystem.GetTickAmount(shieldDamage);
		}
		return UnityEngineSystem.GetTickAmount(hullDamage);
	}
}
