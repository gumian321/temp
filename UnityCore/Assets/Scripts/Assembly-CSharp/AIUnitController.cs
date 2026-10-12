using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

public class AIUnitController : MonoBehaviour, IStunnable
{
	protected Action OnDestroyAction;

	[SerializeField]
	private bool buildOnAwake;

	[Space]
	[Header("AI Faction Data")]
	[SerializeField]
	protected AIFaction aIFaction;

	[SerializeField]
	protected AIThreatLevel aIThreatLevel;

	[Space]
	[Header("AI Values")]
	[SerializeField]
	protected float maxHealth;

	protected int ratePrize = 1;

	[SerializeField]
	protected int scrapsCount = 1;

	[SerializeField]
	protected float explosionSize = 1f;

	[SerializeField]
	public float formationSize = 1f;

	protected DestructibleObject unitObject;

	private AIUnitMovement aIUnitMovement;

	private AIMapIconController aIMapIconController;

	protected List<AICoreController> aICoreControllersList;

	[SerializeField]
	private bool canBeStunned = true;

	private float stunTimer;

	protected bool isStunned;

	private DeActivateAfterTime empShockParticle;

	private float shakeAmount = AIDataStore.GetAIShakeAmount();

	private bool isCoresDisabled;

	protected RadarSystem radarSystem;

	[Space]
	[Header("Radar Values")]
	[SerializeField]
	private DetectionType targetDetectionType = DetectionType.Player;

	[SerializeField]
	private RadarConfiguration rct;

	[SerializeField]
	protected bool AddCenterialzedRadar;

	private bool IsRadarOverriden;

	public void SetOnDestroyAction(Action a)
	{
		OnDestroyAction = a.Invoke;
	}

	public AIThreatLevel GetAIThreatLevel()
	{
		return aIThreatLevel;
	}

	private void Awake()
	{
		ratePrize = (int)maxHealth / Singleton<RatingDataStore>.Instance.AIHealthToDestructionRate;
	}

	public void SetAIFaction(AIFaction aIFaction)
	{
		this.aIFaction = aIFaction;
	}

	public virtual void BuildUnit()
	{
		IsRadarOverriden = false;
		aIUnitMovement = GetComponent<AIUnitMovement>();
		if (aIUnitMovement != null)
		{
			aIUnitMovement.SetMovement(this);
		}
		unitObject = GetComponent<DestructibleObject>();
		if (unitObject != null)
		{
			unitObject.SetObject(Singleton<DetectionDataStore>.Instance.GetDetectionType(base.gameObject), base.transform);
			unitObject.SetObjectHealth(DestroyUnit, null, null, UnityEngineSystem.GetPercent(maxHealth, SceneSingleton<GameMissionManager>.Instance.enemiesHealthModifier));
		}
		targetDetectionType = Singleton<DetectionDataStore>.Instance.GetTargetDetectionType(base.gameObject);
		aICoreControllersList = GetComponentsInChildren<AICoreController>(includeInactive: true).ToList();
		foreach (AICoreController aICoreControllers in aICoreControllersList)
		{
			aICoreControllers.gameObject.layer = Singleton<DetectionDataStore>.Instance.GetLayerNumber(Singleton<DetectionDataStore>.Instance.GetDetectionType(base.gameObject));
			aICoreControllers.BuildCore();
		}
		if (AddCenterialzedRadar)
		{
			CreateCenteralizedRadar();
		}
		aIMapIconController = GetComponent<AIMapIconController>();
		if (aIMapIconController != null)
		{
			aIMapIconController.SetUpAIMapIconController(aIFaction, aIThreatLevel);
		}
		EndStun();
	}

	public void SetMaxHealth(float health)
	{
		unitObject.SetMaxHealth(health);
	}

	public void RefreshAIMapIconController(AIFaction newAIFaction = AIFaction.None, AIThreatLevel newAIThreatLevel = AIThreatLevel.None)
	{
		if (newAIFaction == AIFaction.None)
		{
			newAIFaction = aIFaction;
		}
		if (newAIThreatLevel == AIThreatLevel.None)
		{
			newAIThreatLevel = aIThreatLevel;
		}
		if (aIMapIconController != null)
		{
			aIMapIconController.SetUpAIMapIconController(newAIFaction, newAIThreatLevel);
		}
	}

	public void UpdateRange(float percent)
	{
		if (!AddCenterialzedRadar)
		{
			foreach (AICoreController aICoreControllers in aICoreControllersList)
			{
				aICoreControllers.UpdateRange(percent);
			}
			return;
		}
		if (radarSystem == null)
		{
			foreach (AICoreController aICoreControllers2 in aICoreControllersList)
			{
				aICoreControllers2.UpdateRange(percent);
			}
			return;
		}
		float radarRange = UnityEngineSystem.CalcPercent(GetRadarRange(), percent);
		radarSystem.RescaleRadar(radarRange);
	}

	public void OverrideDamage(float percent)
	{
		foreach (AICoreController aICoreControllers in aICoreControllersList)
		{
			aICoreControllers.OverrideDamage(percent);
		}
	}

