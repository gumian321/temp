using UnityEngine;

public class LanguageChangerButton : MonoBehaviour
{
	[SerializeField]
	private Languages buttonLanguage;

	[SerializeField]
	private GameObject buttonTick;

	public void ChangeLangauge()
	{
		if (Singleton<LocalizationSystem>.Instance != null && Singleton<LocalizationSystem>.Instance.GetCurrentLanguage() != buttonLanguage)
		{
			Singleton<LocalizationSystem>.Instance.ChangeLanguage(buttonLanguage);
		}
	}

	public Languages GetButtonLanguage()
	{
		return buttonLanguage;
	}
}
