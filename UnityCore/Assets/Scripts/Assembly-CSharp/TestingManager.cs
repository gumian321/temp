using System.Collections.Generic;
using UnityEngine;

public class TestingManager : Singleton<TestingManager>
{
	[Space]
	[Header("Testing Control Panel")]
	private bool EnableTestingManager = true;

	[Space]
	[SerializeField]
	public bool isTestingMissions;

	[Space]
	[SerializeField]
	private Mission testingMission;

	[SerializeField]
	private DifficultyTypes testingDifficulty;

	[Space]
	[Space]
	[Space]
	[SerializeField]
	public bool isTestingRest;

	[Space]
	[Header("Game Time")]
	[SerializeField]
	private bool isOverwriteGameStartTime;

	[SerializeField]
	private float OverwriteGameStartTimePercent;

	[SerializeField]
	private bool isOverwriteGameTime;

	[SerializeField]
	private float OverwriteGameTimePercent;

	[Space]
	[Header("Building")]
	[SerializeField]
	private bool isDestroyCoreRightClick;

	[SerializeField]
	private bool isStunCoreRightClick;

	[Space]
	[SerializeField]
	private bool isOverwriteBuildingSize;

	public int buildingLimitX = 3;

	public int buildingLimitY = 3;

	[Space]
	[Space]
	[Header("Player Testing")]
	[Space]
	[SerializeField]
	private bool isPlayerInvincible;

	[Space]
	[SerializeField]
	private bool isPlayerOneShotKill;

	[Space]
	[SerializeField]
	private bool isPlayerUltraSpeed;

	[Space]
	[SerializeField]
	private bool isPlayerUnlimitedFuel;

	[Space]
	[SerializeField]
	private bool isPlayerDisabledHQWeapon;

	[Space]
	[SerializeField]
	private bool isTestingPlayerHQWeapon;

	[SerializeField]
	private TurretCore testingPlayerHQWeapon;

	[Space]
	[SerializeField]
	private bool isTestingPlayerHQDronesList;

	[SerializeField]
	private List<Drone> testingPlayerHQDronesList;

	[Space(5f)]
	[Header("Rewards Testing")]
	[Space]
	[SerializeField]
	private bool isPrintTotalTreePrice;

	[Space]
	[SerializeField]
	private bool isTestingRewardsList;

	[SerializeField]
	private List<Reward> TestingRewards;

	[Space]
	[SerializeField]
	private bool isTestingRewardPacksList;

	[SerializeField]
	private List<RewardPack> TestingRewardPacks;

	[Space]
	[SerializeField]
	private bool UnlockAllRewards;

	[SerializeField]
	private bool LockAllRewards;

	[Space(5f)]
	[Header("AI Testing")]
	[SerializeField]
	private bool stopSpawningBossAI;

	[Space]
	[SerializeField]
	private bool SpawningBossAIOnTopPlayer;

	[Space]
	[SerializeField]
	private bool StopSpawningSwarmAI;

	[Space]
	[SerializeField]
	private bool StopSpawningSwarmAIWaves;

	[Space]
	[SerializeField]
	private bool StopSpawningPatrolAI;

	[Space]
	[SerializeField]
	private bool SpawningSwarmAIFromList;

	[SerializeField]
	private List<PrefabTypes> TestingSwarmAISpawnsList;

	[Space]
	[SerializeField]
	private bool SpawningPatrolAIFromList;

	[SerializeField]
	private List<GameObject> TestingPatrolAISpawnsList;

	[Space(5f)]
	[Header("MapEvents Testing")]
	[Space]
	[SerializeField]
	private bool StopSpawningMapEvents;

	[Space]
	[SerializeField]
	private bool SpawningMapEventsFromList;

	[Space]
	[SerializeField]
	private List<PrefabTypes> TestingMapEventsList;

	[Space]
	[Space]
	[SerializeField]
	private bool isOverridingMapEventPercent;

