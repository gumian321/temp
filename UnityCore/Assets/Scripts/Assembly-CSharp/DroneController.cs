using System.Collections;
using UnityEngine;

public abstract class DroneController : MonoBehaviour
{
	[SerializeField]
	private TrailRenderer engineFlare;

	[SerializeField]
	protected float droneSize = 1f;

	protected Drone drone;

	protected Transform dockPoint;

	protected Transform moveTargetTransform;

	protected Transform droneTransform;

	protected PlayerCenterRadar playerCenterRadar;

	protected RadarConfiguration droneRadarConfiguration;

	protected DetectionType droneTargetDetectionType;

	protected float droneRange;

	private bool isDroneActive = true;

	protected ChipsContainer droneChipsContainer;

	private WaitForSeconds delay;

	protected AudioClipTypes audioClipType;

	protected AudioManager audioManager;

	private bool isRefreshingTargets;

	protected bool isFollowingTarget;

	private bool isDocked = true;

	private float actionDistance;

	private float distanceToTarget;

	private float maxMovingSpeed;

	private float acceleration;

	private float currentMovingSpeed;

	private float maxRotSpeed;

	private float rotAcceleration;

	private float currentRotSpeed;

	private float slowingDownDis;

	private bool isMoving = true;

	public abstract void StartDroneAction();

	public abstract void StopDroneAction();

	public abstract Transform RefreshTarget();

	public virtual void SetDrone(Transform dockPoint, Drone drone, ChipsContainer droneChipsContainer, DetectionType droneTargetDetectionType)
	{
		this.drone = drone;
		this.dockPoint = dockPoint;
		droneTransform = base.transform;
		droneTransform.localScale = Vector2.zero;
		audioManager = Singleton<AudioManager>.Instance;
		playerCenterRadar = SceneSingleton<PlayerCenterRadar>.Instance;
		droneRadarConfiguration = drone.droneRadarConfiguration;
		this.droneTargetDetectionType = droneTargetDetectionType;
		maxMovingSpeed = drone.maxMovingSpeed;
		acceleration = drone.acceleration;
		maxRotSpeed = drone.maxRotSpeed;
		rotAcceleration = drone.rotAcceleration;
		droneRange = drone.GetDroneRange();
		slowingDownDis = drone.slowingDownDis;
		audioClipType = drone.droneActionAudioType;
		delay = drone.GetDroneTargetPingNewDelay();
		isDroneActive = false;
		moveTargetTransform = null;
		isDocked = false;
		DroneIsDocked();
		this.droneChipsContainer = droneChipsContainer;
		GetComponent<SpriteRenderer>().sprite = drone.droneSprite;
		if (engineFlare != null)
		{
			engineFlare.Clear();
			engineFlare.gameObject.SetActive(value: false);
		}
	}

	public virtual void RefreshDrone(ChipsContainer droneChipsContainer)
	{
		this.droneChipsContainer = droneChipsContainer;
		DroneLevelUpReward levelUpReward = Singleton<PlayerDataStore>.Instance.GetLevelUpReward(drone);
		if (levelUpReward != null)
		{
			float num = Singleton<PlayerDataStore>.Instance.GetLevelUpRewardsCount(levelUpReward);
			refreshDroneSpeed(levelUpReward.enginePowerPercent * num);
			droneRange = drone.GetDroneRange(levelUpReward.rangePercent * num);
		}
	}

	public virtual void DisableDrone()
	{
		if (isDroneActive)
		{
			isDroneActive = false;
			isRefreshingTargets = false;
			StopAllCoroutines();
			GetBackToTurret(searchForTarget: false);
		}
	}

	public void ActivateDrone()
	{
		if (!isDroneActive)
		{
			isDroneActive = true;
			StartTargetRefreshingCoroutines();
		}
	}

	protected void StartTargetRefreshingCoroutines()
	{
		if (!isRefreshingTargets && base.gameObject.activeInHierarchy)
		{
			StartCoroutine(StartTargetRefreshing());
		}
	}

	private IEnumerator StartTargetRefreshing()
	{
		isRefreshingTargets = true;
		isFollowingTarget = false;
		while (isDroneActive)
		{
			yield return delay;
			Transform transform = RefreshTarget();
			if (transform != null)
			{
				SetDroneTarget(transform);
				yield return new WaitForEndOfFrame();
				if (engineFlare != null)
				{
					engineFlare.gameObject.SetActive(value: true);
				}
				break;
			}
		}
		isRefreshingTargets = false;
	}

