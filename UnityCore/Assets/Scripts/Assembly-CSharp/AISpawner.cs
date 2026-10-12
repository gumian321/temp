using System.Collections.Generic;
using UnityEngine;

public class AISpawner : MonoBehaviour
{
	[SerializeField]
	private float disToSpawn;

	[SerializeField]
	private bool isSpawning;

	[SerializeField]
	private bool isHeatSpawning;

	private List<SpawnType> HeatSpawnList;

	[HideInInspector]
	public SpawnType currentSpawnType;

	[Space]
	[Header("Fixed Spawning")]
	[SerializeField]
	private List<PrefabTypes> prefabsTypeList;

	[Space]
	[SerializeField]
	private int maxSpawnes;

	[SerializeField]
	private int activeSpawnes;

	[SerializeField]
	public float timeBetweenSpawnes;

	private float timer;

	private Transform targetTransform;

	private AIDataStore aIDataStore;

	private AIFaction swarmAIFaction;

	public void SetUpAIFaction(AIFaction swarmAIFaction)
	{
		this.swarmAIFaction = swarmAIFaction;
	}

	private void Awake()
	{
		aIDataStore = Singleton<AIDataStore>.Instance;
		HeatSpawnList = aIDataStore.GetHeatSpawnersList();
		GetComponent<SpriteRenderer>().sprite = aIDataStore.GetRandomSpawnerSprite();
		targetTransform = SceneSingleton<GameMissionManager>.Instance.GetMissionTarget();
		SetTarget(SceneSingleton<GameMissionManager>.Instance.GetMissionTarget());
		timer = Time.time + timeBetweenSpawnes;
		swarmAIFaction = Singleton<AIDataStore>.Instance.GetSwarmAIFaction();
		SelectSpawnType(SceneSingleton<GameHeatManager>.Instance.GetTimerHeatPercent());
	}

	private void OnEnable()
	{
		timer = Time.time + timeBetweenSpawnes;
		SceneSingleton<GameHeatManager>.Instance.OnHeatTimerChange += SelectSpawnType;
	}

	private void OnDisable()
	{
		if (SceneSingleton<GameHeatManager>.Instance != null)
		{
			SceneSingleton<GameHeatManager>.Instance.OnHeatTimerChange -= SelectSpawnType;
		}
	}

	public void SetTarget(Transform targetTransform)
	{
		this.targetTransform = targetTransform;
	}

	public void ResetTimer(float timeBetweenSpawnes)
	{
		this.timeBetweenSpawnes = timeBetweenSpawnes;
		timer = Time.time + timeBetweenSpawnes;
	}

	public void SelectSpawnType(float heat)
	{
		for (int num = HeatSpawnList.Count - 1; num >= 0; num--)
		{
			if (heat >= HeatSpawnList[num].selectHeatPercent)
			{
				currentSpawnType = HeatSpawnList[num];
				SetUpSpawner(HeatSpawnList[num]);
				break;
			}
		}
	}

	private void SetUpSpawner(SpawnType spawnType)
	{
		prefabsTypeList = new List<PrefabTypes>(spawnType.SpawnObjectsList);
		maxSpawnes = spawnType.maxSpawnCount;
		timeBetweenSpawnes = spawnType.timeBetweenSpawns;
		isSpawning = true;
	}

	private void FixedUpdate()
	{
		if (isSpawning && !(targetTransform == null))
		{
			float num = Vector3.Distance(base.transform.position, targetTransform.position);
			if (!(disToSpawn < num) && activeSpawnes != maxSpawnes && timer < Time.time)
			{
				timer = Time.time + timeBetweenSpawnes;
				SpawnUnit();
			}
		}
	}

	private void SpawnUnit()
	{
		activeSpawnes++;
		GameObject gameObject = MasterPool.Get(prefabsTypeList[Random.Range(0, prefabsTypeList.Count)]);
		gameObject.transform.position = base.transform.position;
		AISwarmingUnit component = gameObject.GetComponent<AISwarmingUnit>();
		component.SetAIFaction(swarmAIFaction);
		component.BuildUnit();
		if (targetTransform != null)
		{
			ObjectSystem.RotateAt(gameObject.transform, targetTransform);
		}
		component.SetOnDestroyAction(SpawnDestroyed);
	}

	private void SpawnDestroyed()
	{
		activeSpawnes--;
	}
}
