using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(AISpawner))]
public class SpawnerStation : MonoBehaviour
{
	private AIFaction aIFaction = AIFaction.Red;

	[Space]
	[SerializeField]
	private float objectHealth;

	private DestructibleObject destructibleObject;

	[Space]
	[SerializeField]
	private List<RewardPack> stationRewardPacksList;

	[SerializeField]
	private int packsDropCount = 1;

	[Space]
	[Header("OnDestroyAction")]
	[SerializeField]
	private int explosionSize;

	[SerializeField]
	private int totalScrapsOnDestroy;

	private int ratePrize = 1;

	private void Awake()
	{
		ratePrize = (int)objectHealth / Singleton<RatingDataStore>.Instance.AIHealthToDestructionRate;
	}

	public void SpawnStation()
	{
		destructibleObject = GetComponent<DestructibleObject>();
		destructibleObject.SetObject(DetectionType.Enemy, destructibleObject.transform);
		destructibleObject.SetObjectHealth(OnDestroyAction, null, null, objectHealth);
		if (GetComponent<AISpawner>() != null)
		{
			GetComponent<SpriteRenderer>().sprite = Singleton<AIDataStore>.Instance.GetRandomStationSpawnerSprite();
		}
		EnableSpawner();
	}

	private void OnDestroyAction()
	{
		DisableSpawner();
		ParticlesSystem.PlayExplosionParticle(base.transform.position, explosionSize);
		SceneSingleton<ScrapsManager>.Instance.SpawnScraps(base.transform.position, totalScrapsOnDestroy, Singleton<AIDataStore>.Instance.GetScrapSpriteList(aIFaction));
		SceneSingleton<RatingSystemManager>.Instance.AddRating(RatingTypes.Destruction, ratePrize);
		SpawnRewardPacks();
		GetComponentInParent<SpawnerStationEventController>().DestroyEvent();
	}

	private void EnableSpawner()
	{
		GetComponent<AISpawner>().enabled = true;
		GetComponent<SpritePulseEffector>()?.StopEffect();
		GetComponent<SpriteRenderer>().color = Color.white;
		GetComponent<Collider2D>().enabled = true;
	}

	private void DisableSpawner()
	{
		GetComponent<AISpawner>().enabled = false;
		GetComponent<SpritePulseEffector>()?.StopEffect();
		GetComponent<SpriteRenderer>().color = Color.gray;
		GetComponent<Collider2D>().enabled = false;
	}

	private void SpawnRewardPacks()
	{
		for (int i = 0; i < packsDropCount; i++)
		{
			RarityTypes randomRarityType = Singleton<RewardDataStore>.Instance.GetRandomRarityType();
			RewardPack rewardPack = Singleton<RewardDataStore>.Instance.GetRewardPack(stationRewardPacksList, randomRarityType);
			SceneSingleton<RewardSystemManager>.Instance.SpawnRewardPack(base.transform.position, rewardPack, randomRarityType);
		}
	}
}
