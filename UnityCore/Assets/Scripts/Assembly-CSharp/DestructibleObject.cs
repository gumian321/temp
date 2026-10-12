using System;
using UnityEngine;

[RequireComponent(typeof(DestructibleObjectHealth))]
[RequireComponent(typeof(Rigidbody2D))]
[RequireComponent(typeof(Collider2D))]
public class DestructibleObject : MonoBehaviour, IDamageable, IDetectable, IRepairable
{
	[SerializeField]
	private DetectionType ObjectDetectionType;

	private Transform objectTransform;

	private DestructibleObjectHealth objectHealth;

	private bool isBeingRepaired;

	public void SetObject(DetectionType ObjectDetectionType, Transform objectTransform)
	{
		objectHealth = GetComponent<DestructibleObjectHealth>();
		this.ObjectDetectionType = ObjectDetectionType;
		this.objectTransform = objectTransform;
	}

	public void SetObjectHealth(Action OnDestroyAction, Action<float> OnHealthDamageAction, Action<float> OnHealthRepairAction, float currentMaxHealth, bool isMaxHealth = true)
	{
		objectHealth.SetHealth(OnDestroyAction, OnHealthDamageAction, OnHealthRepairAction, currentMaxHealth, isMaxHealth);
	}

	public void UpdateObjectHealth(float newMaxHealth)
	{
		objectHealth.UpdateHealth(newMaxHealth);
	}

	public void SetMaxHealth(float newMaxHealth)
	{
		objectHealth.SetMaxHealth(newMaxHealth);
	}

	public void SetOnDestroyAction(Action OnDestroyAction)
	{
		objectHealth.SetOnDestroyAction(OnDestroyAction);
	}

	public void SetOnHealthDamageAction(Action<float> healthDamageAction)
	{
		objectHealth.SetOnHealthDamageAction(healthDamageAction);
	}

	public bool IsDetectionType(DetectionType detectionType)
	{
		return ObjectDetectionType == detectionType;
	}

	public Transform GetDetectionTransform()
	{
		return objectTransform;
	}

	public float GetMaxHealth()
	{
		return objectHealth.GetMaxHealth();
	}

	public void TakeDamage(float damage)
	{
		objectHealth.TakeDamage(damage);
	}

	public void TakeFullDamage()
	{
		objectHealth.TakeFullDamage();
	}

	public float GetDamagePercent()
	{
		return objectHealth.GetDamagePercent();
	}

	public bool CanRepair()
	{
		return objectHealth.CanRepair();
	}

	public void Repair(float repairAmount)
	{
		objectHealth.Repair(repairAmount);
	}

	public void SetRepairStatue(bool statue)
	{
		isBeingRepaired = statue;
	}

	public bool IsBeingRepaired()
	{
		return isBeingRepaired;
	}
}
