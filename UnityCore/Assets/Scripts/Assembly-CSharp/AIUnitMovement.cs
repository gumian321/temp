using UnityEngine;

public abstract class AIUnitMovement : MonoBehaviour, IMovable
{
	protected Transform unitTransform;

	private AIUnitController aIUnitController;

	[SerializeField]
	protected float enginePower;

	[SerializeField]
	protected float maxEnginePower;

	private bool isWarping;

	protected bool isStunned;

	private float shakeAmount = AIDataStore.GetAIShakeAmount();

	protected bool isPushing;

	private Vector3 pushTargetPos;

	protected bool isSucking;

	private Vector3 suckTargetPos;

	private float suckForce;

	public float GetEnginePower()
	{
		return enginePower;
	}

	private void OnEnable()
	{
		isPushing = false;
		isWarping = false;
		isStunned = false;
		isSucking = false;
	}

	public void SetMovement(AIUnitController aIUnitController)
	{
		unitTransform = base.transform;
		this.aIUnitController = aIUnitController;
		UpdateShipVariables();
	}

	public void AddEnginePowerPercent(float percent)
	{
		enginePower = UnityEngineSystem.CalcPercent(enginePower, percent);
		enginePower = Mathf.Clamp(enginePower, 1f, maxEnginePower);
		UpdateShipVariables();
	}

	public void FixedUpdate()
	{
		if (!isWarping)
		{
			if (isSucking)
			{
				SuckUnit();
			}
			else if (isPushing)
			{
				PushUnit();
			}
			else if (isStunned)
			{
				base.transform.position = (Vector2)base.transform.position + Random.insideUnitCircle * shakeAmount;
			}
			else
			{
				MoveUnit();
			}
		}
	}

	public abstract void MoveUnit();

	public abstract void UpdateShipVariables();

	public void IsWarping(bool isWarping)
	{
		this.isWarping = isWarping;
	}

	public void Stun()
	{
		isStunned = true;
	}

	public void EndStun()
	{
		isStunned = false;
	}

	public void SonicWavePush(Vector3 targetPos)
	{
		if (!isSucking)
		{
			pushTargetPos = targetPos;
			isPushing = true;
		}
	}

	private void PushUnit()
	{
		if (Vector3.Distance(unitTransform.position, pushTargetPos) > 0.5f)
		{
			unitTransform.position = Vector2.Lerp(unitTransform.position, pushTargetPos, 3f * Time.fixedDeltaTime);
		}
		else
		{
			isPushing = false;
		}
	}

	public void StartBlackHoleSuck(Vector3 suckTargetPos, float suckForce)
	{
		this.suckTargetPos = suckTargetPos;
		this.suckForce = suckForce;
		isSucking = true;
	}

	public void StopBlackHoleSuck()
	{
		isSucking = false;
	}

	private void SuckUnit()
	{
		unitTransform.position = Vector2.Lerp(unitTransform.position, suckTargetPos, suckForce * Time.fixedDeltaTime);
	}
}
