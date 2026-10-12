using UnityEngine;

public class PlayerArrowsManager : SceneSingleton<PlayerArrowsManager>
{
	[SerializeField]
	private GameObject MainArrowObject;

	[SerializeField]
	private GameObject ArrowObject;

	public GameObject SpawnArrow(Transform targetTransform, Sprite arrowSprite, Color arrowColor)
	{
		GameObject obj = Object.Instantiate(ArrowObject, base.transform);
		obj.GetComponent<PlayerArrowController>().StartArrow(targetTransform, arrowSprite, arrowColor);
		return obj;
	}

	public GameObject SpawnMainArrow(Transform targetTransform, Sprite arrowSprite, Color arrowColor)
	{
		GameObject obj = Object.Instantiate(MainArrowObject, base.transform);
		obj.GetComponent<PlayerArrowController>().StartArrow(targetTransform, arrowSprite, arrowColor);
		return obj;
	}
}
