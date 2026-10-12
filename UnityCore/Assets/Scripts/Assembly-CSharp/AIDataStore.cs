using System.Collections.Generic;
using UnityEngine;

public class AIDataStore : Singleton<AIDataStore>
{
	[SerializeField]
	public float MaxHeat = 100f;

	private MissionAIConfiguration MAIConfig;

	[Header("Factions Colors and Sprites")]
	[SerializeField]
	public Sprite bossSprite;

	[Space]
	[SerializeField]
	private Color BlueColor;

	[SerializeField]
	private Color RedColor;

	[SerializeField]
	private Color GreenColor;

	[SerializeField]
	private Color aIDisabledColor;

	[Space]
	[SerializeField]
	private List<Sprite> threatsLevelSprites;

	[Space]
	[Header("Spawners")]
	[SerializeField]
	private List<Sprite> spawnersSpritesList;

	[SerializeField]
	private List<Sprite> stationSpawnersSpritesList;

	[Space]
	[Header("Guards")]
	[SerializeField]
	private List<Sprite> FederationGuardsLevelSprites;

	[SerializeField]
	private List<Sprite> ASVWGuardsLevelSprites;

	[SerializeField]
	private List<Sprite> GuardsThreatsLevelSprites;

	[Space]
	[Header("Stations")]
	[SerializeField]
	private Sprite FederationStationCoreSprite;

	[SerializeField]
	private Sprite ASVWStationCoreSprite;

	[SerializeField]
	private List<Sprite> FederationStationsLevelSprites;

	[SerializeField]
	private List<Sprite> ASVWStationsLevelSprites;

	[SerializeField]
	private List<Sprite> StationsThreatsLevelSprites;

	[Space]
	[Header("AI Scraps")]
	[SerializeField]
	private List<Sprite> FederationScrapsSprites;

	[SerializeField]
	private List<Sprite> ASVWScrapsSprites;

	[Space]
	[Header("Timers")]
	[SerializeField]
	private float spawningPauseAfterBoss;

	private int secondsToUpdate = 10;

	private int currentSeconds;

	private List<SpawnType> HeatSpawnList;

	[Space]
	[Header("Patrols")]
	private List<GameObject> currentPatrolsPool;

	[Space]
	[Header("Patrol Numbers")]
	[HideInInspector]
	public int PatrolUnitsNumber;

	[HideInInspector]
	public int AddedPatrolNumber;

	[Space]
	[Header("Cores")]
	[SerializeField]
	private List<CoreAIHeat> aICoreList;

	private List<Core> currentCorePool;

	[Space]
	[Header("Swarming")]
	private List<PrefabTypes> currentSwarmingPool;

	[Space]
	[Header("Swarming Numbers")]
	[HideInInspector]
	public int SwarmingUnitsNumber;

	[HideInInspector]
	public int AddedSwarmUnitNumber;

	[Space]
	[Header("WaveSwarm")]
	private List<PrefabTypes> currentWaveSwarmPool;

	[HideInInspector]
	public int AddedWaveUnitNumber;

	[Space]
	[Header("Guards")]
	[SerializeField]
	private List<AIGuardUnit> aIGuardUnitList;

	private List<AIGuardUnit> probAIGuardUnitList;

	[Space]
	[Header("Stations")]
	[SerializeField]
	private List<AIStationPart> aIStationPartsList;

	private List<AIStationPart> probAIStationPartList;

	[Space]
	[Header("Bosses Parts")]
	[SerializeField]
	private List<AIBossPart> aIBossPartsList;

	private Dictionary<AIThreatLevel, List<AIBossPart>> aIBossPartsDict;

	public static float GetAIShakeAmount()
	{
		return 0.02f;
	}

