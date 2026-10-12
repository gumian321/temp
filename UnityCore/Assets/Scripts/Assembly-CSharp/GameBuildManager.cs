using System.Collections.Generic;
using UnityEngine;

public class GameBuildManager : Singleton<GameBuildManager>
{
	[SerializeField]
	private GameVersion gameVersion;

	[Space]
	[SerializeField]
	private Platform platform;

	[Space]
	[SerializeField]
	private int resolutionHeight = 1060;

	[SerializeField]
	private int resolutionWidth = 1920;

	[SerializeField]
	private FullScreenMode screenMode;

	[Space]
	[SerializeField]
	private bool enableSteam;

	[SerializeField]
	private List<GameObject> steamObjects;

	public GameVersion GetGameVersion()
	{
		return gameVersion;
	}

	public Platform GetPlatform()
	{
		return platform;
	}

	protected override void Awake()
	{
		base.Awake();
		if (PlayerPrefs.GetInt("FirstTime" + gameVersion, 0) == 0 || gameVersion == GameVersion.UnityEngine)
		{
			FirstRunGame();
			PlayerPrefs.SetInt("FirstTime" + gameVersion, 1);
		}
		if (gameVersion == GameVersion.Demo)
		{
			Singleton<DemoBuildManager>.Instance.StartDemo();
		}
		if (gameVersion == GameVersion.UnityEngine)
		{
			SaveSystem.SaveMetaPoints(10000);
		}
		foreach (GameObject steamObject in steamObjects)
		{
			steamObject.SetActive(enableSteam);
		}
	}

	public void FirstRunGame()
	{
		Singleton<AnalyticsManager>.Instance.CallUserRegisterEvent(gameVersion, platform);
		if (!SaveSystem.IsSaveFileAvilable())
		{
			SaveSystem.ResetGame();
			SaveSystem.SaveResulationSetting(2);
			SaveSystem.SaveScreenModeSetting(0);
			Screen.SetResolution(resolutionWidth, resolutionHeight, screenMode);
		}
	}

	public void GetSteamDemoReady()
	{
		Debug.Log("GetSteamDemoReady");
		gameVersion = GameVersion.Demo;
		platform = Platform.Steam;
		enableSteam = false;
	}

	public void GetSteamFullGameReady()
	{
		Debug.Log("GetSteamFullGameReady");
		gameVersion = GameVersion.FullGame;
		platform = Platform.Steam;
		enableSteam = true;
	}

	public void GetSteamBetaReady()
	{
		Debug.Log("GetSteamBetaReady");
		gameVersion = GameVersion.Beta;
		platform = Platform.Steam;
		enableSteam = true;
	}

	public bool IsSteamBeta()
	{
		return gameVersion == GameVersion.Beta;
	}
}
