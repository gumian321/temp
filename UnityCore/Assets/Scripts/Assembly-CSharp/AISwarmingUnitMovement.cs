using UnityEngine;

public class AISwarmingUnitMovement : AIUnitMovement
{
	private Transform targetTransform;

	public float movingSpeed;

	[HideInInspector]
	public float rotSpeed;

	[SerializeField]
	protected float rotEngineModifier = 10f;

	private bool isMoving;

	public override void UpdateShipVariables()
	{
		movingSpeed = enginePower;
		rotSpeed = enginePower * rotEngineModifier;
	}

	public void SetMoveTarget(Transform targetTransform)
	{
		this.targetTransform = targetTransform;
	}

	public void SetIsMoving(bool isMoving)
	{
		this.isMoving = isMoving;
	}

	public override void MoveUnit()
	{
		if (isMoving)
		{
			Move();
		}
		RotateToTarget();
	}

	public void Move()
	{
		base.transform.Translate(Vector3.right * movingSpeed * Time.fixedDeltaTime);
	}

	private void RotateToTarget()
	{
		if (!(targetTransform == null))
		{
			Vector3 vector = base.transform.position - targetTransform.position;
			Quaternion to = Quaternion.AngleAxis(Mathf.Atan2(vector.y, vector.x) * 57.29578f + 180f, Vector3.forward);
			base.transform.rotation = Quaternion.RotateTowards(base.transform.rotation, to, rotSpeed * Time.fixedDeltaTime);
		}
	}
}
