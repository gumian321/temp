using System.Collections.Generic;
using UnityEngine;

public class ContainerField : FieldMapNode
{
	private List<ContainerObject> containerObjectsList;

	private int containersCount;

	private AIGuardsSpawner aIGuardsSpawner;

	[SerializeField]
	private List<PrefabTypes> containersPrefabTypes;

	public override void SpawnField()
	{
		containerObjectsList = new List<ContainerObject>();
		float num = (float)Random.Range(minFieldCount, maxFieldCount) / (float)maxFieldCount;
		containersCount = (int)(num * (float)maxFieldCount);
		containersCount = Mathf.Clamp(containersCount, minFieldCount, maxFieldCount);
		fieldArea = (int)(num * (float)maxFieldArea);
		fieldArea = Mathf.Clamp(fieldArea, minFieldArea, maxFieldArea);
		for (int i = 0; i < containersCount; i++)
		{
			SpawnContainer();
		}
		aIGuardsSpawner = GetComponentInChildren<AIGuardsSpawner>();
		aIGuardsSpawner.SpawnGuards(AIFaction.Blue, num);
	}

	private void SpawnContainer()
	{
		ContainerObject component = MasterPool.GetPos(containersPrefabTypes[Random.Range(0, containersPrefabTypes.Count)], GetContainerPos()).GetComponent<ContainerObject>();
		component.SetContainer(this);
		containerObjectsList.Add(component);
	}

	private Vector3 GetContainerPos()
	{
		return base.transform.position + (Vector3)(Random.insideUnitCircle * fieldArea);
	}

	public void ContainerDestroyed(ContainerObject a)
	{
		if (containerObjectsList.Count > 0)
		{
			containerObjectsList.Remove(a);
			if (containerObjectsList.Count == 0)
			{
				FieldDestroyed();
			}
		}
	}

	public override void DeactivateNode()
	{
		aIGuardsSpawner.DisableGuards();
		foreach (ContainerObject containerObjects in containerObjectsList)
		{
			containerObjects.gameObject.SetActive(value: false);
		}
		containerObjectsList.Clear();
		base.DeactivateNode();
	}
}
