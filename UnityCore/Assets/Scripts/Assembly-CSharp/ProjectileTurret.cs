using UnityEngine;

[CreateAssetMenu(fileName = "New ProjectileTurret", menuName = "ScriptableObjects/Turrets/New ProjectileTurret")]
public class ProjectileTurret : Turret
{
	public GameObject turretsBarrels;

	public AudioClipTypes fireAudioClipType;
}
