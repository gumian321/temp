using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering;

public class AIBossUnit : AISwarmingUnit
{
	private Action onBossDestroy;

	private List<AIBossPartController> partsList;

	[Space]
	[SerializeField]
	private List<ParticleSystem> EnginesList;

	[Space]
	[SerializeField]
	private GameObject mapIconArrow;

	[SerializeField]
	private SpriteRenderer mapIconSpriteRenderer;

	private AIBossUnitMovement aIBossUnitMovement;

	private AIBossBoostSystem aIBossBoostSystem;

	private AIWarpManager aIWarpManager;

	private Dictionary<AIBossPartTypes, AIBossPart> bossPartsDict;

	[Space]
	[SerializeField]
	private float bossActionRadiuos = 20f;

	[SerializeField]
	private float bossRangeModifer = 0.3f;

	[SerializeField]
	private float bossDamageModifer = 1f;

	[Space]
	[SerializeField]
	private List<RewardPack> rewardPacksList;

	[Space]
	[SerializeField]
	private int bossRating;

	public bool isBossActivated;

	private void OnEnable()
	{
		aIBossBoostSystem = GetComponent<AIBossBoostSystem>();
		aIBossUnitMovement = GetComponent<AIBossUnitMovement>();
		aIWarpManager = GetComponent<AIWarpManager>();
		bossPartsDict = new Dictionary<AIBossPartTypes, AIBossPart>();
	}

	protected override void DisableUnit()
	{
		base.DisableUnit();
		DeActivateUnit();
	}

	protected override void ActivateUnit()
	{
		base.ActivateUnit();
		if (!isBossActivated)
		{
			SceneSingleton<GameManager>.Instance.ActivateBoss();
		}
		isBossActivated = true;
	}

	private void DeActivateUnit()
	{
		if (isBossActivated)
		{
			SceneSingleton<GameManager>.Instance.DectivateBoss();
		}
		isBossActivated = false;
	}

	public void SetBoss(Action onBossDestroy)
	{
		BuildUnit();
		actionDis = bossActionRadiuos;
		aICoreControllersList.Clear();
		this.onBossDestroy = onBossDestroy.Invoke;
		partsList = new List<AIBossPartController>();
		partsList.AddRange(GetComponentsInChildren<AIBossPartController>().ToList());
		aIBossBoostSystem.SetboostActionRadius(bossActionRadiuos);
		SceneSingleton<GameHeatManager>.Instance.OnHeatTimerChange += ChangeSpeed;
		aIBossUnitMovement.ChangeSpeed(0f);
		foreach (AIBossPartController parts in partsList)
		{
			AIBossPart aIBossPart;
			if (bossPartsDict.ContainsKey(parts.GetAIBossPartTypes()))
			{
				aIBossPart = bossPartsDict[parts.GetAIBossPartTypes()];
			}
			else
			{
				bossPartsDict.Add(parts.GetAIBossPartTypes(), Singleton<AIDataStore>.Instance.GetAIBossPart(aIThreatLevel, parts.GetAIBossPartTypes()));
				aIBossPart = bossPartsDict[parts.GetAIBossPartTypes()];
			}
			parts.SetBossPart(this, aIBossPart);
			parts.BuildUnit();
			parts.UpdateRange(bossRangeModifer);
			parts.OverrideDamage(bossDamageModifer * SceneSingleton<GameMissionManager>.Instance.enemiesDamageModifier);
		}
	}

	public void PartDestroyed(AIBossPartController aIBossPart)
	{
		if (partsList.Count != 0)
		{
			SpawnDisabledPart(aIBossPart);
			partsList.Remove(aIBossPart);
			UnityEngine.Object.Destroy(aIBossPart.gameObject);
			if (aIWarpManager != null)
			{
				aIWarpManager.CheckWarp(partsList.Count, targetTransform, TurnPartsCollidersOff, TurnPartsCollidersOn);
			}
			if (partsList.Count == 0)
			{
				DestroyBoss();
			}
		}
	}

	private void TurnPartsCollidersOn()
	{
		foreach (AIBossPartController parts in partsList)
		{
			parts.TunrCollider(x: true);
		}
	}

	private void TurnPartsCollidersOff()
	{
		foreach (AIBossPartController parts in partsList)
		{
			parts.TunrCollider(x: false);
		}
	}

	private void DestroyBoss()
	{
		mapIconArrow.SetActive(value: false);
		GetComponent<AIBossBoostSystem>().enabled = false;
		aISwarmingUnitMovement.enabled = false;
		SceneSingleton<ScrapsManager>.Instance.SpawnScraps(base.transform.position, scrapsCount, Singleton<AIDataStore>.Instance.GetScrapSpriteList(aIFaction));
		ParticlesSystem.PlayExplosionParticle(base.transform.position, explosionSize);
		foreach (RewardPack rewardPacks in rewardPacksList)
		{
			SceneSingleton<RewardSystemManager>.Instance.SpawnRewardPack(base.transform.position, rewardPacks, RarityTypes.Legendery);
		}
		foreach (ParticleSystem engines in EnginesList)
		{
			engines.Stop();
		}
		GetComponent<SortingGroup>().sortingLayerName = "Background";
		mapIconSpriteRenderer.color = Color.gray;
		base.transform.parent = null;
		Singleton<GameAchievementsManager>.Instance?.Add_BossKilled(aIThreatLevel);
		SceneSingleton<RatingSystemManager>.Instance.AddRating(RatingTypes.Boss, bossRating);
		SceneSingleton<GameManager>.Instance.DectivateBoss();
		if (onBossDestroy != null)
		{
			onBossDestroy();
		}
		GetComponent<TweenScaleDisable>().enabled = true;
		GetComponent<AIBossUnit>().enabled = false;
	}

	public void ChangeSpeed(float heatPercent)
	{
		if (Singleton<DemoBuildManager>.Instance != null && Singleton<DemoBuildManager>.Instance.IsDemoEnabled() && aIThreatLevel == AIThreatLevel.Boss && heatPercent > 0.4f)
		{
			heatPercent *= 2f;
		}
		if (isBossActivated)
		{
			aIBossUnitMovement.ChangeSpeed((heatPercent < 1f) ? 1f : heatPercent);
		}
		else
		{
			aIBossUnitMovement.ChangeSpeed(heatPercent);
		}
	}

	private void SpawnDisabledPart(AIBossPartController aIBossPart)
	{
		GameObject pos = MasterPool.GetPos(PrefabTypes.AI_Part_Disabled, aIBossPart.transform.position, aIBossPart.transform.rotation);
		pos.transform.parent = base.transform;
		SpriteRenderer component = pos.GetComponent<SpriteRenderer>();
		SpriteRenderer component2 = aIBossPart.GetComponent<SpriteRenderer>();
		component.sprite = component2.sprite;
		component.flipX = component2.flipX;
		component.flipY = component2.flipY;
		component.sortingLayerName = component2.GetComponent<SortingGroup>().sortingLayerName;
		component.sortingOrder = component2.GetComponent<SortingGroup>().sortingOrder;
	}
}
