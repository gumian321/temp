using System.Collections.Generic;
using UnityEngine;

public class ProbabilitySystem
{
	public static int GetItemByProbabilityRarity(List<float> cumulativeByRarity)
	{
		float num = Random.Range(1, 100);
		for (int i = 0; i < cumulativeByRarity.Count; i++)
		{
			if (num <= cumulativeByRarity[i])
			{
				return i;
			}
		}
		return 0;
	}

	public static List<float> MakeCumulativeByProbabilityRarity(List<float> probabilityRarity)
	{
		float num = 0f;
		List<float> list = new List<float>();
		float num2 = GetprobabilityByRarityModifer(probabilityRarity);
		for (int i = 0; i < probabilityRarity.Count; i++)
		{
			num += probabilityRarity[i] * num2;
			list.Add(num);
		}
		return list;
	}

	private static float GetprobabilityByRarityModifer(List<float> probabilityRarity)
	{
		float num = 0f;
		for (int i = 0; i < probabilityRarity.Count; i++)
		{
			num += probabilityRarity[i];
		}
		return 100f / num;
	}
}
