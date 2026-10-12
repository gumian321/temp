using UnityEngine;

public class ContainerObject : MapObject
{
	private ContainerField containerField;

	[Space]
	[Header("Container Object Data")]
	[SerializeField]
	private RarityTypes containerRarity;

	public void SetContainer(ContainerField cf)
	{
		containerField = cf;
		Reset();
		GetComponent<AutoRotator>().SetRandomSpeed(10f);
	}

	protected override void OnDestroyAction()
	{
		containerField.ContainerDestroyed(this);
		CheckSpawnPack();
		Singleton<GameAchievementsManager>.Instance?.Add_ContainersDestroyed();
		base.OnDestroyAction();
	}

	private void CheckSpawnPack()
	{
		SceneSingleton<RewardSystemManager>.Instance.SpawnRewardPack(base.transform.position, Singleton<RewardDataStore>.Instance.GetRandomRewardPack(containerRarity), containerRarity);
	}
}
