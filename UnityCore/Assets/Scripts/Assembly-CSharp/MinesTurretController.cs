using System.Collections.Generic;
using System.Linq;
using UnityEngine;

public class MinesTurretController : TurretController
{
	private Dictionary<Vector3, MinesSectionManager> minesSectionManagersDict;

	private List<MinesSectionManager> spawningMinesSectionList;

	private List<MinesSectionManager> spawnedMinesSectionList;

	private MinesCore minesCore;

	private float minesRechargeRate;

	private int maxMinesCount;

	private GameObject turretRange;

	private bool isTurretActive = true;

	private int minesCount;

	private bool isSpawning;

	private float timer;

	private List<Vector3> Surroundings = new List<Vector3>
	{
		new Vector3(3f, -3f, 0f),
		new Vector3(3f, -2f, 0f),
		new Vector3(3f, -1f, 0f),
		new Vector3(3f, 0f, 0f),
		new Vector3(3f, 1f, 0f),
		new Vector3(3f, 2f, 0f),
		new Vector3(3f, 3f, 0f),
		new Vector3(2f, -3f, 0f),
		new Vector3(2f, 3f, 0f),
		new Vector3(1f, -3f, 0f),
		new Vector3(1f, 3f, 0f),
		new Vector3(0f, -3f, 0f),
		new Vector3(0f, 3f, 0f),
		new Vector3(-1f, -3f, 0f),
		new Vector3(-1f, 3f, 0f),
		new Vector3(-2f, -3f, 0f),
		new Vector3(-2f, 3f, 0f),
		new Vector3(-3f, -3f, 0f),
		new Vector3(-3f, -2f, 0f),
		new Vector3(-3f, -1f, 0f),
		new Vector3(-3f, 0f, 0f),
		new Vector3(-3f, 1f, 0f),
		new Vector3(-3f, 2f, 0f),
		new Vector3(-3f, 3f, 0f)
	};

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

	public override void DestroyTurret()
	{
		foreach (MinesSectionManager spawningMinesSection in spawningMinesSectionList)
		{
			spawningMinesSection.RemoveMines();
		}
		foreach (MinesSectionManager spawnedMinesSection in spawnedMinesSectionList)
		{
			spawnedMinesSection.RemoveMines();
		}
	}

	public override void SetTurret(Core core)
	{
		minesSectionManagersDict = new Dictionary<Vector3, MinesSectionManager>();
		minesCore = (MinesCore)core;
		minesRechargeRate = minesCore.minesRechargeRate;
		maxMinesCount = minesCore.maxMinesCount;
		minesCount = 0;
		foreach (Vector3 item in coreController.GetBuilder().GetSurroundingEmpty(coreController, Surroundings))
		{
			AddMinesSectionManager(item);
		}
		spawningMinesSectionList = minesSectionManagersDict.Values.ToList();
		spawnedMinesSectionList = new List<MinesSectionManager>();
		isSpawning = true;
		isTurretActive = true;
	}

	private void AddMinesSectionManager(Vector3 v)
	{
		GameObject obj = Object.Instantiate(minesCore.minesSectionObject, turretTransform);
		obj.transform.localPosition = v;
		MinesSectionManager component = obj.GetComponent<MinesSectionManager>();
		minesSectionManagersDict.Add(v, component);
		component.SetMinesSection(this, minesCore.coreMine, coreController.GetCoreTargetDetectionType(), turretChipsContainer);
	}

	public override void PreviewTurret(Core core, bool showPreview = false)
	{
		base.PreviewTurret(core, showPreview);
		if (turretRange == null)
		{
			turretRange = MasterPool.CreateNew(PrefabTypes.Range_MinesField, base.transform);
		}
		turretRange.SetActive(showPreview);
	}

	public override void RefreshTurret()
	{
		base.RefreshTurret();
		MineFieldLevelUpReward mineFieldLevelUpReward = (MineFieldLevelUpReward)Singleton<PlayerDataStore>.Instance.GetLevelUpReward(minesCore);
		if (mineFieldLevelUpReward != null)
		{
			float num = Singleton<PlayerDataStore>.Instance.GetLevelUpRewardsCount(minesCore);
			minesRechargeRate = UnityEngineSystem.GetPerSecAmount(minesCore.minesRechargeRate, mineFieldLevelUpReward.minesRechargeRatePercent * num);
			maxMinesCount = (int)UnityEngineSystem.CalcPercent(minesCore.maxMinesCount, mineFieldLevelUpReward.maxMinesCountPercent * num);
		}
		List<Vector3> surroundingEmpty = coreController.GetBuilder().GetSurroundingEmpty(coreController, Surroundings);
		List<Vector3> list = new List<Vector3>();
		foreach (Vector3 key in minesSectionManagersDict.Keys)
		{
			if (surroundingEmpty.Contains(key))
			{
				minesSectionManagersDict[key].UpdateMinesChipsContainer(turretChipsContainer);
				continue;
			}
			list.Add(key);
			minesSectionManagersDict[key].RemoveMines();
		}
		foreach (Vector3 item in list)
		{
			minesSectionManagersDict.Remove(item);
		}
		foreach (Vector3 item2 in surroundingEmpty)
		{
			if (!minesSectionManagersDict.Keys.Contains(item2))
			{
				AddMinesSectionManager(item2);
			}
		}
		spawningMinesSectionList = minesSectionManagersDict.Values.ToList();
		spawnedMinesSectionList = new List<MinesSectionManager>();
		UpdateMines();
	}

	private void SpwanMine()
	{
		if (minesSectionManagersDict.Count == 0)
		{
			UpdateMines(isSpawned: false);
			return;
		}
		minesCount++;
		GetSpawningPoint().SpawnMine();
		UpdateMines();
	}

	public void MineDestroyed(int minesCount = 1)
	{
		this.minesCount -= minesCount;
		UpdateMines();
	}

	private void UpdateMines(bool isSpawned = true)
	{
		isSpawning = (minesCount < maxMinesCount) & isSpawned;
	}

	private void FixedUpdate()
	{
		if (isTurretActive && isSpawning && TimeToSpawn())
		{
			SpwanMine();
		}
	}

	protected bool TimeToSpawn()
	{
		if (timer < Time.time)
		{
			timer = Time.time + minesRechargeRate;
			return true;
		}
		return false;
	}

	private MinesSectionManager GetSpawningPoint()
	{
		if (spawningMinesSectionList.Count == 0)
		{
			spawningMinesSectionList = new List<MinesSectionManager>(spawnedMinesSectionList);
		}
		MinesSectionManager minesSectionManager = spawningMinesSectionList[Random.Range(0, spawningMinesSectionList.Count)];
		spawningMinesSectionList.Remove(minesSectionManager);
		spawnedMinesSectionList.Add(minesSectionManager);
		return minesSectionManager;
	}
}
