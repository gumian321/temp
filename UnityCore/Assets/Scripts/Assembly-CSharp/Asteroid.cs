using UnityEngine;

public class Asteroid : MapObject
{
	[Space]
	[Header("Asteroid Object Data")]
	private AsteroidField asteroidField;

	[SerializeField]
	private int totalDebris;

	public void SetAsteroid(AsteroidField af)
	{
		asteroidField = af;
		Reset();
		GetComponent<AutoRotator>().SetRandomSpeed(10f);
	}

	protected override void OnDestroyAction()
	{
		asteroidField.AsteroidDestroyed(this);
		TweenController.ScatterItems(base.transform.position, totalDebris, PrefabTypes.Object_Asteroid_Debri);
		Singleton<GameAchievementsManager>.Instance?.Add_AsteroidsDestroyed();
		base.OnDestroyAction();
	}
}
