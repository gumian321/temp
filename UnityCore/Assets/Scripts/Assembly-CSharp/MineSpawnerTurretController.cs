using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MineSpawnerTurretController : TurretController
{
	private MineSpawnerCore minesCore;

	private MinesManager minesManager;

	private Mine coreMine;

	private float minesSpawnRate;

	[SerializeField]
	private float minesCountPerSpawn;

	private float spawnRadius;

	private bool isTurretActive = true;

	[Space]
	[Header("Mines Spawning")]
	[SerializeField]
	private Transform minesPossHolder;

	[SerializeField]
	private List<Transform> minesSpawnPoints;

	[SerializeField]
	private float timeBetweenTwoMines;

	private Vector3 previousPosition;

	private Vector3 lastMoveDirection;

	private float rotOffset = 90f;

	private AudioManager audioManager;

	private float timer;

	public override void StunTurret(bool isStunned)
	{
		isTurretActive = !isStunned;
	}

	public override void DisableTurret()
	{
		isTurretActive = false;
	}

	public override void ActivateTurret()
	{
		isTurretActive = true;
	}

	public override void SetTurret(Core core)
	{
		audioManager = Singleton<AudioManager>.Instance;
		minesManager = SceneSingleton<MinesManager>.Instance;
		minesCore = (MineSpawnerCore)core;
		coreMine = minesCore.coreMine;
		minesSpawnRate = minesCore.minesSpawnRate;
		minesCountPerSpawn = minesCore.minesCountPerSpawn;
		spawnRadius = minesCore.spawnRadius;
		isTurretActive = true;
	}

	public override void RefreshTurret()
	{
		base.RefreshTurret();
		MineFieldLevelUpReward mineFieldLevelUpReward = (MineFieldLevelUpReward)Singleton<PlayerDataStore>.Instance.GetLevelUpReward(minesCore);
		if (mineFieldLevelUpReward != null)
		{
			float num = Singleton<PlayerDataStore>.Instance.GetLevelUpRewardsCount(minesCore);
			minesSpawnRate = UnityEngineSystem.CalcPercent(minesCore.minesSpawnRate, mineFieldLevelUpReward.minesRechargeRatePercent * num);
			minesCountPerSpawn = minesCore.minesCountPerSpawn + num * 2f;
		}
	}

	private IEnumerator SpawnMines()
	{
		bool breakTime = false;
		int num = minesSpawnPoints.Count - (int)minesCountPerSpawn;
		List<MineController> list = new List<MineController>();
		for (int i = num; i < minesSpawnPoints.Count; i++)
		{
			GameObject pos = MasterPool.GetPos(coreMine.minePrefab, base.transform.position);
			MineController component = pos.GetComponent<MineController>();
			component.SetMine(coreMine, coreController.GetCoreTargetDetectionType(), turretChipsContainer);
			list.Add(component);
			TweenController.LocalMove(pos.transform, minesSpawnPoints[i].position, TweenDuration.Very_Short);
			if (breakTime)
			{
				audioManager.PlaySFX(AudioClipTypes.Gun_Mine);
				yield return new WaitForSeconds(timeBetweenTwoMines);
			}
			breakTime = !breakTime;
		}
		minesManager?.AddMinesList(list);
	}

	private void FixedUpdate()
	{
		if (isTurretActive && TimeToSpawn() && !object.Equals(lastMoveDirection, Vector3.zero))
		{
			StartCoroutine(SpawnMines());
		}
	}

	private void Update()
	{
		lastMoveDirection = (base.transform.position - previousPosition).normalized;
		previousPosition = base.transform.position;
		if (minesPossHolder != null)
		{
			Vector3 euler = Quaternion.LookRotation(Vector3.forward, lastMoveDirection).eulerAngles + new Vector3(0f, 0f, rotOffset);
			minesPossHolder.transform.rotation = Quaternion.Lerp(minesPossHolder.transform.rotation, Quaternion.Euler(euler), Time.deltaTime * 10f);
		}
	}

	protected bool TimeToSpawn()
	{
		if (timer < Time.time)
		{
			timer = Time.time + minesSpawnRate;
			return true;
		}
		return false;
	}

	public override void DestroyTurret()
	{
	}
}
