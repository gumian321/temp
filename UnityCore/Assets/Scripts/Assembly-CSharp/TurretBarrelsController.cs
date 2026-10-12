using System.Collections.Generic;
using UnityEngine;

public class TurretBarrelsController : MonoBehaviour
{
	[SerializeField]
	private List<Transform> barrels;

	private int currentIndex;

	public void ResetBarrels()
	{
		currentIndex = 0;
	}

	public Transform GetNextBarrel()
	{
		Transform result = barrels[currentIndex];
		currentIndex++;
		if (currentIndex >= barrels.Count)
		{
			currentIndex = 0;
		}
		return result;
	}
}
