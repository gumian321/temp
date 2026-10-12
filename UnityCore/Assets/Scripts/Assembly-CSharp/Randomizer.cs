using System;
using System.Collections.Generic;
using UnityEngine;

public class Randomizer : MonoBehaviour
{
	public static List<T> Randomize<T>(List<T> items)
	{
		System.Random random = new System.Random();
		for (int i = 0; i < items.Count - 1; i++)
		{
			int index = random.Next(i, items.Count);
			T value = items[i];
			items[i] = items[index];
			items[index] = value;
		}
		return items;
	}
}
