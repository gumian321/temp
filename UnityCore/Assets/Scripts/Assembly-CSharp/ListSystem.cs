using System.Collections.Generic;
using UnityEngine;

public class ListSystem : MonoBehaviour
{
	public static T GetClampObject<T>(List<T> list, int index)
	{
		if (index < 0)
		{
			index = 0;
		}
		if (index >= list.Count)
		{
			return list[list.Count - 1];
		}
		return list[index];
	}
}
