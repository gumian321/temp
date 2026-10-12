using System;
using System.Collections.Generic;
using UnityEngine;

public class TraderUnit : AIUnitController
{
	private Action onUnitDestroyed;

	[Space]
	[Header("Health Bar")]
	[SerializeField]
	private GameObject HealthBarObject;

	[SerializeField]
	private SpriteRenderer HealthBarSprite;

	[SerializeField]
	private float HealthBarZeroY = -0.56f;

	[Space]
	[SerializeField]
	private SpriteRenderer mapIcon;

	[Space]
	[SerializeField]
	private List<RewardPack> rewardPacksList;

	[SerializeField]
	private int packsDropCount = 2;

	public bool isSpawnRewardPack;

	public void ActivateHealthBar()
	{
		HealthBarObject.SetActive(value: true);
		unitObject.SetOnHealthDamageAction(OnHealthDamage);
	}

	public void OnHealthDamage(float currentHealth)
	{
		float num = currentHealth / maxHealth;
		HealthBarSprite.size = new Vector2(1f, num);
		HealthBarSprite.transform.localPosition = new Vector2(HealthBarSprite.transform.localPosition.x, (1f - num) * HealthBarZeroY);
	}

	public void SetOnUnitDestroy(Action a)
	{
		onUnitDestroyed = a.Invoke;
	}

	public SpriteRenderer GetMapIcon()
	{
		return mapIcon;
	}

	public override void DestroyUnit()
	{
		if (onUnitDestroyed != null)
		{
			onUnitDestroyed();
		}
		SceneSingleton<ScrapsManager>.Instance.SpawnScraps(base.transform.position, scrapsCount, Singleton<AIDataStore>.Instance.GetScrapSpriteList(aIFaction));
		ParticlesSystem.PlayExplosionParticle(base.transform.position, explosionSize);
		if (isSpawnRewardPack)
		{
			SpawnRewardPacks();
		}
		base.gameObject.SetActive(value: false);
	}

	private void SpawnRewardPacks()
	{
		for (int i = 0; i < packsDropCount; i++)
		{
			RarityTypes randomRarityType = Singleton<RewardDataStore>.Instance.GetRandomRarityType();
			RewardPack rewardPack = Singleton<RewardDataStore>.Instance.GetRewardPack(rewardPacksList, randomRarityType);
			SceneSingleton<RewardSystemManager>.Instance.SpawnRewardPack(base.transform.position, rewardPack, randomRarityType);
		}
	}
}
