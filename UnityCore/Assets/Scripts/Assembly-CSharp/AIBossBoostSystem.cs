using UnityEngine;

public class AIBossBoostSystem : MonoBehaviour
{
	private float boostActionRadious;

	[SerializeField]
	private float boostActivationRadious = 10f;

	[SerializeField]
	private float boostActivationAngle = 20f;

	[SerializeField]
	private float boostTimerDelay = 5f;

	[SerializeField]
	private float boostDuration = 2f;

	private float delayTimer;

	private float durationTimer;

	private IBossBoost iBossBoost;

	private AudioSource enginesAudioSource;

	[SerializeField]
	private bool boostToPlayer;

	[SerializeField]
	private Transform targetTransfrom;

	private Transform bossTransform;

	private bool isBoostOn;

	private float boostTimer;

	private AudioManager audioManager;

	[SerializeField]
	private bool isFar;

	[SerializeField]
	private float distanceToTarget;

	public void SetTargetTransfrom(Transform t)
	{
		targetTransfrom = t;
		boostToPlayer = false;
	}

	private void Awake()
	{
		audioManager = Singleton<AudioManager>.Instance;
		iBossBoost = GetComponent<IBossBoost>();
		if (boostToPlayer)
		{
			targetTransfrom = SceneSingleton<GameMissionManager>.Instance.GetMissionTarget();
		}
		bossTransform = base.transform;
	}

	public void SetboostActionRadius(float boostActionRadious)
	{
		this.boostActionRadious = boostActionRadious;
	}

	private void FixedUpdate()
	{
		if (iBossBoost == null)
		{
			return;
		}
		if (isBoostOn)
		{
			if (durationTimer < Time.time)
			{
				DectivateBoost();
			}
		}
		else if (ShouldBoost() && delayTimer < Time.time)
		{
			ActivateBoost();
		}
	}

	private bool ShouldBoost()
	{
		Vector2 vector = ((!(targetTransfrom == null)) ? ((Vector2)targetTransfrom.position) : ((Vector2)SceneSingleton<PlayerManager>.Instance.GetPlayerTransform().position));
		float z = Mathf.Atan2(vector.y - bossTransform.position.y, vector.x - bossTransform.position.x) * 57.29578f;
		Quaternion b = Quaternion.Euler(new Vector3(0f, 0f, z));
		bool flag = Quaternion.Angle(bossTransform.rotation, b) < boostActivationAngle;
		distanceToTarget = Vector3.Distance(vector, bossTransform.position);
		isFar = distanceToTarget > boostActivationRadious;
		if (isFar & flag)
		{
			return iBossBoost.CanBoost();
		}
		return false;
	}

	private void ActivateBoost()
	{
		durationTimer = Time.time + boostDuration;
		if (enginesAudioSource == null)
		{
			enginesAudioSource = audioManager.PlaySFX(AudioClipTypes.HQ_Engine_Boost, bossTransform.position);
		}
		iBossBoost.ActivateBoost();
		isBoostOn = true;
	}

	private void DectivateBoost()
	{
		if (enginesAudioSource != null)
		{
			audioManager.StopLoopedAudioSource(enginesAudioSource);
			enginesAudioSource = null;
		}
		iBossBoost.DeactivateBoost();
		delayTimer = Time.time + boostTimerDelay;
		isBoostOn = false;
	}
}
