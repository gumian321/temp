using UnityEngine;

public class AIPatrolUnitMovement : AIUnitMovement
{
	private AIPatrolMovement aIPatrolMovement;

	private bool turningClockwise;

	private float stoppingDis = 0.5f;

	private Vector3 offset;

	private float currentMovingSpeed;

	private float movingAcceleration;

	private float movingDeceleration;

	private float maxRotSpeed;

	private float currentRotSpeed;

	private float rotAcceleration;

	private float rotDeceleration;

	private float accelerationAngleLimit = 60f;

	private Vector3 targetPos
	{
		get
		{
			return offset + aIPatrolMovement.transform.position;
		}
		set
		{
			offset = value;
		}
	}

	public void SetAIPatrolMovement(AIPatrolMovement aIPatrolMovement)
	{
		this.aIPatrolMovement = aIPatrolMovement;
		targetPos = base.transform.position - aIPatrolMovement.transform.position;
	}

	public override void MoveUnit()
	{
		if (!(aIPatrolMovement == null) && !(Vector3.Distance(base.transform.position, targetPos) < stoppingDis) && !isStunned && !isPushing)
		{
			Vector3 vector = base.transform.position - targetPos;
			Quaternion quaternion = Quaternion.AngleAxis(Mathf.Atan2(vector.y, vector.x) * 57.29578f + 180f, Vector3.forward);
			turningClockwise = Vector3.Cross(base.transform.rotation * Vector3.up, quaternion * Vector3.up).z < 0f;
			float num = Quaternion.Angle(base.transform.rotation, quaternion);
			if (num > accelerationAngleLimit)
			{
				currentRotSpeed = Mathf.Lerp(currentRotSpeed, maxRotSpeed, rotAcceleration * Time.fixedDeltaTime);
				currentMovingSpeed = Mathf.Lerp(currentMovingSpeed, 0f, movingDeceleration * Time.fixedDeltaTime);
			}
			else
			{
				float b = num / accelerationAngleLimit * maxRotSpeed;
				currentRotSpeed = Mathf.Lerp(currentRotSpeed, b, rotDeceleration * Time.fixedDeltaTime);
				float b2 = (1f - num / accelerationAngleLimit) * enginePower;
				currentMovingSpeed = Mathf.Lerp(currentMovingSpeed, b2, movingAcceleration * Time.fixedDeltaTime);
			}
			base.transform.Translate(Vector3.right * currentMovingSpeed * Time.fixedDeltaTime);
			base.transform.rotation = Quaternion.RotateTowards(base.transform.rotation, quaternion, currentRotSpeed * Time.fixedDeltaTime);
		}
	}

	public void SetEnemySquad(AIPatrolMovement t)
	{
		aIPatrolMovement = t;
		if (aIPatrolMovement != null)
		{
			aIPatrolMovement.AddShip(this);
		}
	}

	public override void UpdateShipVariables()
	{
		movingAcceleration = enginePower / 2f;
		movingDeceleration = enginePower / 2f;
		maxRotSpeed = enginePower * 25f;
		rotAcceleration = maxRotSpeed / 8f;
		rotDeceleration = maxRotSpeed / 8f;
		if (aIPatrolMovement != null)
		{
			aIPatrolMovement.UpdateMovingSpeed();
		}
	}
}
