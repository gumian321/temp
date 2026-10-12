using TMPro;
using UnityEngine;

[RequireComponent(typeof(TextMeshProUGUI))]
public class LocalizationTextActivator : MonoBehaviour
{
	[SerializeField]
	private bool ChangeFont = true;

	private TextMeshProUGUI ConnectedText;

	[SerializeField]
	private string IDString;

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
			UpdateText();
		}
	}

	private void OnDisable()
	{
		if (localizationSystem != null)
		{
			localizationSystem.OnLanguageChange -= ChangeLanguage;
		}
	}

	private void ChangeLanguage(Languages newLanguage)
	{
		currentLanguage = newLanguage;
		UpdateText();
	}

	private void UpdateText()
	{
		if (!(localizationSystem == null))
		{
			ConnectedText.text = localizationSystem.GetIDString(IDString);
			if (ChangeFont)
			{
				ConnectedText.font = Singleton<LocalizationFontStore>.Instance?.GetTMP_FontAsset(currentLanguage);
			}
		}
	}

	public void UpdateText(string strID, bool GetID = true)
	{
		if (!(localizationSystem == null))
		{
			if (GetID)
			{
				ConnectedText.text = localizationSystem.GetIDString(strID);
			}
			else
			{
				ConnectedText.text = strID;
			}
			if (ChangeFont)
			{
				ConnectedText.font = Singleton<LocalizationFontStore>.Instance?.GetTMP_FontAsset(localizationSystem.GetCurrentLanguage());
			}
		}
	}
}
