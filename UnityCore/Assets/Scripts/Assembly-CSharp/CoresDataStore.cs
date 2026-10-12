using System.Collections.Generic;
using UnityEngine;

public class CoresDataStore : Singleton<CoresDataStore>
{
	[Space]
	[Header("Clocking")]
	[SerializeField]
	private Color clockedCoreColor;

	[Space]
	[Header("Walled Core")]
	[SerializeField]
	private float walledCoreAddedHealth;

	[SerializeField]
	private Sprite walledCoreSprite;

	[Space]
	[Header("Highlight Core")]
	[SerializeField]
	private Color highLightedCoreColor;

	[Space]
	[SerializeField]
	private List<Sprite> coreHealthSprites;

	[SerializeField]
	private List<Sprite> mainCoreHealthSprites;

	public Color GetClockedCoreColor()
	{
		return clockedCoreColor;
	}

	public float GetWalledCoreAddedHealth()
	{
		return walledCoreAddedHealth;
	}

	public Sprite GetWalledCoreSprite()
	{
		return walledCoreSprite;
	}

	public Color GetHighLightedCoreColor()
	{
		return highLightedCoreColor;
	}

	public Sprite GetCoreHealthSprite(float healthPercent)
	{
		if (healthPercent >= 1f)
		{
			return coreHealthSprites[coreHealthSprites.Count - 1];
		}
		float num = 1f / (float)coreHealthSprites.Count;
		float num2 = healthPercent / num;
		return coreHealthSprites[(int)num2];
	}

	public Sprite GetMainCoreHealthSprite(float healthPercent)
	{
		if (healthPercent >= 1f)
		{
			return mainCoreHealthSprites[mainCoreHealthSprites.Count - 1];
		}
		float num = 1f / (float)mainCoreHealthSprites.Count;
		float num2 = healthPercent / num;
		return mainCoreHealthSprites[(int)num2];
	}
}
