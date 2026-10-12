using UnityEngine;

public class ParticlesSystem : Singleton<ParticlesSystem>
{
	public static void PlayAreaExplosionParticle(Vector2 pos, float radius)
	{
		ObjectSystem.ReScale(MasterPool.GetPos(PrefabTypes.Particle_AreaEffect, pos), radius);
	}

	public static void PlayExplosionParticle(Vector2 pos, float radius)
	{
		if (radius <= 1f)
		{
			Singleton<AudioManager>.Instance.PlaySFX(AudioClipTypes.Explosion_Tiny, pos);
		}
		else if (radius <= 2f)
		{
			Singleton<AudioManager>.Instance.PlaySFX(AudioClipTypes.Explosion_Small, pos);
		}
		else
		{
			Singleton<AudioManager>.Instance.PlaySFX(AudioClipTypes.Explosion_Big, pos);
		}
		if (radius >= 5f)
		{
			SceneSingleton<CameraManager>.Instance.ShakeCamera(0.5f);
		}
		ObjectSystem.ReScale(MasterPool.GetPos(PrefabTypes.Particle_Explosion, pos), radius);
	}

	public static DeActivateAfterTime PlayEMPShockParticle(Transform shockedTransform, float duration)
	{
		GameObject obj = MasterPool.Get(PrefabTypes.Particle_EMPShock, shockedTransform);
		obj.transform.parent = shockedTransform;
		obj.transform.localPosition = Vector2.zero;
		DeActivateAfterTime component = obj.GetComponent<DeActivateAfterTime>();
		component.SetDuration(duration);
		return component;
	}

	public static void PlayParticle(Vector2 pos, PrefabTypes particleType)
	{
		MasterPool.GetPos(particleType, pos);
	}

	public static void PlayParticle(Transform transform, PrefabTypes particleType)
	{
		MasterPool.GetPos(particleType, transform.position, transform.rotation);
	}

	public static void PlayProjectileImpactParticle(Vector2 pos)
	{
		if (Random.Range(0, 100) > 50)
		{
			MasterPool.GetPos(PrefabTypes.Particle_ProjectileImpact_1, pos);
		}
		else
		{
			MasterPool.GetPos(PrefabTypes.Particle_ProjectileImpact_2, pos);
		}
	}

	public static void PlayProjectieShieldImpactParticle(Vector2 pos)
	{
		if (Random.Range(0, 100) > 50)
		{
			MasterPool.GetPos(PrefabTypes.Particle_ProjectileShieldImpact_1, pos);
		}
		else
		{
			MasterPool.GetPos(PrefabTypes.Particle_ProjectileShieldImpact_2, pos);
		}
	}
}
