using TMPro;
using UnityEngine;

public class LocalizationFontActivator : MonoBehaviour
{
	private TextMeshProUGUI ConnectedText;

	private LocalizationSystem localizationSystem;

	private Languages currentLanguage;

	private void OnEnable()
	{
		if (ConnectedText == null)
		{
			ConnectedText = GetComponent<TextMeshProUGUI>();
		}
		if (localizationSystem == null)
		{
			localizationSystem = Singleton<LocalizationSystem>.Instance;
		}
		if (localizationSystem != null)
		{
			localizationSystem.OnLanguageChange += ChangeLanguage;
			currentLanguage = localizationSystem.GetCurrentLanguage();
			SetFont();
		}
	}

	private void ChangeLanguage(Languages newLanguage)
	{
		currentLanguage = newLanguage;
		SetFont();
	}

	private void SetFont()
	{
		if (localizationSystem != null)
		{
			ConnectedText.font = Singleton<LocalizationFontStore>.Instance?.GetTMP_FontAsset(currentLanguage);
		}
	}
}