	public void SetUpMissionAIConfiguration(MissionAIConfiguration MAIConfig)
	{
		this.MAIConfig = MAIConfig;
		HeatSpawnList = MAIConfig.HeatSpawnersList;
		SceneSingleton<AIWaveSpawner>.Instance.SetUpAIFaction(MAIConfig.AIWaveFaction);
		SceneSingleton<AIWaveSpawner>.Instance.SetUp(MAIConfig.IsAIWaveSpawnerActive, MAIConfig.IsAIWaveSpawnerPlayerTargeting);
		SceneSingleton<AISwarmingSpawner>.Instance.SetUpAIFaction(MAIConfig.AISwarmFaction);
		SceneSingleton<AISwarmingSpawner>.Instance.SetUp(MAIConfig.IsAISwarmSpawnerActive, MAIConfig.IsAISwarmSpawnerPlayerTargeting);
		SceneSingleton<AIPatrolSpawner>.Instance.SetUp(MAIConfig.IsAIPatrolSpawnerActive, MAIConfig.IsAIPatrolSpawnerPlayerTargeting);
		SceneSingleton<AIBossSpawner>.Instance.SetUpAIFaction(MAIConfig.AISwarmFaction);
		SceneSingleton<AIBossSpawner>.Instance.SetUp(MAIConfig.IsAIBossSpawnerPlayerTargeting);
		ResetAIPools();
	}

	public AIFaction GetSwarmAIFaction()
	{
		return MAIConfig.AISwarmFaction;
	}

	public Color GetFactionColor(AIFaction aIFaction)
	{
		return aIFaction switch
		{
			AIFaction.Blue => BlueColor, 
			AIFaction.Red => RedColor, 
			AIFaction.None => GreenColor, 
			_ => Color.white, 
		};
	}

	public Color GetDisabledColor()
	{
		return aIDisabledColor;
	}

	public Sprite GetThreatLevelSprite(AIThreatLevel aIThreatLevel)
	{
		return threatsLevelSprites[(int)aIThreatLevel];
	}

	public Sprite GetRandomSpawnerSprite()
	{
		return spawnersSpritesList[Random.Range(0, spawnersSpritesList.Count)];
	}

	public Sprite GetRandomStationSpawnerSprite()
	{
		return stationSpawnersSpritesList[Random.Range(0, stationSpawnersSpritesList.Count)];
	}

	public Sprite GetGuardLevelSprite(AIFaction aIFaction, AIThreatLevel aIThreatLevel)
	{
		if (aIFaction == AIFaction.Blue)
		{
			return FederationGuardsLevelSprites[(int)aIThreatLevel];
		}
		return ASVWGuardsLevelSprites[(int)aIThreatLevel];
	}

	public Sprite GetGuardThreatLevelSprite(AIThreatLevel aIThreatLevel)
	{
		return GuardsThreatsLevelSprites[(int)aIThreatLevel];
	}

	public Sprite GetStationCoreSprite(AIFaction aIFaction)
	{
		if (aIFaction == AIFaction.Blue)
		{
			return FederationStationCoreSprite;
		}
		return ASVWStationCoreSprite;
	}

	public Sprite GetStationLevelSprite(AIFaction aIFaction, AIThreatLevel aIThreatLevel)
	{
		if (aIFaction == AIFaction.Blue)
		{
			return FederationStationsLevelSprites[(int)aIThreatLevel];
		}
		return ASVWStationsLevelSprites[(int)aIThreatLevel];
	}

	public Sprite GetStationThreatLevelSprite(AIThreatLevel aIThreatLevel)
	{
		return StationsThreatsLevelSprites[(int)aIThreatLevel];
	}

	public List<Sprite> GetScrapSpriteList(AIFaction aIFaction)
	{
		if (aIFaction == AIFaction.Blue)
		{
			return FederationScrapsSprites;
		}
		return ASVWScrapsSprites;
	}

	public float GetSpawningPauseAfterBoss()
	{
		return spawningPauseAfterBoss;
	}

	public float GetSwarmingSpawningDelay()
	{
		return MAIConfig.SwarmingSpawningDelay;
	}

	public float GetSwarmingBossPercent()
	{
		return MAIConfig.AISwarmSpawnerBossPercent;
	}

	public float GetPatrolBossPercent()
	{
		return MAIConfig.AIPatrolSpawnerBossPercent;
	}

	public float GetWaveBossPercent()
	{
		return MAIConfig.AIWaveSpawnerBossPercent;
	}

	public float GetPatrolSpawningRadius()
	{
		return MAIConfig.PatrolSpawningRadius;
	}