	public virtual void SetDroneTarget(Transform targetTransform)
	{
		if (isDocked)
		{
			TweenController.KillTweens(droneTransform);
			TweenController.Scale(droneTransform, 0f, droneSize, TweenDuration.Very_Short);
		}
		moveTargetTransform = targetTransform;
		droneTransform.parent = null;
		isDocked = false;
		isFollowingTarget = true;
		actionDistance = drone.droneActionRange;
	}

	public virtual void GetBackToTurret(bool searchForTarget = true)
	{
		moveTargetTransform = dockPoint;
		actionDistance = drone.droneCoreStopDistance;
		isDocked = false;
		isFollowingTarget = false;
		StopDroneAction();
		if (searchForTarget)
		{
			StartTargetRefreshingCoroutines();
		}
	}

	public virtual void DroneIsDocked(bool searchForTarget = false)
	{
		if (isDocked)
		{
			return;
		}
		if (!isDocked)
		{
			TweenController.KillTweens(droneTransform);
			TweenController.Scale(droneTransform, droneSize, 0f, TweenDuration.Very_Short);
			if (engineFlare != null)
			{
				engineFlare.gameObject.SetActive(value: false);
			}
		}
		currentMovingSpeed = 0f;
		currentRotSpeed = 0f;
		droneTransform.parent = dockPoint;
		droneTransform.localPosition = Vector2.zero;
		isDocked = true;
		isFollowingTarget = false;
		if (searchForTarget)
		{
			StartTargetRefreshingCoroutines();
		}
	}

	public virtual void FixedUpdate()
	{
		if (!isDocked)
		{
			if (moveTargetTransform == null || !moveTargetTransform.gameObject.activeSelf)
			{
				GetBackToTurret();
				return;
			}
			distanceToTarget = Vector3.Distance(droneTransform.position, moveTargetTransform.position);
			MoveDrone();
			CheckDroneActionDistance();
			PlayDroneAction();
		}
	}

	public virtual void PlayDroneAction()
	{
	}

	private void CheckDroneActionDistance()
	{
		if (distanceToTarget < actionDistance)
		{
			CheckDroneTarget();
		}
		else
		{
			StopDroneAction();
		}
	}

	private void CheckDroneTarget()
	{
		if (isFollowingTarget)
		{
			StartDroneAction();
		}
		else
		{
			DroneIsDocked();
		}
	}

	public virtual void MoveDrone()
	{
		if (isMoving)
		{
			if (distanceToTarget > slowingDownDis)
			{
				currentRotSpeed = Mathf.Lerp(currentRotSpeed, maxRotSpeed, rotAcceleration * Time.fixedDeltaTime);
				currentMovingSpeed = Mathf.Lerp(currentMovingSpeed, maxMovingSpeed, acceleration * Time.fixedDeltaTime);
			}
			else
			{
				currentRotSpeed = Mathf.Lerp(currentRotSpeed, maxRotSpeed, rotAcceleration * Time.fixedDeltaTime);
				currentMovingSpeed = Mathf.Lerp(currentMovingSpeed, maxMovingSpeed / 5f, acceleration * Time.fixedDeltaTime);
			}
			Vector3 vector = droneTransform.position - moveTargetTransform.position;
			Quaternion to = Quaternion.AngleAxis(Mathf.Atan2(vector.y, vector.x) * 57.29578f + 180f, Vector3.forward);
			droneTransform.Translate(Vector3.right * currentMovingSpeed * Time.fixedDeltaTime);
			droneTransform.rotation = Quaternion.RotateTowards(droneTransform.rotation, to, currentRotSpeed * Time.fixedDeltaTime);
		}
	}

	public void SetDroneMovement(bool flag)
	{
		isMoving = flag;
	}

	public virtual void DestroyDrone()
	{
		if (engineFlare != null)
		{
			engineFlare.Clear();
		}
		ParticlesSystem.PlayExplosionParticle(base.transform.position, 1f);
		isDocked = true;
		isDroneActive = false;
		isFollowingTarget = false;
		moveTargetTransform = null;
		MasterPool.ReturnToPoolTransform(base.gameObject, drone.dronePrefab);
	}

	public void refreshDroneSpeed(float percent)
	{
		maxMovingSpeed = UnityEngineSystem.CalcPercent(drone.maxMovingSpeed, percent);
		acceleration = UnityEngineSystem.CalcPercent(drone.acceleration, percent);
		maxRotSpeed = UnityEngineSystem.CalcPercent(drone.maxRotSpeed, percent);
		rotAcceleration = UnityEngineSystem.CalcPercent(drone.rotAcceleration, percent);
	}
}
