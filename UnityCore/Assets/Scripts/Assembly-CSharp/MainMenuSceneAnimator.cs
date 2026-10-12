using System.Collections.Generic;
using UnityEngine;

public class MainMenuSceneAnimator : SceneSingleton<MainMenuSceneAnimator>
{
	[SerializeField]
	private int objectsCount = 10;

	[Space]
	[Header("Borders")]
	[SerializeField]
	private float topY;

	[SerializeField]
	private float lowY;

	[SerializeField]
	private Vector2 XBorders;

	private float z;

	[SerializeField]
	private List<GameObject> objectsList;

	private void Start()
	{
		z = base.transform.position.z;
		for (int i = 0; i < objectsCount; i++)
		{
			SpawnAnotherObject();
		}
	}

	public void SpawnAnotherObject()
	{
		GameObject gameObject = Object.Instantiate(objectsList[Random.Range(0, objectsList.Count)]);
		Vector3 vector = new Vector3(Random.Range(XBorders.x, XBorders.y), lowY, z);
		Vector3 vector2 = new Vector3(Random.Range(XBorders.x, XBorders.y), topY, z);
		if (Random.value > 0.5f)
		{
			gameObject.GetComponent<MainMenuSceneObject>().SetObject(vector, vector2);
		}
		else
		{
			gameObject.GetComponent<MainMenuSceneObject>().SetObject(vector2, vector);
		}
	}
}