	public float GetSwarmSpawningRadius()
	{
		return MAIConfig.swarmSpawningRadius;
	}

	public float GetWaveSpawningRadius()
	{
		return MAIConfig.waveSpawningRadius;
	}

	public float GetBossSpawningRadius()
	{
		return MAIConfig.bossSpawningRadius;
	}

	public float GetDeSpawningRadius()
	{
		return MAIConfig.despawningRadius;
	}

	public void ResetAIPools()
	{
		currentPatrolsPool = new List<GameObject>();
		currentSwarmingPool = new List<PrefabTypes>();
		currentWaveSwarmPool = new List<PrefabTypes>();
		currentCorePool = new List<Core>();
		AddedWaveUnitNumber = 0;
		AddedPatrolNumber = 0;
		AddedSwarmUnitNumber = 0;
		currentSeconds = secondsToUpdate / 2;
		RefillCores(0f);
		RefillSwarmings(0f);
		UpdateSwarmingNumbers(0f);
		RefillWaveSwarms(0f);
		RefillPatrols(0f);
		UpdatePatrolNumbers(0f);
	}

	public void UpdateAIPools(float newHeat)
	{
		currentSeconds++;
		if (currentSeconds > secondsToUpdate)
		{
			currentSeconds = 0;
			RefillCores(newHeat);
			RefillSwarmings(newHeat);
			UpdateSwarmingNumbers(newHeat);
			RefillWaveSwarms(newHeat);
			RefillPatrols(newHeat);
			UpdatePatrolNumbers(newHeat);
		}
	}

	public List<SpawnType> GetHeatSpawnersList()
	{
		return HeatSpawnList;
	}

	public GameObject GetAIPatrol()
	{
		return currentPatrolsPool[Random.Range(0, currentPatrolsPool.Count)];
	}

	private void RefillPatrols(float newHeat)
	{
		currentPatrolsPool.Clear();
		float num = newHeat;
		if (num > 1f)
		{
			num = 1f;
		}
		foreach (PatrolAIHeat aIPatrols in MAIConfig.aIPatrolsList)
		{
			if (aIPatrols.IsHeatSuitable(num))
			{
				for (int i = 0; i < aIPatrols.probablity; i++)
				{
					currentPatrolsPool.Add(aIPatrols.AIPrefab);
				}
			}
		}
	}

	private void UpdatePatrolNumbers(float newHeat)
	{
		PatrolUnitsNumber = Mathf.RoundToInt(newHeat * (float)MAIConfig.MaxPatrolUnits);
		PatrolUnitsNumber = Mathf.Clamp(PatrolUnitsNumber, MAIConfig.MinPatrolUnits, MAIConfig.MaxPatrolUnits);
		PatrolUnitsNumber += AddedPatrolNumber;
		SceneSingleton<AIPatrolSpawner>.Instance.CalculateSpawningUnits();
	}

	public Core GetAICore()
	{
		return currentCorePool[Random.Range(0, currentCorePool.Count)];
	}

	private void RefillCores(float newHeat)
	{
		currentCorePool.Clear();
		float num = newHeat;
		if (num > 1f)
		{
			num = 1f;
		}
		foreach (CoreAIHeat aICore in aICoreList)
		{
			if (aICore.IsHeatSuitable(num))
			{
				for (int i = 0; i < aICore.probablity; i++)
				{
					currentCorePool.Add(aICore.aICore);
				}
			}
		}
	}

	public PrefabTypes GetAISwarming()
	{
		return currentSwarmingPool[Random.Range(0, currentSwarmingPool.Count)];
	}

	private void RefillSwarmings(float newHeat)
	{
		currentSwarmingPool.Clear();
		float num = newHeat;
		if (num > 1f)
		{
			num = 1f;
		}
		foreach (SwarmingAIHeat aISwarming in MAIConfig.aISwarmingList)
		{
			if (aISwarming.IsHeatSuitable(num))
			{
				for (int i = 0; i < aISwarming.probablity; i++)
				{
					currentSwarmingPool.Add(aISwarming.AIPrefab);
				}
			}
		}
	}