	[Space]
	[SerializeField]
	[Range(0f, 1f)]
	private float mapEventPercent;

	public void DisableTestingManager()
	{
		EnableTestingManager = false;
	}

	private bool IsTestingRest()
	{
		if (isTestingRest)
		{
			return EnableTestingManager;
		}
		return false;
	}

	public bool IsTestingMissions()
	{
		if (isTestingMissions)
		{
			return EnableTestingManager;
		}
		return false;
	}

	public Mission GetTestingMission()
	{
		return testingMission;
	}

	public DifficultyTypes GetTestingDifficulty()
	{
		return testingDifficulty;
	}

	protected override void Awake()
	{
		base.Awake();
		EnableTestingManager = false;
	}

	public bool IsOverwriteGameStartTime()
	{
		if (isOverwriteGameStartTime)
		{
			return IsTestingRest();
		}
		return false;
	}

	public float GetOverwriteGameStartTimePercent()
	{
		return OverwriteGameStartTimePercent;
	}

	public bool IsOverwriteGameTime()
	{
		if (isOverwriteGameTime)
		{
			return IsTestingRest();
		}
		return false;
	}

	public float GetOverwriteGameTime()
	{
		return OverwriteGameTimePercent;
	}

	public bool IsDestroyCoreRightClick()
	{
		if (isDestroyCoreRightClick)
		{
			return IsTestingRest();
		}
		return false;
	}

	public bool IsStunCoreRightClick()
	{
		if (isStunCoreRightClick)
		{
			return IsTestingRest();
		}
		return false;
	}

	public bool IsOverwriteBuildingSize()
	{
		if (isOverwriteBuildingSize)
		{
			return IsTestingRest();
		}
		return false;
	}

	public bool IsPlayerInvincible()
	{
		if (isPlayerInvincible)
		{
			return IsTestingRest();
		}
		return false;
	}

	public bool IsPlayerOneShotKill()
	{
		if (isPlayerOneShotKill)
		{
			return IsTestingRest();
		}
		return false;
	}

	public bool IsPlayerUltraSpeed()
	{
		if (isPlayerUltraSpeed)
		{
			return IsTestingRest();
		}
		return false;
	}

	public bool IsPlayerUnlimitedFuel()
	{
		if (isPlayerUnlimitedFuel)
		{
			return IsTestingRest();
		}
		return false;
	}

	public bool IsPlayerDisabledHQWeapon()
	{
		if (isPlayerDisabledHQWeapon)
		{
			return IsTestingRest();
		}
		return false;
	}

	public bool IsTestingPlayerHQWeapon()
	{
		if (isTestingPlayerHQWeapon)
		{
			return IsTestingRest();
		}
		return false;
	}

	public TurretCore GetTestingPlayerHQWeapon()
	{
		if (testingPlayerHQWeapon == null)
		{
			Debug.LogError("Please choose a Turret HQ Core in Testing Manager");
		}
		return testingPlayerHQWeapon;
	}

	public bool IsTestingPlayerHQDronesList()
	{
		if (isTestingPlayerHQDronesList)
		{
			return IsTestingRest();
		}
		return false;
	}

	public List<Drone> GetTestingPlayerHQDronesList()
	{
		if (testingPlayerHQDronesList == null)
		{
			Debug.LogError("Please choose at least one HQ Drone in Testing Manager");
		}
		return testingPlayerHQDronesList;
	}

	public bool IsPrintTotalTreePrice()
	{
		if (isPrintTotalTreePrice)
		{
			return IsTestingRest();
		}
		return false;
	}

	public bool IsTestingRewardsList()
	{
		if (isTestingRewardsList)
		{
			return IsTestingRest();
		}
		return false;
	}

	public List<Reward> GetTestingRewardsList()
	{
		if (TestingRewards.Count == 0)
		{
			Debug.LogError("Please choose one or more Testing rewards in Testing Manager");
		}
		return TestingRewards;
	}

