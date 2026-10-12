using System;
using UnityEngine;

public class DestructibleObjectHealth : MonoBehaviour
{
	[SerializeField]
	private float currentHealth;

	[SerializeField]
	private float currentMaxHealth;

	private Action OnDestroyAction;

	private Action<float> OnHealthDamageAction;

	private Action<float> OnHealthRepairAction;

	private SpritePulseEffector spritePulseEffector;

	private PlayerDataStore playerDataStore;

	public void SetHealth(Action destroyAction, Action<float> healthDamageAction, Action<float> healthRepairAction, float currentMaxHealth, bool isMaxHealth = true)
	{
		playerDataStore = Singleton<PlayerDataStore>.Instance;
		this.currentMaxHealth = currentMaxHealth;
		if (isMaxHealth)
		{
			currentHealth = currentMaxHealth;
		}
		else
		{
			currentHealth = 0f;
		}
		OnDestroyAction = destroyAction;
		OnHealthDamageAction = healthDamageAction;
		OnHealthRepairAction = healthRepairAction;
		spritePulseEffector = GetComponent<SpritePulseEffector>();
	}

	public void SetOnDestroyAction(Action OnDestroyAction)
	{
		this.OnDestroyAction = OnDestroyAction;
	}

	public void SetOnHealthDamageAction(Action<float> healthDamageAction)
	{
		OnHealthDamageAction = healthDamageAction;
	}

	public void UpdateHealth(float newMaxHealth)
	{
		float num = currentHealth / currentMaxHealth;
		currentMaxHealth = newMaxHealth;
		currentHealth = currentMaxHealth * num;
	}

	public void SetMaxHealth(float newMaxHealth)
	{
		currentMaxHealth = newMaxHealth;
		currentHealth = newMaxHealth;
	}

	public void TakeDamage(float damage)
	{
		if (!(currentHealth <= 0f))
		{
			DamageHealth(damage);
		}
	}

	private void DamageHealth(float damage)
	{
		currentHealth -= damage;
		if (currentHealth <= 0f)
		{
			currentHealth = 0f;
			if (OnDestroyAction != null)
			{
				OnDestroyAction();
			}
			return;
		}
		if (OnHealthDamageAction != null)
		{
			OnHealthDamageAction(currentHealth);
		}
		if (spritePulseEffector != null)
		{
			spritePulseEffector.StartEffect(playerDataStore.playerHitColor);
		}
	}

	public float GetCurrnetHealth()
	{
		return currentHealth;
	}

	public float GetMaxHealth()
	{
		return currentMaxHealth;
	}

	public void TakeFullDamage(bool snap = false)
	{
		TakeDamage(currentHealth);
	}

	public float GetDamagePercent()
	{
		return currentHealth / currentMaxHealth;
	}

	public bool CanRepair()
	{
		return currentHealth < currentMaxHealth;
	}

	public void Repair(float repairAmount)
	{
		currentHealth += repairAmount;
		if (currentHealth > currentMaxHealth)
		{
			currentHealth = currentMaxHealth;
		}
		if (OnHealthRepairAction != null)
		{
			OnHealthRepairAction(currentHealth);
		}
		if (spritePulseEffector != null)
		{
			spritePulseEffector.StartEffect(playerDataStore.playerRepairColor);
		}
	}
}
