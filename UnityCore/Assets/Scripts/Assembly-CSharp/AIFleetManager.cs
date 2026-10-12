using System;
using System.Collections.Generic;
using UnityEngine;

public class AIFleetManager : MonoBehaviour
{
	private Action onWaveDestroyed;

	[SerializeField]
	private GameObject fleetPossHolder;

	[SerializeField]
	private GameObject fleetCenter;

	private GameObject waveCenter;

	private List<AISwarmingUnit> units;

	private int survivingUnitNum;

	private Transform targetTransform;

	private float speed = 5f;

	private float rotOffset = 90f;

	[Space]
	[Header("Testing")]
	[SerializeField]
	private List<PrefabTypes> prefabUnits;

	[SerializeField]
	private bool addSprite;

	[SerializeField]
	private Sprite testSprite;

	private AIFaction fleetAIFaction;

	public void SetUpInMiddle(List<PrefabTypes> unitsPrefabsType, Transform targetTransform, Transform secondTargetTransform, Action onWaveDestroyed = null, bool changeSpeedWithHeat = false, AIFaction fleetAIFaction = AIFaction.Red)
	{
		this.targetTransform = targetTransform;
		this.fleetAIFaction = fleetAIFaction;
		if (onWaveDestroyed != null)
		{
			this.onWaveDestroyed = onWaveDestroyed.Invoke;
		}
		ObjectSystem.SetBetweenTwoPoints(base.transform, targetTransform.position, secondTargetTransform.position, 0.5f);
		SetUp(unitsPrefabsType, changeSpeedWithHeat);
	}

	public void SetUpRadius(List<PrefabTypes> unitsPrefabsType, Transform targetTransform, float spawningRadius, Action onWaveDestroyed = null, bool changeSpeedWithHeat = false, AIFaction fleetAIFaction = AIFaction.Red)
	{
		this.targetTransform = targetTransform;
		this.fleetAIFaction = fleetAIFaction;
		if (onWaveDestroyed != null)
		{
			this.onWaveDestroyed = onWaveDestroyed.Invoke;
		}
		ObjectSystem.SetOnRandomEdgePos(base.transform, targetTransform, spawningRadius);
		SetUp(unitsPrefabsType, changeSpeedWithHeat);
	}

	public void SetUp(List<PrefabTypes> unitsPrefabsType, bool changeSpeedWithHeat = false)
	{
		units = new List<AISwarmingUnit>();
		foreach (PrefabTypes item in unitsPrefabsType)
		{
			GameObject gameObject = MasterPool.Get(item);
			units.Add(gameObject.GetComponent<AISwarmingUnit>());
		}
		survivingUnitNum = units.Count;
		fleetCenter.transform.parent = units[0].transform;
		fleetCenter.transform.localPosition = Vector2.zero;
		FormFleetFormation();
		BuildFleetUnits(changeSpeedWithHeat);
	}

	public void AddAction(Action action)
	{
		if (onWaveDestroyed != null)
		{
			onWaveDestroyed = (Action)Delegate.Combine(onWaveDestroyed, action);
		}
		else
		{
			onWaveDestroyed = action.Invoke;
		}
	}

	private void FormFleetFormation()
	{
		Dictionary<float, List<AISwarmingUnit>> dictionary = new Dictionary<float, List<AISwarmingUnit>>();
		List<float> list = new List<float>();
		foreach (AISwarmingUnit unit in units)
		{
			if (dictionary.ContainsKey(unit.formationSize))
			{
				dictionary[unit.formationSize].Add(unit);
				continue;
			}
			dictionary.Add(unit.formationSize, new List<AISwarmingUnit>());
			dictionary[unit.formationSize].Add(unit);
			list.Add(unit.formationSize);
		}
		list.Sort();
		list.Reverse();
		float num = list[0] + 1f;
		float num2 = 0f;
		foreach (float item in list)
		{
			num2 = UnityEngine.Random.Range(45f, 90f);
			for (int i = 0; i < dictionary[item].Count; i++)
			{
				float num3 = (float)i * (float)Math.PI * 2f / (float)dictionary[item].Count;
				num3 += num2;
				Vector2 vector = new Vector2(Mathf.Cos(num3) * num, Mathf.Sin(num3) * num);
				vector += (Vector2)ObjectSystem.GetRandomPosInCircle(Vector2.zero, 0.25f);
				GameObject gameObject = new GameObject();
				gameObject.transform.SetParent(fleetPossHolder.transform);
				gameObject.transform.localPosition = vector;
				if (addSprite)
				{
					gameObject.AddComponent<SpriteRenderer>();
					gameObject.GetComponent<SpriteRenderer>().sprite = testSprite;
				}
				dictionary[item][i].SetBossFleetTransform(gameObject.transform);
			}
			num += item;
		}
	}

	private void BuildFleetUnits(bool changeSpeedWithHeat = false)
	{
		foreach (AISwarmingUnit unit in units)
		{
			AIBossUnit component = unit.GetComponent<AIBossUnit>();
			if (component != null)
			{
				component.BuildUnit();
				component.SetBoss(WaveShipDestroyed);
				unit.GetComponent<AIBossBoostSystem>()?.SetTargetTransfrom(base.transform.parent);
				if (changeSpeedWithHeat)
				{
					component.GetComponent<AIBossUnitMovement>().AllowChangeSpeedWithHeat();
				}
			}
			else
			{
				unit.SetAIFaction(fleetAIFaction);
				unit.BuildUnit();
				unit.SetOnDestroyAction(WaveShipDestroyed);
			}
		}
		if (!SceneSingleton<GameMissionManager>.Instance.IsMissionEndless())
		{
			return;
		}
		float missionEndlessSpeedHeat = SceneSingleton<GameMissionManager>.Instance.GetMissionEndlessSpeedHeat();
		if (missionEndlessSpeedHeat <= 0f)
		{
			return;
		}
		foreach (AISwarmingUnit unit2 in units)
		{
			AIUnitMovement component2 = unit2.GetComponent<AIUnitMovement>();
			if (component2 != null)
			{
				component2.AddEnginePowerPercent(missionEndlessSpeedHeat);
			}
		}
	}

	private void WaveShipDestroyed()
	{
		survivingUnitNum--;
		if (survivingUnitNum == 0)
		{
			if (onWaveDestroyed != null)
			{
				onWaveDestroyed();
			}
			if (fleetCenter != null)
			{
				UnityEngine.Object.Destroy(fleetCenter.gameObject);
			}
			UnityEngine.Object.Destroy(base.gameObject);
		}
	}

	private void FixedUpdate()
	{
		fleetPossHolder.transform.position = targetTransform.position;
	}

	public Transform GetFleetCenter()
	{
		return fleetCenter.transform;
	}
}
