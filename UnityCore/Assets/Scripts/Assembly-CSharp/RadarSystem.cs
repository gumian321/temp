using System;
using System.Collections.Generic;
using UnityEngine;

public class RadarSystem : MonoBehaviour
{
	[SerializeField]
	private CircleCollider2D radarCollider;

	private DetectionType radarDetectionType;

	private Action<Transform> SetTargetAction;

	[SerializeField]
	private RadarConfiguration radarConfiguration;

	private List<Transform> targetsList = new List<Transform>();

	private Transform radarTransform;

	private float refreshDelay = 0.25f;

	private bool isInvoked;

	private bool updateRadarAgain;

	public void SetRadarSystem(float radarRange, DetectionType radarDetectionType, Action<Transform> SetTargetAction = null, RadarConfiguration radarConfiguration = null, bool addRigidBody = false)
	{
		targetsList = new List<Transform>();
		radarCollider.radius = radarRange;
		radarCollider.enabled = true;
		this.radarDetectionType = radarDetectionType;
		radarTransform = base.transform;
		radarTransform.localPosition = Vector3.zero;
		if (radarConfiguration != null)
		{
			this.radarConfiguration = radarConfiguration;
		}
		if (SetTargetAction != null)
		{
			this.SetTargetAction = SetTargetAction;
		}
		else
		{
			SetTargetAction = null;
		}
		UpdateRadarRigidbody2D(addRigidBody);
		ObjectSystem.ReScale(radarTransform, 1f);
	}

	public void AddTurretActions(Action<Transform> SetTargetAction)
	{
		this.SetTargetAction = (Action<Transform>)Delegate.Combine(this.SetTargetAction, SetTargetAction);
	}

	public void RescaleRadar(float radarRange)
	{
		radarCollider.radius = radarRange;
	}

	private void UpdateTargetList(List<Transform> targetsList)
	{
		if (SetTargetAction != null)
		{
			FilterRadar();
			Transform target = radarConfiguration.GetTarget(targetsList, radarTransform.position);
			SetTargetAction(target);
		}
	}

	private void OnTriggerEnter2D(Collider2D other)
	{
		IDetectable component = other.GetComponent<IDetectable>();
		if (component != null && component.IsDetectionType(radarDetectionType))
		{
			targetsList.Add(component.GetDetectionTransform());
			if (!isInvoked)
			{
				isInvoked = true;
				UpdateTargetList(targetsList);
				CancelInvoke();
				Invoke("UpdateRadar", refreshDelay);
			}
			else
			{
				updateRadarAgain = true;
			}
		}
	}

	private void UpdateRadar()
	{
		if (updateRadarAgain)
		{
			UpdateTargetList(targetsList);
			updateRadarAgain = false;
		}
		isInvoked = false;
	}

	private void OnTriggerExit2D(Collider2D other)
	{
		IDetectable component = other.GetComponent<IDetectable>();
		if (component != null && component.IsDetectionType(radarDetectionType))
		{
			targetsList.Remove(component.GetDetectionTransform());
			UpdateTargetList(targetsList);
		}
	}

	public Transform GetTarget(Vector2 pos, RadarConfiguration radarConfiguration, Transform ignoreTarget = null, float range = -1f)
	{
		if (ignoreTarget != null && targetsList.Contains(ignoreTarget))
		{
			targetsList.Remove(ignoreTarget);
			Transform target = radarConfiguration.GetTarget(targetsList, pos, range);
			targetsList.Add(ignoreTarget);
			return target;
		}
		return radarConfiguration.GetTarget(targetsList, pos, range);
	}

	private void UpdateRadarRigidbody2D(bool addRigidBody)
	{
		Rigidbody2D component = GetComponent<Rigidbody2D>();
		if (addRigidBody)
		{
			if (component == null)
			{
				base.gameObject.AddComponent<Rigidbody2D>().bodyType = RigidbodyType2D.Kinematic;
			}
		}
		else if (component != null)
		{
			UnityEngine.Object.Destroy(component);
		}
	}

	private void FilterRadar()
	{
		for (int num = targetsList.Count - 1; num >= 0; num--)
		{
			if (targetsList[num] == null)
			{
				targetsList.RemoveAt(num);
			}
			else if (!targetsList[num].gameObject.activeSelf)
			{
				targetsList.RemoveAt(num);
			}
		}
	}
}
