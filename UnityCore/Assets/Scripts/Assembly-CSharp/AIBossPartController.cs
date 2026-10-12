using System.Collections.Generic;
using UnityEngine;

public class AIBossPartController : AIUnitController
{
	[Space]
	[Header("AIBossPartController")]
	[SerializeField]
	private AIBossPartTypes aIBossPartType;

	private List<Core> coresList;

	private AIBossUnit aIBossUnit;

	private AIBossPart aIBossPart;

	[SerializeField]
	private Collider2D partCollider;

	[SerializeField]
	private Rigidbody2D rb;

	public AIBossPartTypes GetAIBossPartTypes()
	{
		return aIBossPartType;
	}

	private void Awake()
	{
		partCollider = GetComponent<Collider2D>();
		rb = GetComponent<Rigidbody2D>();
	}

	public void TunrCollider(bool x)
	{
		partCollider.enabled = x;
		rb.simulated = x;
	}

	public override void BuildUnit()
	{
		base.BuildUnit();
		SetCores();
		CreateCenteralizedRadar();
	}

	public void SetBossPart(AIBossUnit aIBossUnit, AIBossPart aIBossPart)
	{
		this.aIBossUnit = aIBossUnit;
		this.aIBossPart = aIBossPart;
	}

	private void SetCores()
	{
		coresList = new List<Core>(aIBossPart.coresList);
		if (coresList.Count != aICoreControllersList.Count)
		{
			Debug.LogError("Cores Count does not match the Boss Part");
		}
		for (int i = 0; i < coresList.Count; i++)
		{
			aICoreControllersList[i].BuildCore(coresList[i]);
			aICoreControllersList[i].GetCurrentCore().ActivateCore(aICoreControllersList[i]);
			aICoreControllersList[i].gameObject.SetActive(value: true);
		}
	}

	public override void DestroyUnit()
	{
		SceneSingleton<ScrapsManager>.Instance.SpawnScraps(base.transform.position, scrapsCount, Singleton<AIDataStore>.Instance.GetScrapSpriteList(aIFaction));
		ParticlesSystem.PlayExplosionParticle(base.transform.position, explosionSize);
		foreach (AICoreController aICoreControllers in aICoreControllersList)
		{
			aICoreControllers.GetCurrentCore().DestroyCore(aICoreControllers);
		}
		aIBossUnit.PartDestroyed(this);
		Object.Destroy(base.gameObject);
	}
}
