using System.Collections.Generic;
using UnityEngine;

public class ContinuousProjectileContoller : ProjectileController
{
	private List<GameObject> targetsList;

	private ParticleSystem continuousParticleSystem;

	private Collider2D col2D;

	private bool isActivated;

	private float startingY = 1.2f;

	public override void SetProjectile(Projectile projectile, DetectionType turretTargetDetectionType, ChipsContainer chipsContainer = null, Transform projectileTarget = null)
	{
		base.SetProjectile(projectile, turretTargetDetectionType, chipsContainer, projectileTarget);
		targetsList = new List<GameObject>();
		ContinuousProjectile continuousProjectile = (ContinuousProjectile)projectile;
		if (continuousParticleSystem != null)
		{
			Object.Destroy(continuousParticleSystem.gameObject);
		}
		continuousParticleSystem = Object.Instantiate(continuousProjectile.continuousParticleSystem, base.transform).GetComponent<ParticleSystem>();
		col2D = GetComponent<Collider2D>();
		startingY = base.transform.localPosition.y;
	}

	public void ActivatePorjectile()
	{
		if (!isActivated)
		{
			isActivated = true;
			targetsList.Clear();
			if (!continuousParticleSystem.isPlaying)
			{
				continuousParticleSystem.Play();
			}
			col2D.enabled = true;
		}
	}

	public void DeactivatePorjectile()
	{
		if (isActivated)
		{
			isActivated = false;
			continuousParticleSystem.Stop();
			continuousParticleSystem.Clear();
			col2D.enabled = false;
		}
	}

	public void UpdateRange(float newRange)
	{
		Vector2 vector = base.gameObject.transform.localPosition;
		vector.y = newRange / startingY;
		base.gameObject.transform.localPosition = vector;
		Vector2 vector2 = base.gameObject.transform.localScale;
		vector2.y = newRange;
		base.gameObject.transform.localScale = vector2;
	}

	public override void FixedUpdate()
	{
		if (isActivated && targetsList.Count > 0)
		{
			DamageTargets();
		}
	}

	private void DamageTargets()
	{
		foreach (GameObject item in new List<GameObject>(targetsList))
		{
			if (!(item == null) && item.activeInHierarchy)
			{
				IDamageable component = item.GetComponent<IDamageable>();
				if (component == null)
				{
					break;
				}
				component.TakeDamage(GetProjectileDamage(item));
			}
		}
	}

	public override void OnTriggerEnter2D(Collider2D other)
	{
		IDetectable component = other.GetComponent<IDetectable>();
		if (component != null && component.IsDetectionType(projectileTargetDetectionType))
		{
			targetsList.Add(other.gameObject);
		}
	}

	private void OnTriggerExit2D(Collider2D other)
	{
		if (targetsList.Contains(other.gameObject))
		{
			targetsList.Remove(other.gameObject);
		}
	}
}
