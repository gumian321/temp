using System.Collections.Generic;
using TMPro;
using UnityEngine;

public class LocalizationFontStore : Singleton<LocalizationFontStore>
{
	[SerializeField]
	private List<Font> fontsList;

	public TMP_FontAsset GetTMP_FontAsset(Languages language)
	{
		foreach (Font fonts in fontsList)
		{
			if (fonts.language == language)
			{
				return fonts.languageFont;
			}
		}
		Debug.LogError(language.ToString() + " font is not avilable in LocalizationFontStore");
		return null;
	}
}