	public virtual void DestroyUnit()
	{
		if (radarSystem != null && !IsRadarOverriden)
		{
			MasterPool.ReturnToPoolTransform(radarSystem.gameObject, PrefabTypes.ShipSystem_Radar);
			radarSystem = null;
		}
		EndStun();
		SceneSingleton<ScrapsManager>.Instance.SpawnScraps(base.transform.position, scrapsCount, Singleton<AIDataStore>.Instance.GetScrapSpriteList(aIFaction));
		ParticlesSystem.PlayExplosionParticle(base.transform.position, explosionSize);
		SceneSingleton<RatingSystemManager>.Instance.AddRating(RatingTypes.Destruction, ratePrize);
		foreach (AICoreController aICoreControllers in aICoreControllersList)
		{
			aICoreControllers.UnitDestroyed();
		}
		base.gameObject.SetActive(value: false);
		if (OnDestroyAction != null)
		{
			OnDestroyAction();
		}
	}

	public virtual void DestroyFarUnit()
	{
		if (empShockParticle != null)
		{
			empShockParticle.DeActivate();
		}
		foreach (AICoreController aICoreControllers in aICoreControllersList)
		{
			aICoreControllers.UnitDestroyed();
		}
		base.gameObject.SetActive(value: false);
	}

	public void Stun(float stunDuration)
	{
		if (canBeStunned)
		{
			stunTimer = Time.time + stunDuration;
			if (GetCoresCount() == 0f && empShockParticle == null)
			{
				empShockParticle = ParticlesSystem.PlayEMPShockParticle(base.transform, stunDuration);
			}
			else
			{
				StunCores(stunDuration);
			}
			if (empShockParticle != null)
			{
				empShockParticle.SetDuration(stunDuration);
			}
			isStunned = true;
			if (aIUnitMovement != null)
			{
				aIUnitMovement.Stun();
			}
		}
	}

	public bool IsStunned()
	{
		return isStunned;
	}

	public void EndStun()
	{
		if (empShockParticle != null)
		{
			empShockParticle.DeActivate();
		}
		empShockParticle = null;
		isStunned = false;
		if (aIUnitMovement != null)
		{
			aIUnitMovement.EndStun();
		}
	}

	public virtual void FixedUpdate()
	{
		if (isStunned && stunTimer < Time.time)
		{
			EndStun();
		}
	}

	public void StunCores(float stunDuration)
	{
		foreach (AICoreController aICoreControllers in aICoreControllersList)
		{
			aICoreControllers.Stun(stunDuration);
		}
	}

	public void DisableCores()
	{
		if (isCoresDisabled)
		{
			return;
		}
		foreach (AICoreController aICoreControllers in aICoreControllersList)
		{
			aICoreControllers.DisableCore();
		}
		isCoresDisabled = true;
	}

	public void ActivateCores()
	{
		if (!isCoresDisabled)
		{
			return;
		}
		foreach (AICoreController aICoreControllers in aICoreControllersList)
		{
			aICoreControllers.ActivateCore();
		}
		isCoresDisabled = false;
	}

	public float GetCoresCount()
	{
		return aICoreControllersList.Count;
	}

	public void ClearRadar()
	{
		radarSystem = null;
	}

	public void OverrideRadar(RadarSystem overrideRadarSystem)
	{
		if (radarSystem != null)
		{
			MasterPool.ReturnToPoolTransform(radarSystem.gameObject, PrefabTypes.ShipSystem_Radar);
			radarSystem = null;
		}
		radarSystem = overrideRadarSystem;
		foreach (AICoreController aICoreControllers in aICoreControllersList)
		{
			aICoreControllers.OverrideCoreRadar(radarSystem);
		}
		IsRadarOverriden = true;
	}

	public void CreateCenteralizedRadar()
	{
		float radarRange = GetRadarRange();
		if (radarRange == 0f)
		{
			return;
		}
		ActivateRadar(radarRange, targetDetectionType, rct);
		foreach (AICoreController aICoreControllers in aICoreControllersList)
		{
			aICoreControllers.OverrideCoreRadar(radarSystem);
		}
	}

	public void ActivateRadar(float turretRange, DetectionType radarDetectionType, RadarConfiguration rct)
	{
		if (!(radarSystem != null))
		{
			radarSystem = MasterPool.Get(PrefabTypes.ShipSystem_Radar, base.transform).GetComponent<RadarSystem>();
			radarSystem.SetRadarSystem(turretRange, radarDetectionType, null, rct);
		}
	}

	private float GetRadarRange()
	{
		int num = 0;
		float num2 = 0f;
		foreach (AICoreController aICoreControllers in aICoreControllersList)
		{
			float coreRadarRange = aICoreControllers.GetCoreRadarRange();
			if (coreRadarRange != -1f)
			{
				num2 += coreRadarRange;
				num++;
			}
		}
		if (num != 0)
		{
			return num2 / (float)num;
		}
		return 0f;
	}

	public RadarSystem GetUnitRadarSystem()
	{
		return radarSystem;
	}
}
