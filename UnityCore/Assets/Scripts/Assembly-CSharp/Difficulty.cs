using System;
using UnityEngine;

[Serializable]
public class Difficulty
{
	public string diffecultyTextID;

	public DifficultyTypes difficultyType;

	[Space]
	public float enemiesDamageModifier;

	public float enemiesHealthModifier;
}
