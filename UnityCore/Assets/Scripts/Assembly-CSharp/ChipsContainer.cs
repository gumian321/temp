using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

[Serializable]
public class ChipsContainer
{
	[SerializeField]
	private List<ChipTypes> activatedChipsList = new List<ChipTypes>();

	public ChipsContainer()
	{
		activatedChipsList = new List<ChipTypes>();
	}

	public void SetChips(List<ChipTypes> activatedChipsList)
	{
		this.activatedChipsList = activatedChipsList;
	}

	public void AddChip(ChipTypes chipType)
	{
		activatedChipsList.Add(chipType);
	}

	public int GetChipLevel(ChipTypes chipType)
	{
		return activatedChipsList.Count((ChipTypes chip) => chip == chipType);
	}

	public int GetChipsCount()
	{
		return activatedChipsList.Count;
	}

	public void ResetChips()
	{
		activatedChipsList = new List<ChipTypes>();
	}

	public bool IsChipActivated(ChipTypes chipType)
	{
		return activatedChipsList.Contains(chipType);
	}
}
