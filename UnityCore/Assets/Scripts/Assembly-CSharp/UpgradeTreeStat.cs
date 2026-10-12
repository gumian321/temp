using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class UpgradeTreeStat : MonoBehaviour
{
	[SerializeField]
	private Color color;

	[SerializeField]
	private Color addedColor;

	[SerializeField]
	private StatTypes statType;

	[SerializeField]
	private List<Image> statBars;

	public StatTypes GetStatType()
	{
		return statType;
	}

	public bool IsStatType(StatTypes statType)
	{
		return this.statType == statType;
	}

	public void SetStat(int value, int addedValue = 0)
	{
		if (value == 0)
		{
			base.gameObject.SetActive(value: false);
			return;
		}
		base.gameObject.SetActive(value: true);
		if (statBars.Count <= 0)
		{
			return;
		}
		foreach (Image statBar in statBars)
		{
			statBar.color = color;
			ImageSystem.Alphalizer(statBar, 0.5f);
		}
		for (int i = 0; i < value; i++)
		{
			ImageSystem.Alphalizer(statBars[i], 1f);
		}
		for (int j = value; j < value + addedValue && j < statBars.Count; j++)
		{
			statBars[j].color = addedColor;
			ImageSystem.Alphalizer(statBars[j], 1f);
		}
	}
}