	private void UpdateSwarmingNumbers(float newHeat)
	{
		SwarmingUnitsNumber = Mathf.RoundToInt(newHeat * (float)MAIConfig.MaxSwarmingUnits);
		SwarmingUnitsNumber = Mathf.Clamp(SwarmingUnitsNumber, MAIConfig.MinSwarmingUnits, MAIConfig.MaxSwarmingUnits);
		SwarmingUnitsNumber += AddedSwarmUnitNumber;
		SceneSingleton<AISwarmingSpawner>.Instance.CalculateSpawningUnits();
	}

	public float GetNextWaveTimer()
	{
		return Mathf.Clamp(Mathf.RoundToInt(SceneSingleton<GameHeatManager>.Instance.GetTimerHeatPercent() * MAIConfig.MaxWaveTimer), MAIConfig.MinWaveTimer, MAIConfig.MaxWaveTimer);
	}

	public PrefabTypes GetAIWaveSwarm()
	{
		return currentWaveSwarmPool[Random.Range(0, currentWaveSwarmPool.Count)];
	}

	private void RefillWaveSwarms(float newHeat)
	{
		currentWaveSwarmPool.Clear();
		float num = newHeat;
		if (num > 1f)
		{
			num = 1f;
		}
		foreach (SwarmingAIHeat aIWaveSwarm in MAIConfig.aIWaveSwarmList)
		{
			if (aIWaveSwarm.IsHeatSuitable(num))
			{
				for (int i = 0; i < aIWaveSwarm.probablity; i++)
				{
					currentWaveSwarmPool.Add(aIWaveSwarm.AIPrefab);
				}
			}
		}
	}

	public int GetWaveCount()
	{
		return Mathf.Clamp(Mathf.RoundToInt(SceneSingleton<GameHeatManager>.Instance.GetTimerHeatPercent() * (float)MAIConfig.MaxWaveCount), MAIConfig.MinWaveCount, MAIConfig.MaxWaveCount) + AddedWaveUnitNumber;
	}

	private void BuildGuardsList()
	{
		probAIGuardUnitList = new List<AIGuardUnit>();
		foreach (AIGuardUnit aIGuardUnit in aIGuardUnitList)
		{
			for (int i = 0; i < aIGuardUnit.unitProbabilty; i++)
			{
				probAIGuardUnitList.Add(aIGuardUnit);
			}
		}
	}

	public AIGuardUnit GetAIGuardUnit()
	{
		if (probAIGuardUnitList == null)
		{
			BuildGuardsList();
		}
		return probAIGuardUnitList[Random.Range(0, probAIGuardUnitList.Count)];
	}

	private void BuildAIStationPartList()
	{
		probAIStationPartList = new List<AIStationPart>();
		foreach (AIStationPart aIStationParts in aIStationPartsList)
		{
			for (int i = 0; i < aIStationParts.partProbabilty; i++)
			{
				probAIStationPartList.Add(aIStationParts);
			}
		}
	}

	public AIStationPart GetAIStationPart()
	{
		if (probAIStationPartList == null)
		{
			BuildAIStationPartList();
		}
		return probAIStationPartList[Random.Range(0, probAIStationPartList.Count)];
	}

	public AIBossPart GetAIBossPart(AIThreatLevel aIThreatLevel, AIBossPartTypes aIBossPartType)
	{
		if (aIBossPartsDict == null)
		{
			BuildAIBossPartsDict();
		}
		List<AIBossPart> list = new List<AIBossPart>();
		foreach (AIBossPart item in aIBossPartsDict[aIThreatLevel])
		{
			if (item.aIBossPartType == aIBossPartType)
			{
				list.Add(item);
			}
		}
		return list[Random.Range(0, list.Count)];
	}

	public void BuildAIBossPartsDict()
	{
		aIBossPartsDict = new Dictionary<AIThreatLevel, List<AIBossPart>>();
		foreach (AIBossPart aIBossParts in aIBossPartsList)
		{
			if (!aIBossPartsDict.ContainsKey(aIBossParts.bossThreatLevel))
			{
				aIBossPartsDict.Add(aIBossParts.bossThreatLevel, new List<AIBossPart>());
			}
			aIBossPartsDict[aIBossParts.bossThreatLevel].Add(aIBossParts);
		}
	}
}
