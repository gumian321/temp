using System;
using System.Collections.Generic;
using UnityEngine;

public class AIBossSpawner : SceneSingleton<AIBossSpawner>
{
	private AIFaction bossWaveAIFaction;

	private Transform targetTransform;

	public void SetUpAIFaction(AIFaction bossWaveAIFaction)
	{
		this.bossWaveAIFaction = bossWaveAIFaction;
	}

	public void SetUp(bool isPlayerTargeting)
	{
		if (isPlayerTargeting)
		{
			targetTransform = SceneSingleton<PlayerManager>.Instance.GetPlayerTransform();
		}
		else
		{
			targetTransform = SceneSingleton<GameMissionManager>.Instance.GetMissionTarget();
		}
	}

	public Transform SpawnBossWave(List<PrefabTypes> typesList, float spawnDistance = 40f, Action OnDestroyAction = null, bool changeSpeedWithHeat = false, bool isRadius = true, Transform target = null)
	{
		AIFleetManager component = MasterPool.CreateNew(PrefabTypes.AIFleetManager).GetComponent<AIFleetManager>();
		if (isRadius)
		{
			component.SetUpRadius(typesList, targetTransform, spawnDistance, OnDestroyAction, changeSpeedWithHeat, bossWaveAIFaction);
		}
		else
		{
			component.SetUpInMiddle(typesList, targetTransform, target, OnDestroyAction, changeSpeedWithHeat, bossWaveAIFaction);
		}
		component.AddAction(OnBossWaveDestroyed);
		Singleton<AudioManager>.Instance.PlaySFX(AudioClipTypes.BossEntry);
		CameraTargetBossWave(component.GetFleetCenter());
		return component.GetFleetCenter();
	}

	public void OnBossWaveDestroyed()
	{
		SceneSingleton<GameManager>.Instance.BossWaveDestroyed();
	}

	private void CameraTargetBossWave(Transform boss)
	{
		if (!SaveSystem.GetSkipBossSetting())
		{
			SceneSingleton<GameCameraManager>.Instance.SetCameraTarget(boss, CompleteBossTargeting);
		}
		else
		{
			CompleteBossTargeting();
		}
	}

	private void CompleteBossTargeting()
	{
		TweenController.DelayedCall(1f, () =>
		{
			SceneSingleton<TutorialMenuController>.Instance.ShowRunTutorial();
		});
	}
}
