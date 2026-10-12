using System.Collections.Generic;
using UnityEngine;

public class AsteroidField : FieldMapNode
{
	private List<Asteroid> asteroids;

	[Space]
	[Header("Asteroid Counts")]
	[SerializeField]
	private int smallAsteroidsProb = 3;

	[SerializeField]
	private int midAsteroidsProb = 2;

	[SerializeField]
	private int bigAsteroidsProb = 1;

	private int smallAsteroidsCount;

	private int midAsteroidsCount;

	private int bigAsteroidsCount;

	public override void SpawnField()
	{
		asteroids = new List<Asteroid>();
		float num = (float)Random.Range(minFieldCount, maxFieldCount) / (float)maxFieldCount;
		float num2 = num / (float)(smallAsteroidsProb + bigAsteroidsProb + midAsteroidsProb);
		smallAsteroidsCount = (int)(num2 * (float)smallAsteroidsProb * (float)maxFieldCount);
		midAsteroidsCount = (int)(num2 * (float)midAsteroidsProb * (float)maxFieldCount);
		bigAsteroidsCount = (int)(num2 * (float)bigAsteroidsProb * (float)maxFieldCount);
		fieldArea = (int)(num * (float)maxFieldArea);
		fieldArea = Mathf.Clamp(fieldArea, minFieldArea, maxFieldArea);
		SpawnAstero(PrefabTypes.Object_Asteroid_Small, smallAsteroidsCount);
		SpawnAstero(PrefabTypes.Object_Asteroid_Mid, midAsteroidsCount);
		SpawnAstero(PrefabTypes.Object_Asteroid_Big, bigAsteroidsCount);
	}

	private void SpawnAstero(PrefabTypes type, int num)
	{
		for (int i = 0; i < num; i++)
		{
			Asteroid component = MasterPool.GetPos(type, GetAsteroidPos()).GetComponent<Asteroid>();
			component.SetAsteroid(this);
			asteroids.Add(component);
		}
	}

	private Vector3 GetAsteroidPos()
	{
		return base.transform.position + (Vector3)(Random.insideUnitCircle * fieldArea);
	}

	public void AsteroidDestroyed(Asteroid a)
	{
		if (asteroids.Count != 0)
		{
			asteroids.Remove(a);
			if (asteroids.Count == 0)
			{
				FieldDestroyed();
			}
		}
	}

	public override void DeactivateNode()
	{
		foreach (Asteroid asteroid in asteroids)
		{
			asteroid.gameObject.SetActive(value: false);
		}
		asteroids.Clear();
		base.DeactivateNode();
	}
}
