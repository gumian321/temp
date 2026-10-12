using System;
using System.Collections.Generic;
using Steamworks;

public class LocalizationSystem : Singleton<LocalizationSystem>
{
	private Languages currentLanguage = Languages.English;

	private Dictionary<string, string> languageIDStrings;

	private CSVReader cSVReader;

	public event Action<Languages> OnLanguageChange;

	private void OnEnable()
	{
		LoadLanguage();
	}

	private void LoadLanguage()
	{
		SetCurrentLanguage();
		LoadDictionary();
	}

	private void LoadDictionary()
	{
		if (cSVReader == null)
		{
			cSVReader = Singleton<CSVReader>.Instance;
		}
		languageIDStrings = new Dictionary<string, string>();
		languageIDStrings = cSVReader.LoadData((int)currentLanguage);
	}

	private void SetCurrentLanguage()
	{
		currentLanguage = (Languages)FBPP.GetInt("currentLanguage", GetDefaultLanguage());
	}

	private void SaveLanguage(Languages newLanguage)
	{
		FBPP.SetInt("currentLanguage", (int)newLanguage);
		SaveSystem.SaveLanguageSetting(FBPP.GetInt("currentLanguage", 1) - 1);
	}

	private int GetDefaultLanguage()
	{
		return getDefaultDesktopLanguage();
	}

	private int getDefaultDesktopLanguage()
	{
		if (!SteamManager.Initialized)
		{
			return 1;
		}
		return SteamApps.GetCurrentGameLanguage() switch
		{
			"english" => 1, 
			"schinese" => 2, 
			"tchinese" => 3, 
			"russian" => 4, 
			_ => 1, 
		};
	}

	public void ChangeLanguage(Languages newLanguage)
	{
		if (newLanguage != currentLanguage)
		{
			SaveLanguage(newLanguage);
			LoadLanguage();
			if (OnLanguageChange != null)
			{
				OnLanguageChange(currentLanguage);
			}
		}
	}

	public string GetIDString(string ID)
	{
		ID = ID.Trim();
		ID = ID.ToLower();
		if (languageIDStrings.ContainsKey(ID))
		{
			return languageIDStrings[ID];
		}
		return "Error_Localization_ID\n" + ID;
	}

	public bool HasIDString(string ID)
	{
		ID = ID.Trim();
		ID = ID.ToLower();
		return languageIDStrings.ContainsKey(ID);
	}

	public bool CheckLanguage(Languages checkedLanguage)
	{
		return checkedLanguage == currentLanguage;
	}

	public Languages GetCurrentLanguage()
	{
		return currentLanguage;
	}

	public Dictionary<string, string> GetDictionary()
	{
		return languageIDStrings;
	}
}
