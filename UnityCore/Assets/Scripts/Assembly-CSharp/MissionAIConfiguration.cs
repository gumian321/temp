using System.Collections.Generic;
using UnityEngine;

[CreateAssetMenu(fileName = "New MissionAIConfiguration", menuName = "ScriptableObjects/Missions/New MissionAIConfiguration")]
public class MissionAIConfiguration : ScriptableObject
{
	[Space]
	[Header("Allow AI Spawners")]
	public bool IsAISwarmSpawnerActive = true;

	public bool IsAIPatrolSpawnerActive = true;

	public bool IsAIWaveSpawnerActive = true;

	[Space]
	[Header("AI Spawners targeting")]
	public bool IsAISwarmSpawnerPlayerTargeting = true;

	public bool IsAIPatrolSpawnerPlayerTargeting = true;

	public bool IsAIWaveSpawnerPlayerTargeting = true;

	public bool IsAIBossSpawnerPlayerTargeting = true;

	[Space]
	[Header("AI Spawners Percent when Boss Spawns")]
	[Range(0f, 1f)]
	public float AISwarmSpawnerBossPercent = 1f;

	[Range(0f, 1f)]
	public float AIPatrolSpawnerBossPercent = 1f;

	[Range(0f, 1f)]
	public float AIWaveSpawnerBossPercent = 1f;

	[Space]
	[Header("AI Factions")]
	public AIFaction AIWaveFaction = AIFaction.Red;

	public AIFaction AISwarmFaction = AIFaction.Red;

	public AIFaction AIBossWaveFaction = AIFaction.Red;

	[Space]
	[Header("Radius")]
	public float bossSpawningRadius = 50f;

	public float despawningRadius = 75f;

	[Space]
	[Space]
	[Header("Patrols")]
	public float PatrolSpawningRadius = 50f;

	[Space]
	public int MinPatrolUnits = 2;

	public int MaxPatrolUnits = 5;

	public List<PatrolAIHeat> aIPatrolsList;

	[Space]
	[Space]
	[Header("Spawners")]
	public List<SpawnType> HeatSpawnersList;

	[Space]
	[Space]
	[Header("Swarm")]
	public float swarmSpawningRadius = 25f;

	public float SwarmingSpawningDelay = 2f;

	[Space]
	public int MinSwarmingUnits = 2;

	public int MaxSwarmingUnits = 7;

	public List<SwarmingAIHeat> aISwarmingList;

	[Space]
	[Space]
	[Header("Swarm Waves")]
	public float waveSpawningRadius = 35f;

	[Space]
	public float MinWaveTimer = 20f;

	public float MaxWaveTimer = 30f;

	[Space]
	public int MinWaveCount = 5;

	public int MaxWaveCount = 15;

	public List<SwarmingAIHeat> aIWaveSwarmList;

	[Space]
	[Header("Events")]
	public int distanceBetweenNodes;

	public List<PrefabTypes> mapEventsList;

	public int xOffset;

	public int yOffset;

	public bool emptyFirstLayerMapNodes;
}