	public bool IsTestingRewardPacksList()
	{
		if (isTestingRewardPacksList)
		{
			return IsTestingRest();
		}
		return false;
	}

	public RewardPack GetRandomTestingRewardPack()
	{
		if (TestingRewardPacks.Count == 0)
		{
			Debug.LogError("Please choose one or more Testing rewardPacks in Testing Manager");
		}
		return TestingRewardPacks[Random.Range(0, TestingRewardPacks.Count)];
	}

	public bool IsUnlockAllRewards()
	{
		if (UnlockAllRewards && LockAllRewards)
		{
			Debug.LogError("Please choose to lock or unlock all rewards in Testing Manager");
		}
		if (UnlockAllRewards)
		{
			return IsTestingRest();
		}
		return false;
	}

	public bool IsLockAllRewards()
	{
		if (UnlockAllRewards && LockAllRewards)
		{
			Debug.LogError("Please choose to lock or unlock all rewards in Testing Manager");
		}
		if (LockAllRewards)
		{
			return IsTestingRest();
		}
		return false;
	}

	public bool IsStopSpawningBossAI()
	{
		if (stopSpawningBossAI)
		{
			return IsTestingRest();
		}
		return false;
	}

	public bool IsSpawningBossAIOnTopPlayer()
	{
		if (SpawningBossAIOnTopPlayer)
		{
			return IsTestingRest();
		}
		return false;
	}

	public bool IsStopSpawningSwarmAI()
	{
		if (StopSpawningSwarmAI)
		{
			return IsTestingRest();
		}
		return false;
	}

	public bool IsStopSpawningSwarmWaveAI()
	{
		if (StopSpawningSwarmAIWaves)
		{
			return IsTestingRest();
		}
		return false;
	}

	public bool IsStopSpawningPatrolAI()
	{
		if (StopSpawningPatrolAI)
		{
			return IsTestingRest();
		}
		return false;
	}

	public bool IsSpawningSwarmAIFromList()
	{
		if (SpawningSwarmAIFromList)
		{
			return IsTestingRest();
		}
		return false;
	}

	public PrefabTypes GetTestingSwarmAISpawn()
	{
		if (TestingSwarmAISpawnsList.Count == 0)
		{
			Debug.LogError("Please choose one or more Swarm AI to spawn from in Testing Manager");
		}
		return TestingSwarmAISpawnsList[Random.Range(0, TestingSwarmAISpawnsList.Count)];
	}

	public bool IsSpawningPatrolAIFromList()
	{
		if (SpawningPatrolAIFromList)
		{
			return IsTestingRest();
		}
		return false;
	}

	public GameObject GetTestingPatrolAISpawn()
	{
		if (TestingPatrolAISpawnsList.Count == 0)
		{
			Debug.LogError("Please choose one or more Patrols to spawn from in Testing Manager");
		}
		return TestingPatrolAISpawnsList[Random.Range(0, TestingPatrolAISpawnsList.Count)];
	}

	public bool IsSpawningMapEvents()
	{
		if (StopSpawningMapEvents)
		{
			return IsTestingRest();
		}
		return false;
	}

	public bool IsSpawningMapEventsFromList()
	{
		if (SpawningMapEventsFromList)
		{
			return IsTestingRest();
		}
		return false;
	}

	public PrefabTypes GetTestingMapEventSpawn()
	{
		if (TestingMapEventsList.Count == 0)
		{
			Debug.LogError("Please choose one or more Map Events to spawn from in Testing Manager");
		}
		return TestingMapEventsList[Random.Range(0, TestingMapEventsList.Count)];
	}

	public bool IsOverridingMapEventPercent()
	{
		if (isOverridingMapEventPercent)
		{
			return IsTestingRest();
		}
		return false;
	}

	public float GetMapEventPercent()
	{
		return mapEventPercent;
	}
}
