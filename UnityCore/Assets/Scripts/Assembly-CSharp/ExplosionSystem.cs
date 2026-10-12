using System.Collections.Generic;
using System.Linq;
using UnityEngine;

public class ExplosionSystem : MonoBehaviour
{
	public static List<GameObject> TriggerExplosion(float range, Vector2 centerPoint, DetectionType targetDT, Damage damage, bool isShieldHit = false)
	{
		ParticlesSystem.PlayAreaExplosionParticle(centerPoint, range);
		List<Collider2D> list = Physics2D.OverlapCircleAll(centerPoint, range).ToList();
		List<GameObject> list2 = new List<GameObject>();
		foreach (Collider2D item in list)
		{
			if (item == null)
			{
				continue;
			}
			IDetectable component = item.GetComponent<IDetectable>();
			if (component == null || !component.IsDetectionType(targetDT))
			{
				continue;
			}
			IDamageable component2 = item.GetComponent<IDamageable>();
			if (component2 != null)
			{
				float num = damage.GetDamage(item.gameObject);
				if (isShieldHit)
				{
					num *= damage.shieldHitDamageReduction;
				}
				component2.TakeDamage(num);
				list2.Add(item.gameObject);
			}
		}
		return list2;
	}
}
