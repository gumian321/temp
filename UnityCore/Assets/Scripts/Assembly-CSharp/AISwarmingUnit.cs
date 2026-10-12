using UnityEngine;

[RequireComponent(typeof(AISwarmingUnitMovement))]
public class AISwarmingUnit : AIUnitController
{
	[Header("target transform")]
	[SerializeField]
	private bool followTransform;

	[SerializeField]
	private Transform BossFleetTransform;

	protected Transform targetTransform;

	private Transform aITransform;

	protected AISwarmingUnitMovement aISwarmingUnitMovement;

	[Space]
	[Header("Distnaces")]
	[SerializeField]
	private bool calculateDistances = true;

	[SerializeField]
	private float stoppingdDis;

	protected float actionDis;

	[SerializeField]
	private bool UseActionDistance;

	[Space]
	[SerializeField]
	private bool isDisableIfFar = true;

	private float deSpawningRadius = 100f;

	[Space]
	[Header("Radar")]
	[SerializeField]
	private RadarConfiguration radarConfiguration;

	private RadarSystem TargetingRadarSystem;

	public void SetBossFleetTransform(Transform t)
	{
		BossFleetTransform = t;
		base.transform.position = BossFleetTransform.position;
		followTransform = true;
		calculateDistances = false;
		stoppingdDis = 0.5f;
	}

	public override void BuildUnit()
	{
		base.BuildUnit();
		deSpawningRadius = Singleton<AIDataStore>.Instance.GetDeSpawningRadius();
		aITransform = base.transform;
		TargetingRadarSystem = SceneSingleton<PlayerCenterRadar>.Instance.GetRadarSystem(DetectionType.Player);
		aISwarmingUnitMovement = GetComponent<AISwarmingUnitMovement>();
		SceneSingleton<GameHeatManager>.Instance.OnPlayerHeatChange += RefreshTarget;
		SetDistances();
		RefreshTarget();
		if (!UseActionDistance)
		{
			ActivateUnit();
		}
	}

	public void RefreshTarget()
	{
		if (followTransform)
		{
			targetTransform = BossFleetTransform;
		}
		else
		{
			targetTransform = TargetingRadarSystem.GetTarget(aITransform.position, radarConfiguration);
		}
		aISwarmingUnitMovement.SetMoveTarget(targetTransform);
	}

	public override void FixedUpdate()
	{
		base.FixedUpdate();
		if (targetTransform == null)
		{
			RefreshTarget();
			if (targetTransform == null)
			{
				return;
			}
		}
		float num = Vector3.Distance(targetTransform.position, aITransform.position);
		if (isDisableIfFar && num > deSpawningRadius)
		{
			DestroyFarUnit();
			return;
		}
		aISwarmingUnitMovement.SetIsMoving(num > stoppingdDis);
		if (UseActionDistance)
		{
			if (num > actionDis)
			{
				DisableUnit();
			}
			else
			{
				ActivateUnit();
			}
		}
	}

	protected virtual void DisableUnit()
	{
		DisableCores();
	}

	protected virtual void ActivateUnit()
	{
		ActivateCores();
	}

	public override void DestroyUnit()
	{
		if (GetComponent<KamikazeTrigger>() != null)
		{
			GetComponent<KamikazeTrigger>().TriggerExplosion();
		}
		SceneSingleton<GameHeatManager>.Instance.OnPlayerHeatChange -= RefreshTarget;
		Singleton<GameAchievementsManager>.Instance?.Add_ShipsDestroyed();
		base.DestroyUnit();
	}

	public override void DestroyFarUnit()
	{
		if (OnDestroyAction != null)
		{
			OnDestroyAction();
		}
		SceneSingleton<GameHeatManager>.Instance.OnPlayerHeatChange -= RefreshTarget;
		base.DestroyFarUnit();
	}

	private void SetDistances()
	{
		if (!calculateDistances)
		{
			actionDis = stoppingdDis * 1.5f;
		}
		else
		{
			if (aICoreControllersList.Count == 0)
			{
				return;
			}
			float num = 9999f;
			foreach (AICoreController aICoreControllers in aICoreControllersList)
			{
				float coreRadarRange = aICoreControllers.GetCoreRadarRange();
				if (coreRadarRange != -1f && coreRadarRange < num)
				{
					num = coreRadarRange;
				}
			}
			if (num != 9999f)
			{
				stoppingdDis = num * 0.8f;
				actionDis = num;
			}
		}
	}
}
