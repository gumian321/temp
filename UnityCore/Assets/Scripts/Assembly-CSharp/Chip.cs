using UnityEngine;

[CreateAssetMenu(fileName = "New Chip", menuName = "ScriptableObjects/Turrets/New Chip")]
public class Chip : ScriptableObject
{
	public Sprite chipSprite;

	public GameObject chipObject;

	public ChipTypes chipType;
}
