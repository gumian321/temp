using System.Collections.Generic;
using UnityEngine;

public class SpriteRandomSelector : MonoBehaviour
{
	[SerializeField]
	private List<Sprite> spritesList;

	private void OnEnable()
	{
		GetComponent<SpriteRenderer>().sprite = spritesList[Random.Range(0, spritesList.Count)];
	}
}
