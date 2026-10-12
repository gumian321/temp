using System.IO;
using Steamworks;
using UnityEngine;
using UnityEngine.InputSystem;

public class SaveSystem : Singleton<SaveSystem>
{
	private static string saveFileName = "SaveData.txt";

	private static string GetFilePath(string fileName)
	{
		return GetSaveDir() + "/" + fileName;
	}

	private static string GetExperimentSavePath()
	{
#if UNITY_EDITOR
		return Path.GetFullPath(Path.Combine(Application.dataPath, "../LocalData"));
#else
		return Application.persistentDataPath;
#endif
	}

	private static string GetSaveDir()
	{
		try
		{
			string text = GetExperimentSavePath();
			if (SteamManager.Initialized)
			{
				text = text + "/" + SteamUser.GetSteamID().ToString();
			}
			if (!Directory.Exists(text))
			{
				Directory.CreateDirectory(text);
			}
			return text;
		}
		catch
		{
			return GetExperimentSavePath();
		}
	}

	public static bool IsSaveFileAvilable()
	{
		return File.Exists(GetFilePath(saveFileName));
	}

	private void OnEnable()
	{
		bool num = !IsSaveFileAvilable();
		FBPP.Start(new FBPPConfig
		{
			SaveFileName = saveFileName,
			AutoSaveData = false,
			SaveFilePath = GetSaveDir()
		});
		if (num)
		{
			ResetGame();
		}
	}

	public static void ResetGame()
	{
		int resulationSetting = GetResulationSetting();
		int screenModeSetting = GetScreenModeSetting();
		bool skipBossSetting = GetSkipBossSetting();
		float masterSlider = AudioSlidersController.GetMasterSlider();
		float musicSlider = AudioSlidersController.GetMusicSlider();
		float sFXSlider = AudioSlidersController.GetSFXSlider();
		FBPP.DeleteAll();
		SaveMetaPoints(55);
		Object.FindObjectOfType<RewardDataStore>().LockRewards();
		SaveResulationSetting(resulationSetting);
		SaveScreenModeSetting(screenModeSetting);
		SaveLanguageSetting(FBPP.GetInt("currentLanguage", 1) - 1);
		SaveSkipBossSetting(skipBossSetting);
		AudioSlidersController.SetMasterSlider(masterSlider);
		AudioSlidersController.SetMusicSlider(musicSlider);
		AudioSlidersController.SetSFXSlider(sFXSlider);
		SaveInvertAimYSetting(state: false);
		SaveInvertAimXSetting(state: false);
		SaveSwitchAimSetting(state: true);
		ResetPlayerInput();
		SaveGame();
	}

	public static void SaveGame()
	{
		FBPP.Save();
	}

	public static int GetMetaPoints()
	{
		return FBPP.GetInt("MetaPoints");
	}

	public static void SaveMetaPoints(int points)
	{
		FBPP.SetInt("MetaPoints", points);
		SaveGame();
	}

	public static int GetResulationSetting()
	{
		return FBPP.GetInt("ResulationSetting");
	}

	public static void SaveResulationSetting(int index)
	{
		FBPP.SetInt("ResulationSetting", index);
	}

	public static bool GetSkipBossSetting()
	{
		return FBPP.GetInt("SkipBossSetting") == 1;
	}

	public static void SaveSkipBossSetting(bool state)
	{
		FBPP.SetInt("SkipBossSetting", state ? 1 : 0);
	}

	public static int GetScreenModeSetting()
	{
		return FBPP.GetInt("ScreenModeSetting");
	}

	public static void SaveScreenModeSetting(int index)
	{
		FBPP.SetInt("ScreenModeSetting", index);
	}

	public static int GetLanguageSetting()
	{
		return FBPP.GetInt("LanguageSetting");
	}

	public static void SaveLanguageSetting(int index)
	{
		FBPP.SetInt("LanguageSetting", index);
	}

	public static void UnlockReward(string name)
	{
		FBPP.SetInt(name, 1);
	}

	public static void LockReward(string name)
	{
		FBPP.SetInt(name);
	}

	public static bool IsRewardUnlocked(string name)
	{
		return FBPP.GetInt(name) == 1;
	}

	public static void UnToggleReward(string name)
	{
		FBPP.SetInt(name + "Toggled");
	}

	public static void ToggleReward(string name)
	{
		FBPP.SetInt(name + "Toggled", 1);
	}

	public static bool IsRewardToggled(string name)
	{
		return FBPP.GetInt(name + "Toggled", 1) == 1;
	}

	public static void UnlockSystem(string name)
	{
		FBPP.SetInt(name + "Unlocked", 1);
		SaveGame();
	}

	public static bool IsSystemUnlocked(string name)
	{
		return FBPP.GetInt(name + "Unlocked") == 1;
	}

	public static void SavePlayerInput()
	{
		string value = InputDataStore.baseInputActions.SaveBindingOverridesAsJson();
		FBPP.SetString("Input", value);
		SaveGame();
	}

	public static void LoadPlayerInput()
	{
		// Recovered project: first-run reset can precede InputDataStore.Awake.
        if (InputDataStore.baseInputActions == null) InputDataStore.baseInputActions = new PlayerInputActions();
        string json = FBPP.GetString("Input");
		InputDataStore.baseInputActions.LoadBindingOverridesFromJson(json);
	}

	public static void ResetPlayerInput()
	{
		PlayerInputActions actions = new PlayerInputActions();
		FBPP.SetString("Input", actions.SaveBindingOverridesAsJson());
		LoadPlayerInput();
		if (Singleton<InputDataStore>.IsInitialized) Singleton<InputDataStore>.Instance.SetUIActionMap();
		SaveGame();
	}

	public static bool GetInvertAimXSetting()
	{
		return FBPP.GetInt("InvertAimXSetting") == 1;
	}

	public static void SaveInvertAimXSetting(bool state)
	{
		FBPP.SetInt("InvertAimXSetting", state ? 1 : 0);
		SaveGame();
	}

	public static bool GetInvertAimYSetting()
	{
		return FBPP.GetInt("InvertAimYSetting") == 1;
	}

	public static void SaveInvertAimYSetting(bool state)
	{
		FBPP.SetInt("InvertAimYSetting", state ? 1 : 0);
		SaveGame();
	}

	public static bool GetSwitchAimSetting()
	{
		return FBPP.GetInt("SwitchAimSetting", 1) == 1;
	}

	public static void SaveSwitchAimSetting(bool state)
	{
		FBPP.SetInt("SwitchAimSetting", state ? 1 : 0);
		SaveGame();
	}
}
