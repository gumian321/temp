using UnityEngine;

public class AIFollowingUnitMovement : AIUnitMovement
{
	private Transform targetTransform;

	protected float movingSpeed;

	protected float rotSpeed;

	[SerializeField]
	protected float rotEngineModifier = 10f;

	[SerializeField]
	private float stoppingdDis;

	[SerializeField]
	private float runningAwayDistance;

	[SerializeField]
	private float movingModifier;

	[SerializeField]
	private float movingBackSpeedPercent = 0.6f;

	public override void UpdateShipVariables()
	{
		movingSpeed = enginePower;
		rotSpeed = enginePower * rotEngineModifier;
	}

	public void SetMoveTarget(Transform targetTransform)
	{
		this.targetTransform = targetTransform;
	}

	public override void MoveUnit()
	{
		if (!(targetTransform == null))
		{
			float num = Vector3.Distance(targetTransform.position, base.transform.position);
			movingModifier = 0f;
			float num2 = movingSpeed;
			if (num > stoppingdDis)
			{
				movingModifier = 1f;
			}
			if (num < runningAwayDistance)
			{
				movingModifier = -1f;
				num2 *= movingBackSpeedPercent;
			}
			Vector3 normalized = (targetTransform.position - base.transform.position).normalized;
			base.transform.Translate(normalized * (num2 * movingModifier) * Time.fixedDeltaTime);
		}
	}
}
