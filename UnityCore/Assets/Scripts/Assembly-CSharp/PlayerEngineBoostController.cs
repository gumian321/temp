using System.Collections.Generic;
using UnityEngine;

public class PlayerEngineBoostController : SceneSingleton<PlayerEngineBoostController>
{
	private AudioSource enginesAudioSource;

	private float currentFuelCapacity;

	private float maxFuelCapacity;

	private float fuelRechargeRate;

	private float fuelRechargeDelay;

	private float fuelConsumptionRate;

	private float boostEnginePower;

	private bool canRecharge;

	private bool canActivate;

	private bool engineActive;

	private float delayTimer;

	private List<FuelTankContoller> fuelTankContollersList = new List<FuelTankContoller>();

	private PlayerMovement playerMovement;

	private AudioManager audioManager;

	private bool CanConsume;

	public void Setup()
	{
		audioManager = Singleton<AudioManager>.Instance;
		fuelRechargeRate = PlayerDataStore.GetFuelRechargeRate();
		fuelConsumptionRate = PlayerDataStore.GetFuelConsumptionRate();
		fuelRechargeDelay = PlayerDataStore.GetFuelRechargeDelay();
		boostEnginePower = Singleton<PlayerDataStore>.Instance.GetBoostEnginePower();
		playerMovement = GetComponent<PlayerMovement>();
	}

	public void AddFuelTankContoller(FuelTankContoller fuelTankContoller)
	{
		SceneSingleton<TutorialMenuController>.Instance.ShowBoostTutorial();
		if (!fuelTankContollersList.Contains(fuelTankContoller))
		{
			fuelTankContollersList.Add(fuelTankContoller);
			maxFuelCapacity += fuelTankContoller.GetFuelCapacity();
			engineActive = true;
			UpdateFuel();
		}
	}

	public void RemoveFuelTankContoller(FuelTankContoller fuelTankContoller, float fuelCapacity)
	{
		if (fuelTankContollersList.Contains(fuelTankContoller))
		{
			float num = currentFuelCapacity / maxFuelCapacity;
			maxFuelCapacity -= fuelCapacity;
			fuelTankContollersList.Remove(fuelTankContoller);
			if (maxFuelCapacity == 0f)
			{
				currentFuelCapacity = 0f;
				engineActive = false;
			}
			else
			{
				currentFuelCapacity = maxFuelCapacity * num;
			}
			UpdateFuel();
		}
	}

	public void UpdateFuelTankCapacity()
	{
		maxFuelCapacity = 0f;
		foreach (FuelTankContoller fuelTankContollers in fuelTankContollersList)
		{
			maxFuelCapacity += fuelTankContollers.GetFuelCapacity();
		}
		UpdateFuel();
	}

	public void UpdateBoostEngine(float boostEnginePower)
	{
		this.boostEnginePower = boostEnginePower;
	}

	private void UpdateFuel()
	{
		if (currentFuelCapacity >= maxFuelCapacity)
		{
			currentFuelCapacity = maxFuelCapacity;
		}
		UpdateFuelTanks(currentFuelCapacity / maxFuelCapacity);
		if (currentFuelCapacity <= 0f)
		{
			DisableEngine();
		}
		else if (!CanConsume)
		{
			canRecharge = currentFuelCapacity < maxFuelCapacity;
		}
	}

	private void UpdateFuelTanks(float percent)
	{
		foreach (FuelTankContoller fuelTankContollers in fuelTankContollersList)
		{
			fuelTankContollers.SetFuelPercent(percent);
		}
	}

	private void DisableEngine()
	{
		currentFuelCapacity = 0f;
		canRecharge = false;
		StopUsingEngine();
		UpdateFuelTanks(0f);
		StartEngineDelay();
	}

	private void StartEngineDelay()
	{
		delayTimer = Time.time + fuelRechargeDelay;
		canRecharge = false;
		canActivate = true;
	}

	private void ActivateEngine()
	{
		canRecharge = true;
		canActivate = false;
	}

	private void FixedUpdate()
	{
		if (!engineActive)
		{
			return;
		}
		if (canActivate)
		{
			if (delayTimer < Time.time)
			{
				ActivateEngine();
			}
			return;
		}
		if (CanConsume)
		{
			currentFuelCapacity -= fuelConsumptionRate;
		}
		else if (canRecharge)
		{
			currentFuelCapacity += fuelRechargeRate;
		}
		UpdateFuel();
	}

	private bool CanUseEngine()
	{
		if (engineActive)
		{
			return currentFuelCapacity > 0f;
		}
		return false;
	}

	public void UseEngine(bool isOn)
	{
		if (!Singleton<InputManager>.Instance.isPlayerInputOn)
		{
			isOn = false;
		}
		if (isOn)
		{
			StartUsingEngine();
		}
		else
		{
			StopUsingEngine();
		}
	}

	public void StartUsingEngine()
	{
		if (CanUseEngine())
		{
			if (enginesAudioSource == null)
			{
				enginesAudioSource = audioManager.PlaySFX(AudioClipTypes.HQ_Engine_Boost);
			}
			canRecharge = false;
			CanConsume = true;
			playerMovement.ActivateEngineBoost(boostEnginePower);
		}
	}

	public void StopUsingEngine()
	{
		if (enginesAudioSource != null)
		{
			audioManager.StopLoopedAudioSource(enginesAudioSource);
			enginesAudioSource = null;
		}
		if (CanConsume)
		{
			playerMovement.deactivateEngineBoost();
		}
		CanConsume = false;
	}
}
