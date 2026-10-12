using UnityEngine;

public class FuelTankContoller : TurretController
{
	[SerializeField]
	private Transform fuelObject;

	private float fuelCapacity;

	private FuelCore fuelCore;

	public float GetFuelCapacity()
	{
		return fuelCapacity;
	}

	public override void StunTurret(bool isStunned)
	{
		if (isStunned)
		{
			SceneSingleton<PlayerEngineBoostController>.Instance.RemoveFuelTankContoller(this, fuelCapacity);
		}
		else
		{
			SceneSingleton<PlayerEngineBoostController>.Instance.AddFuelTankContoller(this);
		}
	}

	public override void DisableTurret()
	{
		SceneSingleton<PlayerEngineBoostController>.Instance.RemoveFuelTankContoller(this, fuelCapacity);
	}

	public override void ActivateTurret()
	{
		SceneSingleton<PlayerEngineBoostController>.Instance.AddFuelTankContoller(this);
	}

	public override void RefreshTurret()
	{
		base.RefreshTurret();
		if (Singleton<PlayerDataStore>.Instance.CanLevelUp(fuelCore))
		{
			FuelTankLevelUpReward fuelTankLevelUpReward = (FuelTankLevelUpReward)Singleton<PlayerDataStore>.Instance.GetLevelUpReward(fuelCore);
			float percent = (float)Singleton<PlayerDataStore>.Instance.GetLevelUpRewardsCount(fuelCore) * fuelTankLevelUpReward.TankCapacityPercent;
			fuelCapacity = UnityEngineSystem.CalcPercent(fuelCore.fuelCapacity, percent);
			SceneSingleton<PlayerEngineBoostController>.Instance.UpdateFuelTankCapacity();
		}
	}

	public override void SetTurret(Core core)
	{
		fuelCore = (FuelCore)core;
		fuelCapacity = fuelCore.fuelCapacity;
		SceneSingleton<PlayerEngineBoostController>.Instance.AddFuelTankContoller(this);
		Singleton<GameAchievementsManager>.Instance?.Add_AchievementTypes(AchievementTypes.fuelCount);
	}

	public override void DestroyTurret()
	{
		SceneSingleton<PlayerEngineBoostController>.Instance.RemoveFuelTankContoller(this, fuelCapacity);
		Singleton<GameAchievementsManager>.Instance?.Add_AchievementTypes(AchievementTypes.fuelCount, -1);
	}

	public void SetFuelPercent(float percent)
	{
		Vector2 one = Vector2.one;
		one.y *= percent;
		fuelObject.localScale = one;
	}
}
