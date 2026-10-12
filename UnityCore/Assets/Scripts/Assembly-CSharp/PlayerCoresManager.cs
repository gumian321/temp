using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.Rendering;

public class PlayerCoresManager : SceneSingleton<PlayerCoresManager>
{
	[SerializeField]
	private List<CoreController> currentCores = new List<CoreController>();

	[SerializeField]
	public GameObject coresUI;

	[SerializeField]
	private TextMeshProUGUI coresBuildCountText;

	private CoreController mainCore;

	private void Start()
	{
		SetUIState(flag: false);
	}

	public void SetUIState(bool flag)
	{
		if (flag)
		{
			RefreshUI();
			TweenController.ScaleV3(coresUI.transform, 0f, 1f, TweenDuration.Very_Short, ignoreTimeScale: true);
		}
		else
		{
			TweenController.ScaleV3(coresUI.transform, 1f, 0f, TweenDuration.Very_Short, ignoreTimeScale: true);
		}
	}

	public void RefreshUI()
	{
		coresBuildCountText.text = currentCores.Count + "/" + Singleton<PlayerDataStore>.Instance.GetMaxBuiltCores();
	}

	public int GetCoresCount()
	{
		return currentCores.Count;
	}

	public bool CanAddCore(int count = 1)
	{
		count += currentCores.Count;
		return count <= Singleton<PlayerDataStore>.Instance.GetMaxBuiltCores();
	}

	public bool CanWallCores(int count = 1)
	{
		int num = 0;
		foreach (CoreController currentCore in currentCores)
		{
			if (currentCore != null && currentCore.CanAddWall())
			{
				num++;
			}
		}
		return num >= count;
	}

	public void AddCoreController(CoreController controller)
	{
		ParticlesSystem.PlayParticle(controller.transform.position, PrefabTypes.Particle_CoreBuilt);
		TweenController.PunchScale(controller.transform, 0.1f, TweenDuration.Very_Short, ignoreTimeScale: true);
		currentCores.Add(controller);
		SceneSingleton<GameHeatManager>.Instance.ChangeHeat(controller.GetCurrentCore().coreHeat);
		SceneSingleton<RatingSystemManager>.Instance.AddRating(RatingTypes.PartsBuilt, controller.GetCurrentCore().coreRatePrize);
		SceneSingleton<PlayerCenterRadar>.Instance.UpdateRadars();
		RefreshUI();
	}

	public void RemoveCoreController(CoreController controller)
	{
		ParticlesSystem.PlayExplosionParticle(controller.transform.position, 0.5f);
		currentCores.Remove(controller);
		SceneSingleton<GameHeatManager>.Instance.ChangeHeat(-controller.GetCurrentCore().coreHeat);
		SceneSingleton<PlayerCenterRadar>.Instance.UpdateRadars();
		RefreshUI();
	}

	public void DestroyAllCores()
	{
		foreach (CoreController item in new List<CoreController>(currentCores))
		{
			if (item != null)
			{
				item.DestroyCore();
			}
		}
	}

	public void RefreshCores()
	{
		foreach (CoreController currentCore in currentCores)
		{
			if (currentCore != null)
			{
				currentCore.RefreshCore();
			}
		}
	}

	public void RefreshCores(Core core)
	{
		foreach (CoreController currentCore in currentCores)
		{
			if (currentCore != null && currentCore.GetCurrentCore() == core)
			{
				currentCore.RefreshCore();
			}
		}
	}

	public void RefreshCoresHealth()
	{
		foreach (CoreController currentCore in currentCores)
		{
			if (currentCore != null)
			{
				currentCore.RefreshCoreHealth();
			}
		}
	}

	public void EnterBuildMode()
	{
		GetComponent<SortingGroup>().sortingLayerName = "Build Mode";
		foreach (CoreController currentCore in currentCores)
		{
			if (currentCore != null)
			{
				currentCore.EnterBuildMode();
			}
		}
	}

	public void ExitBuildMode()
	{
		GetComponent<SortingGroup>().sortingLayerName = "Blocks";
		foreach (CoreController currentCore in currentCores)
		{
			if (currentCore != null)
			{
				currentCore.ExitBuildMode();
			}
		}
	}

	public void HighLightCores(CoreController holdedCore)
	{
		foreach (CoreController currentCore in currentCores)
		{
			if (currentCore != null)
			{
				HighLightCore(currentCore, holdedCore);
			}
		}
	}

	public void HighLightCores(Core holdedCore)
	{
		foreach (CoreController currentCore in currentCores)
		{
			if (currentCore != null)
			{
				HighLightCore(currentCore, holdedCore);
			}
		}
	}

	public void DisableHighLightCores()
	{
		foreach (CoreController currentCore in currentCores)
		{
			if (currentCore != null)
			{
				currentCore.DisableHighLightCore(snapDisable: true);
			}
		}
	}

	private void HighLightCore(CoreController currentCoreController, CoreController holdedCoreController, bool isBuildingMode = false)
	{
		Core currentCore = holdedCoreController.GetCurrentCore();
		HighLightCore(currentCoreController, currentCore, isBuildingMode);
	}

	private void HighLightCore(CoreController currentCoreController, Core holdedCore, bool isBuildingMode = false)
	{
		Core currentCore = currentCoreController.GetCurrentCore();
		if (holdedCore is ChipCore)
		{
			if (!(currentCore is ChipCore))
			{
				ChipTypes coreChipType = ((ChipCore)holdedCore).GetCoreChipType();
				if (currentCore.CanBeHighlighted(coreChipType))
				{
					currentCoreController.HighLightCore();
				}
			}
		}
		else if (currentCore is ChipCore)
		{
			ChipTypes coreChipType2 = ((ChipCore)currentCore).GetCoreChipType();
			if (holdedCore.CanBeHighlighted(coreChipType2))
			{
				currentCoreController.HighLightCore();
			}
		}
	}

	public void SetMainCoreController(CoreController mainCore)
	{
		this.mainCore = mainCore;
	}

	public CoreController GetMainCoreController()
	{
		return mainCore;
	}

	public void RefreshMainCoreHealth()
	{
		float mainCoreHealthPercent = Singleton<PlayerDataStore>.Instance.GetMainCoreHealthPercent(SceneSingleton<PlayerTurretManager>.Instance.GetTurretCore());
		float newMaxHealth = UnityEngineSystem.CalcPercent(mainCore.GetCurrentCore().CoreHealth, mainCoreHealthPercent);
		mainCore.UpdateCoreHealth(newMaxHealth);
	}
}
