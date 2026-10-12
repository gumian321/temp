using System.Collections.Generic;
using UnityEngine;

public class AIPatrolManager : MonoBehaviour
{
	private List<AIPatrolUnit> units = new List<AIPatrolUnit>();

	private AIPatrolMovement aIPatrolMovement;

	[SerializeField]
	private GameObject arrowObject;

	[SerializeField]
	private float squadDetectionRange = 10f;

	private bool isChasingPlayer;

	private bool canBreakChasing;

	[SerializeField]
	private float ChaseDuration = 3f;

	public float GetSquadDetectionRange()
	{
		return squadDetectionRange;
	}

	private void Awake()
	{
		aIPatrolMovement = GetComponentInChildren<AIPatrolMovement>();
		SetUpUnits();
	}

	private void SetUpUnits()
	{
		units.AddRange(GetComponentsInChildren<AIPatrolUnit>());
		foreach (AIPatrolUnit unit in units)
		{
			unit.SetAIPatrolManager(this);
			unit.BuildUnit();
		}
	}

	public void UnitDestroyed(AIPatrolUnitMovement aIUnitMovement)
	{
		aIPatrolMovement.RemoveShip(aIUnitMovement);
	}

	public void DestroyPatrol(bool destroyed)
	{
		if (destroyed)
		{
			Singleton<GameAchievementsManager>.Instance?.Add_PatrolsDestroyed();
		}
		if (SceneSingleton<AIPatrolSpawner>.Instance != null)
		{
			SceneSingleton<AIPatrolSpawner>.Instance.PatrolDestroyed();
		}
		Object.Destroy(base.gameObject);
	}

	private void FixedUpdate()
	{
		if (!isChasingPlayer)
		{
			ObjectSystem.RotateAt(arrowObject.transform, aIPatrolMovement.targetPoint);
		}
	}

	public void StartChasingPlayer()
	{
		if (isChasingPlayer)
		{
			return;
		}
		arrowObject.SetActive(value: false);
		aIPatrolMovement.SetIsChasingPlayer(x: true);
		foreach (AIPatrolUnit unit in units)
		{
			unit.RefreshAIMapIconController(AIFaction.Red);
		}
		isChasingPlayer = true;
		canBreakChasing = false;
		TweenController.DelayedCall(ChaseDuration, () =>
		{
			CanBreakChasing();
		});
	}

	public void StopChasingPlayer()
	{
		if (!canBreakChasing || !isChasingPlayer)
		{
			return;
		}
		arrowObject.SetActive(value: true);
		aIPatrolMovement.SetIsChasingPlayer(x: false);
		foreach (AIPatrolUnit unit in units)
		{
			unit.RefreshAIMapIconController(AIFaction.Blue);
		}
		isChasingPlayer = false;
	}

	private void CanBreakChasing()
	{
		canBreakChasing = true;
	}
}
