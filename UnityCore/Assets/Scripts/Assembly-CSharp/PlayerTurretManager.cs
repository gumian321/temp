using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

public class PlayerTurretManager : SceneSingleton<PlayerTurretManager>
{
	private Camera mainCamera;

	private TurretController turretController;

	private ProjectileTurretController projectileTurretController;

	private Core turretCore;

	private CoreController coreController;

	private List<ProjectileTurretController> projectileCoresList = new List<ProjectileTurretController>();

	private PlayerCoresManager playerCoresManager;

	private bool isTurretActive;

	private bool isActivatable;

	private bool isFiring;

	private bool isStunned;

	public bool isMouse;

	private Vector3 direction;

	private void Start()
	{
		mainCamera = Camera.main;
		playerCoresManager = SceneSingleton<PlayerCoresManager>.Instance;
		projectileCoresList = new List<ProjectileTurretController>();
	}

	public bool IsSameCore(Core core)
	{
		return turretCore == core;
	}

	public void BuildPlayerTurret(CoreController coreController, Core core)
	{
		if (turretController == null)
		{
			turretCore = core;
			this.coreController = coreController;
			SetUpTurret();
		}
		else
		{
			turretCore = core;
			this.coreController = coreController;
			TweenController.Scale(turretController.transform, 1.75f, 0f, TweenDuration.Very_Short, ignoreTimeScale: true, SetUpTurret);
		}
	}

	private void SetUpTurret()
	{
		Singleton<AudioManager>.Instance.PlaySFX(AudioClipTypes.HQ_Weapon_Change);
		Core currentCore = coreController.GetCurrentCore();
		coreController.SetCurrentCore(turretCore);
		GameObject gameObject = coreController.SpawnNewCoreObject();
		turretController = gameObject.GetComponent<TurretController>();
		turretController.BuildTurret(coreController, turretCore);
		turretController.SetIsPlayerControlled(IsPlayerControlled: false);
		if (turretController is ProjectileTurretController)
		{
			projectileTurretController = (ProjectileTurretController)turretController;
			isActivatable = true;
		}
		else
		{
			projectileTurretController = null;
			isActivatable = false;
		}
		SetCurser();
		RefreshTurret();
		coreController.SetCurrentCore(currentCore);
		TweenController.Scale(turretController.transform, 0f, 1.75f, TweenDuration.Very_Short, ignoreTimeScale: true);
	}

	public Core GetTurretCore()
	{
		return turretCore;
	}

	public void RefreshTurret()
	{
		turretCore.RefreshCore(coreController);
		LevelUpReward levelUpReward = Singleton<PlayerDataStore>.Instance.GetLevelUpReward(turretCore);
		if (levelUpReward is TurretLevelUpReward)
		{
			TurretLevelUpReward turretLevelUpReward = (TurretLevelUpReward)levelUpReward;
			if (turretLevelUpReward != null)
			{
				float num = Singleton<PlayerDataStore>.Instance.GetLevelUpRewardsCount(turretCore);
				UpdateTurretDamage(Singleton<PlayerDataStore>.Instance.GetMainCoreDamagePercent() + turretLevelUpReward.DamagePercent * num);
				UpdateTurretRateOfFire(Singleton<PlayerDataStore>.Instance.GetMainCoreRateOfFirePercent() + turretLevelUpReward.RateOfFirePercent * num);
				UpdateTurretRange(Singleton<PlayerDataStore>.Instance.GetMainCoreRangePercent() + turretLevelUpReward.RangePercent * num);
			}
			else
			{
				UpdateTurretDamage(Singleton<PlayerDataStore>.Instance.GetMainCoreDamagePercent());
				UpdateTurretRateOfFire(Singleton<PlayerDataStore>.Instance.GetMainCoreRateOfFirePercent());
				UpdateTurretRange(Singleton<PlayerDataStore>.Instance.GetMainCoreRangePercent());
			}
		}
	}

	public void UpdateTurretRateOfFire(float percent)
	{
		if (projectileTurretController != null)
		{
			projectileTurretController.UpdateRateOfFire(percent);
		}
	}

	public void UpdateTurretDamage(float percent)
	{
		if (projectileTurretController != null)
		{
			projectileTurretController.UpdateDamageModifer(percent);
		}
	}

	public void UpdateTurretRange(float percent)
	{
		if (projectileTurretController != null)
		{
			projectileTurretController.UpdateRange(percent);
		}
	}

	public void DisableTurret()
	{
		Singleton<CurserManager>.Instance.SetCurser(CurserTypes.ShootingDisabled);
		isStunned = true;
		turretController.DisableTurret();
	}

	public void ActivateTurret()
	{
		SetCurser();
		isStunned = false;
		turretController.ActivateTurret();
	}

	private void FixedUpdate()
	{
		if (isTurretActive)
		{
			foreach (ProjectileTurretController projectileCores in projectileCoresList)
			{
				projectileCores.RotateToTarget(mainCamera.ScreenToWorldPoint(Mouse.current.position.ReadValue()));
				projectileCores.ShootTurret(projectileCores.IsFiring());
			}
		}
		if (CanControlTurret())
		{
			if (isMouse)
			{
				projectileTurretController.RotateToTarget(mainCamera.ScreenToWorldPoint(Mouse.current.position.ReadValue()));
			}
			else
			{
				projectileTurretController.RotateToTarget(base.transform.position + direction * 10f);
			}
			projectileTurretController.ShootTurret(projectileTurretController.IsFiring());
		}
	}

	public void ActivateTurret(bool isTurretActive)
	{
		if (!Singleton<InputManager>.Instance.isPlayerInputOn)
		{
			isTurretActive = false;
		}
		this.isTurretActive = isTurretActive;
		if (!isActivatable)
		{
			return;
		}
		turretController.SetIsPlayerControlled(isTurretActive);
		foreach (ProjectileTurretController projectileCores in projectileCoresList)
		{
			projectileCores.SetIsPlayerControlled(isTurretActive);
		}
	}

	private bool CanControlTurret()
	{
		if (isActivatable && turretController != null && isTurretActive && !isStunned)
		{
			return projectileTurretController != null;
		}
		return false;
	}

	public void SetCurser()
	{
		if (isActivatable)
		{
			Singleton<CurserManager>.Instance.SetCurser(CurserTypes.Shooting);
		}
		else
		{
			Singleton<CurserManager>.Instance.SetCurser(CurserTypes.ShootingDisabled);
		}
	}

	public void AddTurret(ProjectileTurretController projectileTurret)
	{
		if (!projectileCoresList.Contains(projectileTurret))
		{
			projectileCoresList.Add(projectileTurret);
		}
	}

	public void RemoveTurret(ProjectileTurretController projectileTurret)
	{
		if (projectileCoresList.Contains(projectileTurret))
		{
			projectileCoresList.Remove(projectileTurret);
			projectileTurret.SetIsPlayerControlled(IsPlayerControlled: false);
		}
	}

	public void SetAimDirection(Vector2 direction)
	{
		if (isActivatable)
		{
			isMouse = false;
			if (direction.x != 0f || direction.y != 0f)
			{
				this.direction = direction;
			}
		}
	}
}
