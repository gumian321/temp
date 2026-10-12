using System;

public class MetaEconomySystem : Singleton<MetaEconomySystem>
{
	private int currentMeta;

	public event Action<int> OnMetaChange;

	public int GetCurrentMetaPoints()
	{
		return currentMeta;
	}

	public void RefreshMetaSystem()
	{
		currentMeta = SaveSystem.GetMetaPoints();
		if (OnMetaChange != null)
		{
			OnMetaChange(currentMeta);
		}
	}

	public void SetMetaPoints(int points)
	{
		currentMeta = points;
		if (OnMetaChange != null)
		{
			OnMetaChange(currentMeta);
		}
	}

	public bool CanSpendMetaPoints(int points)
	{
		return currentMeta >= points;
	}

	public void ModifyMetaPoints(int points)
	{
		currentMeta += points;
		SaveSystem.SaveMetaPoints(currentMeta);
		if (OnMetaChange != null)
		{
			OnMetaChange(currentMeta);
		}
	}
}
