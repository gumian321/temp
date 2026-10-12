using System.Collections.Generic;
using UnityEngine;

public class AIPatrolMovement : MonoBehaviour
{
	private AIPatrolManager aIPatrolManager;

	[SerializeField]
	private List<AIPatrolUnitMovement> units = new List<AIPatrolUnitMovement>();

	[SerializeField]
	private bool isChasingPlayer;

	private float squadDetectionRange;

	[Space]
	[Header("Roaming")]
	[SerializeField]
	public Vector3 targetPoint;

	[SerializeField]
	private float waitingTime;

	private float waitingTimer;

	[SerializeField]
	private bool isWaiting;

	private Transform targetTransform;

	[Space]
	[SerializeField]
	private float maxMovingSpeed;

	private float currentMovingSpeed;

	private float raduisCheckTimer;

	private float acceleration => maxMovingSpeed / 10f;

	private void Start()
	{
		targetTransform = SceneSingleton<GameMissionManager>.Instance.GetMissionTarget();
		units.AddRange(base.transform.parent.GetComponentsInChildren<AIPatrolUnitMovement>());
		UpdateMovingSpeed();
		aIPatrolManager = GetComponentInParent<AIPatrolManager>();
		squadDetectionRange = aIPatrolManager.GetSquadDetectionRange();
	}

	private void OnEnable()
	{
		GetNextRoamingPoint();
	}

	private void FixedUpdate()
	{
		if (raduisCheckTimer < Time.time)
		{
			raduisCheckTimer = Time.time + 0.5f;
			if (Vector3.Distance(base.transform.position, targetTransform.position) > Singleton<AIDataStore>.Instance.GetDeSpawningRadius())
			{
				aIPatrolManager.DestroyPatrol(destroyed: false);
			}
		}
		Vector3 position = targetTransform.position;
		float num = Vector3.Distance(base.transform.position, position);
		if (num > squadDetectionRange)
		{
			aIPatrolManager.StopChasingPlayer();
		}
		else
		{
			aIPatrolManager.StartChasingPlayer();
		}
		if (isChasingPlayer)
		{
			if (num > SceneSingleton<PlayerManager>.Instance.GetPlayerShipSize())
			{
				currentMovingSpeed = Mathf.Lerp(currentMovingSpeed, maxMovingSpeed, acceleration * Time.fixedDeltaTime);
				base.transform.Translate((position - base.transform.position).normalized * currentMovingSpeed * Time.fixedDeltaTime);
			}
			else
			{
				currentMovingSpeed = Mathf.Lerp(currentMovingSpeed, 0f, acceleration * Time.fixedDeltaTime);
			}
		}
		else if (isWaiting)
		{
			if (waitingTimer < Time.time)
			{
				GetNextRoamingPoint();
			}
		}
		else if (Vector3.Distance(base.transform.position, targetPoint) > 0.5f)
		{
			currentMovingSpeed = Mathf.Lerp(currentMovingSpeed, maxMovingSpeed, acceleration * Time.fixedDeltaTime);
			base.transform.Translate((targetPoint - base.transform.position).normalized * currentMovingSpeed * Time.fixedDeltaTime);
		}
		else
		{
			isWaiting = true;
			waitingTimer = Time.time + waitingTime;
		}
	}

	public void AddShip(AIPatrolUnitMovement sm)
	{
		if (units.Contains(sm))
		{
			Debug.LogError(sm.gameObject.name + "is already listed", sm.gameObject);
			return;
		}
		units.Add(sm);
		UpdateMovingSpeed();
	}

	public void RemoveShip(AIPatrolUnitMovement sm)
	{
		if (!units.Contains(sm))
		{
			Debug.LogError(sm.gameObject.name + "is NOT listed", sm.gameObject);
			return;
		}
		units.Remove(sm);
		UpdateMovingSpeed();
		if (units.Count == 0)
		{
			aIPatrolManager.DestroyPatrol(destroyed: true);
		}
	}

	public bool IsChasingPlayer()
	{
		return isChasingPlayer;
	}

	public void SetIsChasingPlayer(bool x)
	{
		isChasingPlayer = x;
	}

	public void UpdateMovingSpeed()
	{
		if (units.Count == 0)
		{
			return;
		}
		maxMovingSpeed = 1000f;
		foreach (AIPatrolUnitMovement unit in units)
		{
			unit.SetAIPatrolMovement(this);
			float enginePower = unit.GetEnginePower();
			if (maxMovingSpeed > enginePower)
			{
				maxMovingSpeed = enginePower;
			}
		}
		maxMovingSpeed *= 0.5f;
	}

	private void GetNextRoamingPoint()
	{
		isWaiting = false;
		if (SceneSingleton<AIPatrolSpawner>.Instance != null)
		{
			targetPoint = SceneSingleton<AIPatrolSpawner>.Instance.GetRandomInsidePos();
		}
	}
}
