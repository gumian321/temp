using System.Collections.Generic;
using UnityEngine;

public class TraderUnitMovement : AIUnitMovement
{
	[SerializeField]
	private List<Engine> enginesList;

	[SerializeField]
	private bool engineIsOn;

	[Space]
	[Header("Movement")]
	[SerializeField]
	private Transform targetTransform;

	[SerializeField]
	private float rotSpeed;

	public override void UpdateShipVariables()
	{
	}

	public override void MoveUnit()
	{
		bool flag = true;
		if (targetTransform == null)
		{
			flag = false;
		}
		else if (Vector3.Distance(base.transform.position, targetTransform.position) < 0.5f)
		{
			flag = false;
		}
		if (!flag)
		{
			if (!engineIsOn)
			{
				return;
			}
			foreach (Engine engines in enginesList)
			{
				engines.SetEngineState(state: false);
			}
			engineIsOn = false;
			return;
		}
		if (!engineIsOn)
		{
			foreach (Engine engines2 in enginesList)
			{
				engines2.SetEngineState(state: true);
			}
			engineIsOn = true;
		}
		base.transform.Translate(Vector3.right * enginePower * Time.fixedDeltaTime);
		Vector3 vector = base.transform.position - targetTransform.position;
		Quaternion to = Quaternion.AngleAxis(Mathf.Atan2(vector.y, vector.x) * 57.29578f + 180f, Vector3.forward);
		base.transform.rotation = Quaternion.RotateTowards(base.transform.rotation, to, rotSpeed * Time.fixedDeltaTime);
	}

	public void SetMoveTarget(Transform targetTransform)
	{
		this.targetTransform = targetTransform;
	}

	public void SnapToTarget()
	{
		base.transform.position = targetTransform.position;
	}
}
