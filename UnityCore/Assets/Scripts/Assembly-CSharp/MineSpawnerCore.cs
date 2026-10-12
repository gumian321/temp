using UnityEngine;

[CreateAssetMenu(fileName = "New MineSpawner Core", menuName = "ScriptableObjects/New Core/MineSpawner Core")]
public class MineSpawnerCore : TurretCore
{
	public Mine coreMine;

	public float minesSpawnRate;

	public float minesCountPerSpawn = 5f;

	public float spawnRadius = 0.5f;

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
