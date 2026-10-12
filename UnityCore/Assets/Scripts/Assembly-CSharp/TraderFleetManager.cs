using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TraderFleetManager : MonoBehaviour
{
	[SerializeField]
	private BHModeManager bHModeManager;

	[SerializeField]
	private GAModeManager gAModeManager;

	[Space]
	[SerializeField]
	private LayerMask fleetLayerMask;

	[SerializeField]
	private List<Sprite> tradersSpritesList;

	[Space]
	[SerializeField]
	private List<SpriteRenderer> mapIconSpriteRenderersList;

	[Header("Movement")]
	[SerializeField]
	private Transform fleetTarget;

	[SerializeField]
	private Transform playerTransform;

	[SerializeField]
	private float movingSpeed;

	private float movingModifier;

	[Space]
	[Header("Fleet")]
	[SerializeField]
	private Transform fleetMovementHolder;

	[SerializeField]
	private int currentUnits;

	[SerializeField]
	private List<TraderUnit> units;

	[Space]
	[Header("Warping")]
	[SerializeField]
	private bool allowWarping;

	[SerializeField]
	private bool isWarping;

	[SerializeField]
	private List<Rigidbody2D> unitsRB;

	[SerializeField]
	private List<Collider2D> unitsColl;

	[Space]
	[Header("Gardian Angle Mode")]
	[SerializeField]
	private Transform gardianAngleTarget;

	[SerializeField]
	private float disFromTargetToWin;

	[SerializeField]
	private float disFromPlayerToMove;

	private bool won;

	public float fleetPercent = 1f;

	public void Setup(bool runAway, Transform target = null)
	{
		playerTransform = SceneSingleton<PlayerManager>.Instance.GetPlayerTransform();
		if (target != null)
		{
			fleetTarget = target;
		}
		else
		{
			fleetTarget = gardianAngleTarget;
		}
		if (runAway)
		{
			movingModifier = -1f;
		}
		else
		{
			movingModifier = 1f;
		}
		ListTraders();
		foreach (SpriteRenderer mapIconSpriteRenderers in mapIconSpriteRenderersList)
		{
			SceneSingleton<GameMissionManager>.Instance.SetMapIcon(mapIconSpriteRenderers);
		}
		fleetPercent = 1f;
	}

	private void ListTraders()
	{
		mapIconSpriteRenderersList = new List<SpriteRenderer>();
		units.Clear();
		units.AddRange(GetComponentsInChildren<TraderUnit>());
		currentUnits = units.Count;
		foreach (TraderUnit unit in units)
		{
			unit.gameObject.layer = Singleton<DetectionDataStore>.Instance.GetLayerNumber(fleetLayerMask);
			unit.BuildUnit();
			GameObject gameObject = new GameObject();
			gameObject.transform.SetParent(fleetMovementHolder);
			gameObject.transform.position = unit.transform.position;
			unit.GetComponent<TraderUnitMovement>().SetMoveTarget(gameObject.transform);
			unit.SetOnUnitDestroy(UnitDestroyed);
			unitsRB.Add(unit.GetComponent<Rigidbody2D>());
			unitsColl.Add(unit.GetComponent<Collider2D>());
			unit.GetComponent<SpriteRenderer>().sprite = tradersSpritesList[(int)unit.GetAIThreatLevel()];
			mapIconSpriteRenderersList.Add(unit.GetMapIcon());
			if (gAModeManager != null)
			{
				unit.ActivateHealthBar();
			}
			if (bHModeManager != null)
			{
				unit.GetComponent<TraderUnit>().isSpawnRewardPack = true;
			}
		}
	}

	private void FixedUpdate()
	{
		if (fleetTarget == null)
		{
			return;
		}
		if (bHModeManager != null)
		{
			Vector3 normalized = (fleetTarget.position - fleetMovementHolder.position).normalized;
			fleetMovementHolder.Translate(normalized * (movingSpeed * movingModifier) * Time.fixedDeltaTime);
		}
		if (gAModeManager != null)
		{
			if (Vector3.Distance(fleetMovementHolder.position, playerTransform.position) < disFromPlayerToMove)
			{
				Vector3 normalized2 = (fleetTarget.position - fleetMovementHolder.position).normalized;
				fleetMovementHolder.Translate(normalized2 * (movingSpeed * movingModifier) * Time.fixedDeltaTime);
			}
			if (Vector3.Distance(fleetMovementHolder.position, gardianAngleTarget.position) < disFromTargetToWin && !won)
			{
				won = true;
				SceneSingleton<GameManager>.Instance.EndGame(isPlayerWon: true);
			}
		}
	}

	public GameObject GetRandomUnit()
	{
		List<GameObject> list = new List<GameObject>();
		foreach (TraderUnit unit in units)
		{
			if (unit.gameObject.activeSelf)
			{
				list.Add(unit.gameObject);
			}
		}
		if (list.Count != 0)
		{
			return list[Random.Range(0, list.Count)];
		}
		return null;
	}

	private void UnitDestroyed()
	{
		currentUnits--;
		fleetPercent = (float)currentUnits / (float)units.Count;
		if (bHModeManager != null)
		{
			bHModeManager.SpawnBossesFleet(fleetPercent);
			if (fleetPercent == 0f)
			{
				SceneSingleton<GameManager>.Instance.EndGame(isPlayerWon: true);
			}
		}
		if (gAModeManager != null && fleetPercent == 0f)
		{
			SceneSingleton<GameManager>.Instance.EndGame(isPlayerWon: false);
		}
	}

	public int GetTraderSurvivedCount()
	{
		return currentUnits;
	}

	public void WarpFleet(float fleetWarpDistance)
	{
		if (allowWarping && !isWarping)
		{
			StartCoroutine(IWarpFleet(fleetWarpDistance));
		}
	}

	private IEnumerator IWarpFleet(float fleetWarpDistance)
	{
		ActiveUnits(x: false);
		isWarping = true;
		foreach (TraderUnit unit in units)
		{
			if (unit.gameObject.activeSelf)
			{
				unit.GetComponent<AIUnitMovement>().IsWarping(isWarping: true);
				MasterPool.GetPos(PrefabTypes.Particle_Warp, unit.transform.position);
				TweenController.Scale(unit.transform, 1f, 0f, TweenDuration.Short, ignoreTimeScale: false, () =>
				{
					Singleton<AudioManager>.Instance.PlaySFX(AudioClipTypes.AI_Warp);
				});
			}
		}
		yield return new WaitForSeconds(2f);
		ObjectSystem.SetOnRandomEdgePos(fleetMovementHolder, playerTransform, fleetWarpDistance);
		yield return new WaitForEndOfFrame();
		foreach (TraderUnit unit2 in units)
		{
			if (unit2.gameObject.activeSelf)
			{
				unit2.GetComponent<AIUnitMovement>().IsWarping(isWarping: false);
				unit2.GetComponent<TraderUnitMovement>().SnapToTarget();
				TweenController.Scale(unit2.transform, 0f, 1f, TweenDuration.Short);
			}
		}
		ActiveUnits(x: true);
		isWarping = false;
	}

	private void ActiveUnits(bool x)
	{
		foreach (Rigidbody2D item in unitsRB)
		{
			item.simulated = x;
		}
		foreach (Collider2D item2 in unitsColl)
		{
			item2.enabled = x;
		}
	}
}
