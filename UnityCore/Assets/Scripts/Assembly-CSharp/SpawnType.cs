using System;
using System.Collections.Generic;
using UnityEngine;

[Serializable]
public class SpawnType
{
	public List<PrefabTypes> SpawnObjectsList;

	public int maxSpawnCount;

	public float timeBetweenSpawns;

	[Range(0f, 1f)]
	public float selectHeatPercent;
}
