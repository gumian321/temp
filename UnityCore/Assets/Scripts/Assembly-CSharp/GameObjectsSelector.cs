using System.Collections.Generic;
using UnityEngine;

public class GameObjectsSelector : MonoBehaviour
{
	[SerializeField]
	private List<GameObject> objectsList;

	private void OnEnable()
	{
		foreach (GameObject objects in objectsList)
		{
			objects.SetActive(value: false);
		}
		objectsList[Random.Range(0, objectsList.Count)].SetActive(value: true);
	}
}
