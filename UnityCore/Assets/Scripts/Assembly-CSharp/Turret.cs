using UnityEngine;

[CreateAssetMenu(fileName = "New Turret", menuName = "ScriptableObjects/Turrets/New Turret")]
public class Turret : ScriptableObject
{
	public Sprite turretSprite;

	public GameObject turretObject;
}
