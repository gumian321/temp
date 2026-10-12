using UnityEngine;

[CreateAssetMenu(fileName = "New Mine Core", menuName = "ScriptableObjects/New Core/Mine Core")]
public class MinesCore : TurretCore
{
	public Mine coreMine;

	public GameObject minesSectionObject;

	public int maxMinesCount;

	public float minesRechargeRate;

	public override bool CanBeHighlighted(ChipTypes ChipType)
	{
		if (!isChipable)
		{
			return false;
		}
		if (coreMine.activatableChips.IsChipActivated(ChipType))
		{
			return true;
		}
		return false;
	}
}
