using UnityEngine;

[CreateAssetMenu(fileName = "New Drone Core", menuName = "ScriptableObjects/New Core/Drone")]
public class DroneCore : TurretCore
{
	public Drone coreDrone;

	public int DroneCount = 4;

	public int maxDronesCount = 5;

	public override string GetCoreTitle()
	{
		return string.Format(Singleton<LocalizationSystem>.Instance.GetIDString(coreNameID), coreDrone.GetDroneTitle());
	}

	public override void BuildCore(CoreController coreController)
	{
		base.BuildCore(coreController);
		if (Singleton<DetectionDataStore>.Instance.IsEnemyLayer(coreController.GetCoreTargetDetectionType()))
		{
			Singleton<GameAchievementsManager>.Instance?.Add_AchievementTypes(AchievementTypes.dronesCount, DroneCount);
		}
	}

	public override void DestroyCore(CoreController coreController)
	{
		base.DestroyCore(coreController);
		if (Singleton<DetectionDataStore>.Instance.IsEnemyLayer(coreController.GetCoreTargetDetectionType()))
		{
			Singleton<GameAchievementsManager>.Instance?.Add_AchievementTypes(AchievementTypes.dronesCount, -DroneCount);
		}
	}

	public override bool CanBeHighlighted(ChipTypes ChipType)
	{
		if (!isChipable)
		{
			return false;
		}
		if (coreDrone.GetCoreChipsContainer().IsChipActivated(ChipType))
		{
			return true;
		}
		return false;
	}
}
