using UnityEngine;

public class RewardScrapPackController : MonoBehaviour
{
	public void StartRewardPack(int scrapsCount)
	{
		Vector2 vector = ObjectSystem.GetRandomEdgePos(SceneSingleton<PlayerManager>.Instance.GetPlayerTransform(), 5f, 0.5f);
		base.transform.position = SceneSingleton<PlayerManager>.Instance.GetPlayerTransform().position;
		ObjectSystem.ReScale(base.gameObject, 0.75f);
		TweenController.LocalMove(base.transform, vector, TweenDuration.Short, ignoreTimeScale: true, () =>
		{
			TweenController.Scale(base.transform, 0.75f, 0f, TweenDuration.Super_Short, ignoreTimeScale: true, () =>
			{
				SceneSingleton<ScrapsManager>.Instance.SpawnScraps(base.transform.position, scrapsCount, Singleton<PlayerDataStore>.Instance.GetScrapSpriteList(), ignoreTimeScale: true);
				MasterPool.ReturnToPoolTransform(base.gameObject, PrefabTypes.Object_ScrapPack);
			});
		});
	}

	private void Update()
	{
		base.transform.Rotate(0f, 0f, 50f * Time.unscaledDeltaTime);
	}
}
