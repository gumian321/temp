using TMPro;
using UnityEngine;

public class PlayerDronesManager : SceneSingleton<PlayerDronesManager>
{
	[SerializeField]
	private DroneTurretController droneTurretController;

	[HideInInspector]
	public int dronesCount;

	[SerializeField]
	public GameObject dronesHQUI;

	[SerializeField]
	public TextMeshProUGUI scrapperDronesCountText;

	private int scrapperDronesCount;

	[SerializeField]
	public TextMeshProUGUI attackDronesCountText;

	private int attackDronesCount;

	[SerializeField]
	public TextMeshProUGUI engineerDronesCountText;

	private int engineerDronesCount;

	[SerializeField]
	public TextMeshProUGUI totalDronesCount;

	public void BuildDrones()
	{
		foreach (Drone mainCoreDrones in Singleton<PlayerDataStore>.Instance.GetMainCoreDronesList())
		{
			AddDrone(mainCoreDrones);
		}
		RefreshUI();
		droneTurretController.ActivateDrones();
		Singleton<GameAchievementsManager>.Instance?.Add_AchievementTypes(AchievementTypes.HQDronesCount, Singleton<PlayerDataStore>.Instance.GetMainCoreDronesList().Count);
	}

	public void DisableDrones()
	{
		droneTurretController.DisableTurret();
	}

	public void ActivateDrones()
	{
		droneTurretController.ActivateTurret();
	}

	public void SetMainParent(Transform parent)
	{
		droneTurretController.transform.parent = parent;
	}

	public void RefreshDrones()
	{
		droneTurretController.RefreshTurret();
		droneTurretController.UpdateDronesRange(Singleton<PlayerDataStore>.Instance.GetMainCoreRangePercent());
	}

	public void AddDrone(Drone drone)
	{
		dronesCount++;
		Singleton<GameAchievementsManager>.Instance?.Add_AchievementTypes(AchievementTypes.HQDronesCount);
		switch (drone.dronePrefab)
		{
		case PrefabTypes.Drone_Scrapper:
			scrapperDronesCount++;
			break;
		case PrefabTypes.Drone_Attack:
			attackDronesCount++;
			break;
		case PrefabTypes.Drone_Engineer:
			engineerDronesCount++;
			break;
		}
		droneTurretController.AddDrone(drone);
		droneTurretController.ActivateDrones();
	}

	private void Start()
	{
		SetUIState(flag: false);
	}

	public void SetUIState(bool flag)
	{
		if (flag)
		{
			RefreshUI();
			TweenController.ScaleV3(dronesHQUI.transform, 0f, 1f, TweenDuration.Very_Short, ignoreTimeScale: true);
		}
		else
		{
			TweenController.ScaleV3(dronesHQUI.transform, 1f, 0f, TweenDuration.Very_Short, ignoreTimeScale: true);
		}
	}

	public void RefreshUI()
	{
		scrapperDronesCountText.text = scrapperDronesCount.ToString();
		attackDronesCountText.text = attackDronesCount.ToString();
		engineerDronesCountText.text = engineerDronesCount.ToString();
		totalDronesCount.text = dronesCount + "/" + Singleton<PlayerDataStore>.Instance.GetMaxHQDronesCount();
	}
}
