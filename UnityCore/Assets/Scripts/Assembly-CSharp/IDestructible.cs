using UnityEngine;

public interface IDestructible
{
	[SerializeField]
	int maxHealth { get; set; }
}
