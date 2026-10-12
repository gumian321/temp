using System;
using System.Linq;
using UnityEngine;

[RequireComponent(typeof(DestructibleObject))]
public class AIStationPartController : AIUnitController
{
	private SpriteRenderer spriteRenderer;

	[SerializeField]
	private SpriteRenderer mapIconSpriteRenderer;

	private AIStationPart aIStationPart;

	private Action<AIStationPartController, Sprite> OnPartDestroyed;

	public void SetStationPart(Action<AIStationPartController, Sprite> OnPartDestroyed, AIStationPart aIStationPart, RadarSystem radarSystem = null, AIFaction aIFaction = AIFaction.Red)
	{
		this.OnPartDestroyed = OnPartDestroyed;
		this.aIStationPart = aIStationPart;
		spriteRenderer = GetComponent<SpriteRenderer>();
		SetCores();
		BuildUnit();
		foreach (AICoreController aICoreControllers in aICoreControllersList)
		{
			aICoreControllers.gameObject.SetActive(value: true);
		}
		if (radarSystem != null)
		{
			OverrideRadar(radarSystem);
		}
		base.aIFaction = aIFaction;
		if (mapIconSpriteRenderer != null)
		{
			mapIconSpriteRenderer.color = Singleton<AIDataStore>.Instance.GetFactionColor(aIFaction);
		}
		UpdateRange(0.3f);
	}

	public AIThreatLevel GetPartThreatLevel()
	{
		return aIStationPart.aIThreatLevel;
	}

	private void SetCores()
	{
		aICoreControllersList = GetComponentsInChildren<AICoreController>(includeInactive: true).ToList();
		if (aIStationPart.coresList.Count != aICoreControllersList.Count)
		{
			Debug.LogError("AI Spawn Point Cores Count does not match the Station Level");
		}
		for (int i = 0; i < aIStationPart.coresList.Count; i++)
		{
			aICoreControllersList[i].core = aIStationPart.coresList[i];
		}
	}

	public void SetStationPartSprite()
	{
		spriteRenderer.sprite = Singleton<AIDataStore>.Instance.GetStationLevelSprite(aIFaction, aIThreatLevel);
	}

	public override void DestroyUnit()
	{
		foreach (AICoreController aICoreControllers in aICoreControllersList)
		{
			aICoreControllers.DisableCore();
			aICoreControllers.gameObject.SetActive(value: false);
		}
		if (mapIconSpriteRenderer != null)
		{
			mapIconSpriteRenderer.color = Singleton<AIDataStore>.Instance.GetDisabledColor();
			mapIconSpriteRenderer.transform.parent = base.transform.parent;
		}
		if (OnPartDestroyed != null)
		{
			OnPartDestroyed(this, spriteRenderer.sprite);
		}
		DisableUnit();
		base.DestroyUnit();
	}

	public void DisableUnit()
	{
		ClearRadar();
		MasterPool.ReturnToPoolTransform(base.gameObject, aIStationPart.prefabType);
	}
}
