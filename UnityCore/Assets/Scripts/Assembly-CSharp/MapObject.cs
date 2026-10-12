using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(DestructibleObject))]
public class MapObject : MonoBehaviour
{
	[SerializeField]
	protected float objectHealth;

	private DestructibleObject destructibleObject;

	[Space]
	[SerializeField]
	private int totalScraps;

	[SerializeField]
	private int totalScrapsOnDestroy;

	private int spawnedScraps;

	[Space]
	[SerializeField]
	private int explosionSize = 1;

	private int ratePrize = 1;

	[Space]
	[SerializeField]
	private List<Sprite> scrapsList;

	private void Awake()
	{
		ratePrize = (int)objectHealth / Singleton<RatingDataStore>.Instance.AIHealthToDestructionRate;
		destructibleObject = GetComponent<DestructibleObject>();
		destructibleObject.SetObject(DetectionType.Enemy, destructibleObject.transform);
	}

	protected void Reset()
	{
		destructibleObject.SetObjectHealth(OnDestroyAction, OnHealthChange, null, objectHealth);
	}

	protected virtual void OnDestroyAction()
	{
		ParticlesSystem.PlayExplosionParticle(base.transform.position, explosionSize);
		SceneSingleton<ScrapsManager>.Instance.SpawnScraps(base.transform.position, totalScrapsOnDestroy, scrapsList);
		SceneSingleton<RatingSystemManager>.Instance.AddRating(RatingTypes.Destruction, ratePrize);
		base.gameObject.SetActive(value: false);
	}

	private void OnHealthChange(float health)
	{
		int num = Mathf.RoundToInt((1f - health / objectHealth) * (float)totalScraps) - spawnedScraps;
		if (num != 0)
		{
			SceneSingleton<ScrapsManager>.Instance.SpawnScraps(base.transform.position, num, scrapsList);
		}
		spawnedScraps += num;
	}
}
