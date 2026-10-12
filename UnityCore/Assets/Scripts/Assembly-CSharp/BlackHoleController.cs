using System.Collections.Generic;
using UnityEngine;

public class BlackHoleController : MonoBehaviour
{
	private List<GameObject> targetsList;

	private BlackHoleProjectile blackHoleProjectile;

	private DetectionType targetDetectionType;

	[SerializeField]
	private float maxForce;

	[SerializeField]
	private float radius;

	private float effectArea;

	private AudioSource audioSource;

	private Transform blackHoleTransform;

	public void ActivateBlackHole(BlackHoleProjectile blackHoleProjectile, DetectionType targetDetectionType, ChipsContainer chipsContainer)
	{
		blackHoleTransform = base.transform;
		this.blackHoleProjectile = blackHoleProjectile;
		this.targetDetectionType = targetDetectionType;
		effectArea = blackHoleProjectile.projectileEffectArea;
		if (chipsContainer != null && chipsContainer.IsChipActivated(ChipTypes.Mammoth))
		{
			effectArea = Singleton<ChipsDataStore>.Instance.GetMammothArea(effectArea, chipsContainer.GetChipLevel(ChipTypes.Mammoth));
		}
		TweenController.Scale(base.gameObject.transform, 0f, effectArea, TweenDuration.Medium);
		targetsList = new List<GameObject>();
		audioSource = Singleton<AudioManager>.Instance.PlaySFX(AudioClipTypes.Explosion_BlackHole, blackHoleTransform.position);
		Invoke("DestroyBlackHole", blackHoleProjectile.projectileEffectAreaDuration);
	}

	private void DestroyBlackHole()
	{
		foreach (GameObject targets in targetsList)
		{
			if (!(targets == null) && targets.activeSelf)
			{
				targets.GetComponent<IMovable>()?.StopBlackHoleSuck();
			}
		}
		if (audioSource != null)
		{
			Singleton<AudioManager>.Instance.StopLoopedAudioSource(audioSource);
			audioSource = null;
		}
		TweenController.Scale(base.gameObject.transform, effectArea, 0f, TweenDuration.Short, ignoreTimeScale: false, () =>
		{
			MasterPool.ReturnToPoolTransform(base.gameObject, PrefabTypes.Object_BlackHole);
		});
	}

	private void FixedUpdate()
	{
		if (targetsList.Count > 0)
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
				component.TakeDamage(blackHoleProjectile.GetProjectileDamage(item));
			}
		}
	}

	public void OnTriggerEnter2D(Collider2D other)
	{
		IDetectable component = other.GetComponent<IDetectable>();
		if (component != null && component.IsDetectionType(targetDetectionType))
		{
			IMovable component2 = other.GetComponent<IMovable>();
			if (component2 != null)
			{
				Vector3 targetPos = blackHoleTransform.position + (Vector3)(Random.insideUnitCircle.normalized * radius);
				component2.StartBlackHoleSuck(targetPos, maxForce);
			}
			targetsList.Add(other.gameObject);
		}
	}

	private void OnTriggerExit2D(Collider2D other)
	{
		if (targetsList.Contains(other.gameObject))
		{
			other.GetComponent<IMovable>()?.StopBlackHoleSuck();
			targetsList.Remove(other.gameObject);
		}
	}
}
